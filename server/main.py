"""FlixGo server: واجهة FastAPI فوق yt-dlp لاستخراج وتحميل الفيديو والصوت."""
import ipaddress
import os
import re
import secrets
import socket
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal, Optional
from urllib.parse import urlparse

import yt_dlp
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from yt_dlp.utils import DownloadCancelled, DownloadError
from yt_dlp.version import __version__ as YTDLP_VERSION

# ───────── الإعدادات (متغيرات بيئة) ─────────
DOWNLOAD_DIR = Path(os.getenv("DOWNLOAD_DIR", "downloads"))
DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
API_KEY = os.getenv("API_KEY")  # اختياري: يُرسل من التطبيق في X-API-Key
MAX_CONCURRENT = int(os.getenv("MAX_CONCURRENT", "3"))
FILE_TTL = int(os.getenv("FILE_TTL_SECONDS", "3600"))  # مدة بقاء الملفات المؤقتة
MAX_FILESIZE_MB = int(os.getenv("MAX_FILESIZE_MB", "0"))  # 0 = بلا حد
COOKIES_FILE = os.getenv("COOKIES_FILE")  # اختياري: لحسابك الخاص (إنستغرام/فيسبوك)
ALLOWED = [
    d.strip().lower()
    for d in os.getenv(
        "ALLOWED_DOMAINS",
        "youtube.com,youtu.be,tiktok.com,instagram.com,facebook.com,fb.watch,"
        "x.com,twitter.com,vimeo.com,soundcloud.com,dailymotion.com,reddit.com",
    ).split(",")
    if d.strip()
]  # ضع ALLOWED_DOMAINS=* للسماح بكل المواقع التي يدعمها yt-dlp

app = FastAPI(title="FlixGo API")
POOL = ThreadPoolExecutor(max_workers=MAX_CONCURRENT)
LOCK = threading.Lock()
ACTIVE = ("queued", "downloading", "processing")


# ───────── النماذج ─────────
class AnalyzeRequest(BaseModel):
    url: str = Field(max_length=2048)


class DownloadRequest(BaseModel):
    url: str = Field(max_length=2048)
    kind: Literal["video", "audio"] = "video"
    quality: int = Field(720, ge=64, le=4320)  # ارتفاع الفيديو أو kbps للصوت
    format: Literal["mp4", "webm", "mp3", "m4a"] = "mp4"


@dataclass
class Job:
    id: str
    url: str
    kind: str
    title: str = ""
    status: str = "queued"  # queued | downloading | processing | done | error | canceled
    progress: float = 0.0
    speed: Optional[float] = None
    eta: Optional[int] = None
    filename: Optional[str] = None
    path: Optional[Path] = None
    error: Optional[str] = None
    created: float = field(default_factory=time.time)
    cancel: threading.Event = field(default_factory=threading.Event)


JOBS: dict[str, Job] = {}


# ───────── أدوات مساعدة ─────────
def check_key(x_api_key: Optional[str] = Header(None)) -> None:
    if API_KEY and not secrets.compare_digest(x_api_key or "", API_KEY):
        raise HTTPException(401, "مفتاح غير صحيح")


def validate_url(raw: str) -> str:
    """يقبل http/https فقط، ضمن النطاقات المسموحة، ويرفض العناوين الداخلية (SSRF)."""
    p = urlparse(raw.strip())
    if p.scheme not in ("http", "https") or not p.hostname:
        raise HTTPException(400, "رابط غير صالح")
    host = p.hostname.lower()
    if ALLOWED != ["*"] and not any(host == d or host.endswith("." + d) for d in ALLOWED):
        raise HTTPException(400, "هذا الموقع غير مدعوم")
    try:
        for info in socket.getaddrinfo(host, None):
            ip = ipaddress.ip_address(info[4][0])
            if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
                raise HTTPException(400, "رابط غير مسموح")
    except socket.gaierror:
        raise HTTPException(400, "تعذّر الوصول إلى الموقع")
    return p.geturl()


def base_opts() -> dict:
    o = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "socket_timeout": 20,
        "retries": 3,
        "color": "never",
    }
    if COOKIES_FILE:
        o["cookiefile"] = COOKIES_FILE
    if MAX_FILESIZE_MB:
        o["max_filesize"] = MAX_FILESIZE_MB * 1024 * 1024
    return o


def clean_error(e: Exception) -> str:
    msg = re.sub(r"\x1b\[[0-9;]*m", "", str(e)).replace("ERROR: ", "")
    return msg.strip()[:300] or "تعذّر معالجة الرابط"


def safe_name(title: str) -> str:
    return re.sub(r'[\\/:*?"<>|\r\n]+', "_", title).strip()[:80] or "video"


def cleanup_files(job_id: str) -> None:
    for f in DOWNLOAD_DIR.glob(f"{job_id}.*"):
        f.unlink(missing_ok=True)


def remove_job(job_id: str) -> None:
    job = JOBS.pop(job_id, None)
    if job:
        job.cancel.set()
    cleanup_files(job_id)


def purge_old() -> None:
    now = time.time()
    with LOCK:
        for jid in [
            j for j, job in JOBS.items()
            if now - job.created > FILE_TTL and job.status not in ACTIVE
        ]:
            remove_job(jid)
    for f in DOWNLOAD_DIR.iterdir():  # ملفات يتيمة (مثلاً بعد إعادة تشغيل الخادم)
        if f.is_file() and now - f.stat().st_mtime > FILE_TTL * 2:
            f.unlink(missing_ok=True)


def get_job(job_id: str) -> Job:
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(404, "المهمة غير موجودة")
    return job


# ───────── التحميل ─────────
def run_job(job: Job, req: DownloadRequest) -> None:
    if job.cancel.is_set():
        job.status = "canceled"
        return
    job.status = "downloading"

    def hook(d: dict) -> None:
        if job.cancel.is_set():
            raise DownloadCancelled()
        if d["status"] == "downloading":
            job.status = "downloading"
            total = d.get("total_bytes") or d.get("total_bytes_estimate")
            if total:
                pct = round(d["downloaded_bytes"] / total * 100, 1)
                job.progress = min(99.0, max(job.progress, pct))  # لا يرجع للخلف بين المجريين
            job.speed, job.eta = d.get("speed"), d.get("eta")
        elif d["status"] == "finished":
            job.status = "processing"  # دمج الصوت والفيديو أو التحويل

    opts = {
        **base_opts(),
        "outtmpl": str(DOWNLOAD_DIR / f"{job.id}.%(ext)s"),
        "progress_hooks": [hook],
    }
    if req.kind == "video":
        h = req.quality
        opts["format"] = f"bv*[height<={h}]+ba/b[height<={h}]/b"
        opts["merge_output_format"] = req.format
    else:
        opts["format"] = "bestaudio/best"
        opts["postprocessors"] = [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": req.format,
            "preferredquality": str(req.quality),
        }]

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(job.url, download=True)
        if info.get("_type") == "playlist" and info.get("entries"):
            info = next(iter(info["entries"]))
        if job.cancel.is_set():
            raise DownloadCancelled()
        files = [
            f for f in DOWNLOAD_DIR.glob(f"{job.id}.*")
            if f.suffix not in (".part", ".ytdl", ".temp")
        ]
        if not files:
            raise RuntimeError("لم يتم إنشاء الملف")
        job.path = max(files, key=lambda f: f.stat().st_size)
        job.title = info.get("title") or "video"
        job.filename = safe_name(job.title) + job.path.suffix
        job.progress, job.speed, job.eta = 100.0, None, None
        job.status = "done"
    except DownloadCancelled:
        job.status = "canceled"
        cleanup_files(job.id)
    except DownloadError as e:
        if job.cancel.is_set():
            job.status = "canceled"
        else:
            job.status, job.error = "error", clean_error(e)
        cleanup_files(job.id)
    except Exception:
        job.status, job.error = "error", "فشل التحميل"
        cleanup_files(job.id)


# ───────── الواجهات ─────────
@app.get("/api/health")
def health():
    return {"ok": True, "yt_dlp": YTDLP_VERSION}


@app.post("/api/analyze", dependencies=[Depends(check_key)])
def analyze(req: AnalyzeRequest):
    url = validate_url(req.url)
    try:
        with yt_dlp.YoutubeDL({**base_opts(), "skip_download": True}) as ydl:
            info = ydl.extract_info(url, download=False)
    except DownloadError as e:
        raise HTTPException(422, clean_error(e))
    if info.get("_type") == "playlist" and info.get("entries"):
        info = next(iter(info["entries"]))  # مثل ألبومات إنستغرام: نأخذ أول عنصر
    if info.get("is_live"):
        raise HTTPException(422, "البث المباشر غير مدعوم")
    heights = sorted(
        {
            f["height"] for f in info.get("formats", [])
            if f.get("height") and f.get("vcodec") not in (None, "none")
        },
        reverse=True,
    )
    return {
        "url": url,
        "title": info.get("title") or "",
        "uploader": info.get("uploader") or info.get("channel") or "",
        "platform": info.get("extractor_key") or "",
        "thumbnail": info.get("thumbnail"),
        "duration": int(info["duration"]) if info.get("duration") else None,
        "heights": heights,
    }


@app.post("/api/download", dependencies=[Depends(check_key)])
def start_download(req: DownloadRequest):
    url = validate_url(req.url)
    if (req.kind == "video") != (req.format in ("mp4", "webm")):
        raise HTTPException(422, "الصيغة لا تناسب النوع المختار")
    purge_old()
    job = Job(id=uuid.uuid4().hex, url=url, kind=req.kind)
    JOBS[job.id] = job
    POOL.submit(run_job, job, req)
    return {"job_id": job.id}


@app.get("/api/jobs/{job_id}", dependencies=[Depends(check_key)])
def job_status(job_id: str):
    j = get_job(job_id)
    return {
        "status": j.status,
        "progress": j.progress,
        "speed": j.speed,
        "eta": j.eta,
        "title": j.title,
        "filename": j.filename,
        "error": j.error,
    }


@app.delete("/api/jobs/{job_id}", dependencies=[Depends(check_key)])
def delete_job(job_id: str):
    j = get_job(job_id)
    if j.status in ACTIVE:
        j.cancel.set()
        j.status = "canceled"
    else:
        remove_job(job_id)
    return {"ok": True}


@app.get("/api/files/{job_id}", dependencies=[Depends(check_key)])
def get_file(job_id: str):
    j = get_job(job_id)
    if j.status != "done" or not j.path or not j.path.exists():
        raise HTTPException(409, "الملف غير جاهز")
    return FileResponse(j.path, filename=j.filename)

#!/usr/bin/env python3
"""FlixGo download server for Termux (Python standard library only).

Downloads direct file links (mp3, mp4, ...) to a folder on the phone and lets
the FlixGo app start / watch / cancel downloads and list / delete the files.

Run:   python flixgo_server.py
Config (environment variables, all optional):
  FLIXGO_PORT=8787            port to listen on
  FLIXGO_HOST=127.0.0.1       127.0.0.1 = this phone only. Use 0.0.0.0 only on a
                              trusted network, and then ALWAYS set FLIXGO_TOKEN.
  FLIXGO_TOKEN=secret         if set, the app must send it (header X-Token)
  FLIXGO_DIR=/path/to/folder  where files are saved
  FLIXGO_MAX_MB=2048          refuse files larger than this
  FLIXGO_ALLOW_HTTP=1         also allow plain http:// links (default: https only)
  FLIXGO_ALLOW_PRIVATE=1      allow links that point to private/local addresses

Only download content you own or that is openly licensed. Links to YouTube,
Instagram, TikTok, X and Facebook are refused on purpose.
"""
import hmac
import ipaddress
import json
import os
import re
import socket
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = "1.0.0"
HOST = os.environ.get("FLIXGO_HOST", "127.0.0.1")
PORT = int(os.environ.get("FLIXGO_PORT", "8787"))
TOKEN = os.environ.get("FLIXGO_TOKEN", "")
MAX_BYTES = int(float(os.environ.get("FLIXGO_MAX_MB", "2048")) * 1024 * 1024)
ALLOW_HTTP = os.environ.get("FLIXGO_ALLOW_HTTP") == "1"
ALLOW_PRIVATE = os.environ.get("FLIXGO_ALLOW_PRIVATE") == "1"

BLOCKED = (
    "youtube.com", "youtu.be", "instagram.com", "tiktok.com",
    "twitter.com", "x.com", "facebook.com", "fb.com", "fb.watch",
)
AUDIO_EXT = {"mp3", "m4a", "aac", "wav", "ogg", "flac", "opus"}


def default_dir():
    shared = os.path.expanduser("~/storage/downloads")
    base = shared if os.path.isdir(shared) else os.path.expanduser("~")
    return os.path.join(base, "FlixGo")


SAVE_DIR = os.environ.get("FLIXGO_DIR") or default_dir()
os.makedirs(SAVE_DIR, exist_ok=True)

jobs = {}
lock = threading.Lock()


class Refused(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def host_blocked(host):
    host = (host or "").lower().rstrip(".")
    return any(host == d or host.endswith("." + d) for d in BLOCKED)


def check_url(url):
    u = urllib.parse.urlparse(url)
    if u.scheme not in (("https", "http") if ALLOW_HTTP else ("https",)):
        raise Refused("bad_url", "only https links are allowed")
    if not u.hostname:
        raise Refused("bad_url", "invalid link")
    if host_blocked(u.hostname):
        raise Refused("blocked", "this platform is not supported")
    if not ALLOW_PRIVATE:
        try:
            infos = socket.getaddrinfo(u.hostname, u.port or (443 if u.scheme == "https" else 80))
        except socket.gaierror:
            raise Refused("bad_url", "cannot resolve host")
        for info in infos:
            ip = ipaddress.ip_address(info[4][0])
            if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_multicast:
                raise Refused("private", "links to local/private addresses are refused")
    return u


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        check_url(newurl)  # every hop is checked again
        return super().redirect_request(req, fp, code, msg, headers, newurl)


OPENER = urllib.request.build_opener(SafeRedirect)


def clean_name(name, kind):
    name = urllib.parse.unquote(name or "")
    name = re.sub(r"[^\w.\- ]", "_", name, flags=re.UNICODE).strip(" .")
    if not name:
        name = "flixgo_%d" % int(time.time())
    if "." not in name:
        name += ".mp3" if kind == "audio" else ".mp4"
    return name[:120]


def unique_path(name):
    path = os.path.join(SAVE_DIR, name)
    stem, dot, ext = name.rpartition(".")
    if not dot:
        stem, ext = name, ""
    n = 1
    while os.path.exists(path) or os.path.exists(path + ".part"):
        path = os.path.join(SAVE_DIR, "%s_%d%s" % (stem, n, "." + ext if ext else ""))
        n += 1
    return path


def run_job(job):
    part = job["path"] + ".part"
    try:
        req = urllib.request.Request(job["url"], headers={"User-Agent": "FlixGo/" + VERSION})
        with OPENER.open(req, timeout=30) as resp:
            total = int(resp.headers.get("Content-Length") or 0)
            if total > MAX_BYTES:
                raise Refused("too_big", "file is larger than the allowed size")
            job["total"] = total
            job["status"] = "downloading"
            with open(part, "wb") as out:
                while True:
                    if job["cancel"]:
                        raise InterruptedError()
                    chunk = resp.read(64 * 1024)
                    if not chunk:
                        break
                    job["got"] += len(chunk)
                    if job["got"] > MAX_BYTES:
                        raise Refused("too_big", "file is larger than the allowed size")
                    out.write(chunk)
        os.replace(part, job["path"])
        job["status"] = "done"
    except InterruptedError:
        job["status"] = "cancelled"
        remove_quiet(part)
    except Refused as e:
        job["status"], job["error"] = "error", e.message
        remove_quiet(part)
    except (urllib.error.URLError, OSError, ValueError) as e:
        job["status"], job["error"] = "error", str(getattr(e, "reason", e))[:200]
        remove_quiet(part)


def remove_quiet(path):
    try:
        os.remove(path)
    except OSError:
        pass


def public(job):
    return {k: job[k] for k in ("id", "name", "url", "kind", "status", "got", "total", "error")}


def list_files():
    out = []
    for n in sorted(os.listdir(SAVE_DIR)):
        p = os.path.join(SAVE_DIR, n)
        if n.endswith(".part") or not os.path.isfile(p):
            continue
        st = os.stat(p)
        out.append({"name": n, "size": st.st_size, "mtime": int(st.st_mtime),
                    "kind": "audio" if n.rsplit(".", 1)[-1].lower() in AUDIO_EXT else "video"})
    out.sort(key=lambda f: f["mtime"], reverse=True)
    return out


class Handler(BaseHTTPRequestHandler):
    server_version = "FlixGo/" + VERSION

    def log_message(self, fmt, *args):
        pass

    def send_json(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authed(self):
        if not TOKEN:
            return True
        return hmac.compare_digest(self.headers.get("X-Token", ""), TOKEN)

    def route(self, method):
        path = urllib.parse.urlparse(self.path).path.rstrip("/") or "/"
        if method == "GET" and path == "/health":
            return self.send_json(200, {"ok": True, "version": VERSION, "auth": bool(TOKEN)})
        if not self.authed():
            return self.send_json(401, {"error": "invalid token", "code": "auth"})
        parts = path.strip("/").split("/")

        if method == "POST" and path == "/download":
            try:
                length = int(self.headers.get("Content-Length") or 0)
                data = json.loads(self.rfile.read(min(length, 65536)) or b"{}")
                url = str(data.get("url", "")).strip()
                kind = "audio" if data.get("kind") == "audio" else "video"
                u = check_url(url)
            except Refused as e:
                return self.send_json(400, {"error": e.message, "code": e.code})
            except (ValueError, json.JSONDecodeError):
                return self.send_json(400, {"error": "invalid request", "code": "bad_request"})
            name = clean_name(os.path.basename(u.path), kind)
            with lock:
                path_ = unique_path(name)
                job = {"id": uuid.uuid4().hex[:12], "url": url, "kind": kind,
                       "name": os.path.basename(path_), "path": path_, "status": "queued",
                       "got": 0, "total": 0, "error": None, "cancel": False}
                jobs[job["id"]] = job
                open(path_ + ".part", "wb").close()  # reserve the name
            threading.Thread(target=run_job, args=(job,), daemon=True).start()
            return self.send_json(202, public(job))

        if method == "GET" and path == "/jobs":
            return self.send_json(200, {"jobs": [public(j) for j in jobs.values()]})
        if len(parts) == 2 and parts[0] == "jobs":
            job = jobs.get(parts[1])
            if not job:
                return self.send_json(404, {"error": "no such job", "code": "not_found"})
            if method == "GET":
                return self.send_json(200, public(job))
            if method == "DELETE":
                job["cancel"] = True
                if job["status"] in ("queued",):
                    job["status"] = "cancelled"
                return self.send_json(200, public(job))

        if method == "GET" and path == "/files":
            return self.send_json(200, {"files": list_files(), "dir": SAVE_DIR})
        if len(parts) == 2 and parts[0] == "files":
            name = os.path.basename(urllib.parse.unquote(parts[1]))
            fpath = os.path.join(SAVE_DIR, name)
            if not name or name.endswith(".part") or not os.path.isfile(fpath):
                return self.send_json(404, {"error": "no such file", "code": "not_found"})
            if method == "DELETE":
                os.remove(fpath)
                return self.send_json(200, {"deleted": name})
            if method == "GET":
                size = os.path.getsize(fpath)
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(size))
                self.send_header("Content-Disposition",
                                 "attachment; filename*=UTF-8''" + urllib.parse.quote(name))
                self.end_headers()
                with open(fpath, "rb") as f:
                    while True:
                        chunk = f.read(64 * 1024)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                return
        return self.send_json(404, {"error": "not found", "code": "not_found"})

    def do_GET(self):
        self.route("GET")

    def do_POST(self):
        self.route("POST")

    def do_DELETE(self):
        self.route("DELETE")


def main():
    if HOST not in ("127.0.0.1", "localhost") and not TOKEN:
        raise SystemExit("Refusing to listen on %s without FLIXGO_TOKEN. Set a token." % HOST)
    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    print("FlixGo server %s on http://%s:%d" % (VERSION, HOST, PORT))
    print("Saving to:", SAVE_DIR)
    print("Auth token:", "required" if TOKEN else "not set")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()

// خادم استخراج عام لتطبيق FlixGo — بلا اعتماديات (Node 18+).
// يقرأ وسوم الوصف المفتوحة (Open Graph / JSON-LD / وسم video) من الصفحات التي تعرض ملف الفيديو علناً،
// ويقبل أيضاً روابط الملفات المباشرة. لا يحتوي أي كود خاص بمنصة معيّنة.
// المتغيرات (اختيارية):
//   PORT          المنفذ (الافتراضي 8080)
//   API_KEY       إن ضُبط يُطلب في الترويسة x-api-key أو ?key=
//   HOST_ONLY     =1 يربط الخادم بـ 127.0.0.1 فقط (للتشغيل على الهاتف نفسه)
//   ALLOW_PRIVATE للاختبار المحلي فقط؛ لا تضبطه على الخادم العام
//   ALLOWED_HOSTS قائمة نطاقات مسموحة مفصولة بفواصل (مثل: example.com,cdn.example.com)؛ تشمل النطاقات الفرعية
const http = require('http');
const dns = require('dns').promises;
const net = require('net');
const { execFile } = require('child_process');
const { promisify } = require('util');
const execFileAsync = promisify(execFile);

const PORT = Number(process.env.PORT || 8080);
const API_KEY = process.env.API_KEY || '';
const ALLOWED = (process.env.ALLOWED_HOSTS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
const UA = 'Mozilla/5.0 (compatible; FlixGoResolver/1.0)';
const MEDIA_EXT = /\.(mp4|m4v|webm|mov|mkv|mp3|m4a|aac|ogg|wav|flac)(\?|#|$)/i;
const MAX_HTML = 2 * 1024 * 1024;
const TIMEOUT_MS = 15000;
const YTDLP_HOSTS = new Set([
  'youtube.com', 'youtu.be', 'tiktok.com', 'instagram.com', 'facebook.com', 'fb.watch',
  'x.com', 'twitter.com', 'vimeo.com', 'reddit.com', 'soundcloud.com', 'twitch.tv',
]);

const rate = new Map(); // حدّ بسيط: 30 طلباً/دقيقة لكل عنوان
function limited(ip) {
  const now = Date.now();
  const arr = (rate.get(ip) || []).filter((t) => now - t < 60000);
  arr.push(now);
  rate.set(ip, arr);
  return arr.length > 30;
}

function hostAllowed(host) {
  if (!ALLOWED.length) return true;
  host = host.toLowerCase();
  return ALLOWED.some((a) => host === a || host.endsWith('.' + a));
}

function isPrivateIp(ip) {
  if (net.isIPv4(ip)) {
    const [a, b] = ip.split('.').map(Number);
    return a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
  }
  const l = ip.toLowerCase();
  if (l.startsWith('::ffff:')) return isPrivateIp(l.slice(7));
  return l === '::1' || l === '::' || l.startsWith('fc') || l.startsWith('fd') || l.startsWith('fe80');
}

// يمنع الوصول إلى الشبكات الداخلية (SSRF)
async function assertPublic(u) {
  if (!['http:', 'https:'].includes(u.protocol)) throw new HttpError(422, 'invalid scheme');
  if (!hostAllowed(u.hostname)) throw new HttpError(422, 'host not allowed');
  const addrs = net.isIP(u.hostname) ? [{ address: u.hostname }] : await dns.lookup(u.hostname, { all: true });
  if (!addrs.length || (!process.env.ALLOW_PRIVATE && addrs.some((a) => isPrivateIp(a.address)))) throw new HttpError(422, 'private address');
}

class HttpError extends Error {
  constructor(status, msg) { super(msg); this.status = status; }
}

async function fetchSafe(url, opts = {}, hops = 0) {
  if (hops > 5) throw new HttpError(422, 'too many redirects');
  const u = new URL(url);
  await assertPublic(u);
  const res = await fetch(u, {
    ...opts,
    redirect: 'manual',
    headers: { 'user-agent': UA, accept: '*/*', ...(opts.headers || {}) },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (res.status >= 300 && res.status < 400 && res.headers.get('location')) {
    return fetchSafe(new URL(res.headers.get('location'), u).href, opts, hops + 1);
  }
  return res;
}

const decode = (s) => s.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;|&#x27;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');

function metas(html) {
  const out = {};
  for (const m of html.matchAll(/<meta\s+[^>]*>/gi)) {
    const tag = m[0];
    const key = (tag.match(/(?:property|name)\s*=\s*["']([^"']+)["']/i) || [])[1];
    const val = (tag.match(/content\s*=\s*["']([^"']*)["']/i) || [])[1];
    if (key && val != null) (out[key.toLowerCase()] ||= []).push(decode(val));
  }
  return out;
}

function jsonLdVideos(html) {
  const found = [];
  for (const m of html.matchAll(/<script[^>]+application\/ld\+json[^>]*>([\s\S]*?)<\/script>/gi)) {
    try {
      const walk = (n) => {
        if (Array.isArray(n)) return n.forEach(walk);
        if (n && typeof n === 'object') {
          const t = [].concat(n['@type'] || []);
          if (t.includes('VideoObject') || t.includes('AudioObject')) found.push(n);
          Object.values(n).forEach(walk);
        }
      };
      walk(JSON.parse(m[1]));
    } catch (_) { /* تجاهل JSON غير صالح */ }
  }
  return found;
}

function extOf(url, type = '') {
  const m = new URL(url).pathname.match(/\.([a-z0-9]{2,4})$/i);
  if (m) return m[1].toLowerCase();
  if (/mp4/.test(type)) return 'mp4';
  if (/webm/.test(type)) return 'webm';
  if (/mpeg|mp3/.test(type)) return 'mp3';
  if (/aac|m4a|mp4a/.test(type)) return 'm4a';
  return 'mp4';
}

const AUDIO_EXT = new Set(['mp3', 'm4a', 'aac', 'ogg', 'wav', 'flac']);

async function probe(url) {
  // يتحقق أن الرابط ملف وسائط فعلاً ويقرأ حجمه
  let res = await fetchSafe(url, { method: 'HEAD' }).catch(() => null);
  if (!res || !res.ok) res = await fetchSafe(url, { headers: { range: 'bytes=0-0' } });
  const type = res.headers.get('content-type') || '';
  const range = res.headers.get('content-range');
  const len = range ? Number(range.split('/').pop()) : Number(res.headers.get('content-length'));
  try { await res.body?.cancel(); } catch (_) {}
  const isMedia = /^(video|audio)\//i.test(type) || /octet-stream/i.test(type) && MEDIA_EXT.test(url);
  return { ok: res.ok && isMedia, type, size: Number.isFinite(len) && len > 0 ? len : undefined };
}

function fileName(u) {
  try { return decodeURIComponent(new URL(u).pathname.split('/').pop()) || 'فيديو'; } catch (_) { return 'فيديو'; }
}

function supportedExtractorHost(host) {
  host = host.toLowerCase().replace(/^www\./, '');
  return [...YTDLP_HOSTS].some((root) => host === root || host.endsWith('.' + root));
}

function formatLabel(f) {
  if (f.vcodec && f.vcodec !== 'none') {
    return f.height ? `${f.height}p` : (f.format_note || f.format_id || 'فيديو');
  }
  const bitrate = Number(f.abr || f.tbr || 0);
  return bitrate > 0 ? `${Math.round(bitrate)}k` : (f.format_note || 'صوت');
}

async function resolveWithYtDlp(pageUrl) {
  let stdout;
  try {
    ({ stdout } = await execFileAsync('yt-dlp', [
      '--ignore-config', '--no-playlist', '--no-warnings', '--no-progress',
      '--no-cookies', '--no-cache-dir', '--socket-timeout', '15',
      '--dump-single-json', '--skip-download', pageUrl,
    ], { timeout: 45000, maxBuffer: 8 * 1024 * 1024, windowsHide: true }));
  } catch (e) {
    if (e.code === 'ENOENT') return null; // yt-dlp اختياري في بيئات التطوير
    throw new HttpError(422, 'platform extraction unavailable');
  }
  let data;
  try { data = JSON.parse(stdout); } catch (_) { throw new HttpError(422, 'invalid extractor response'); }
  const formats = [];
  const seen = new Set();
  for (const f of (data.formats || [])) {
    if (!f.url || f.has_drm || !/^https?:\/\//i.test(f.url)) continue;
    const video = f.vcodec && f.vcodec !== 'none';
    const audio = f.acodec && f.acodec !== 'none';
    // لا نعرض مسارات فيديو بلا صوت تحتاج دمجاً أو صيغ DRM.
    if (!audio) continue;
    if (!video && !audio) continue;
    if (seen.has(f.url)) continue;
    seen.add(f.url);
    const headers = {};
    const raw = f.http_headers || {};
    for (const key of ['User-Agent', 'Referer', 'Accept', 'Accept-Language']) {
      const value = raw[key] || raw[key.toLowerCase()];
      if (typeof value === 'string' && value.length < 2048 && !/[\r\n]/.test(value)) headers[key] = value;
    }
    if (!headers['User-Agent']) headers['User-Agent'] = UA;
    const ext = /^[a-z0-9]{2,5}$/i.test(f.ext || '') ? f.ext.toLowerCase() : (video ? 'mp4' : 'm4a');
    formats.push({
      label: formatLabel(f), url: f.url, ext,
      size: Number.isFinite(f.filesize) ? f.filesize : (Number.isFinite(f.filesize_approx) ? f.filesize_approx : undefined),
      audioOnly: !video, httpHeaders: headers,
    });
  }
  // حدّ الخيارات لتجنّب إغراق واجهة الهاتف، مع إبقاء أفضل الخيارات المتاحة.
  const videoFormats = formats.filter((f) => !f.audioOnly).sort((a, b) => parseInt(b.label) - parseInt(a.label));
  const audioFormats = formats.filter((f) => f.audioOnly).sort((a, b) => parseInt(b.label) - parseInt(a.label));
  const selected = [...videoFormats.slice(0, 8), ...audioFormats.slice(0, 4)];
  if (!selected.length) throw new HttpError(422, 'no compatible public formats');
  return {
    title: String(data.title || data.id || 'وسائط').slice(0, 300),
    author: data.uploader || data.channel || undefined,
    duration: Number.isFinite(data.duration) ? Math.round(data.duration) : undefined,
    thumbnail: typeof data.thumbnail === 'string' && /^https?:\/\//i.test(data.thumbnail) ? data.thumbnail : undefined,
    formats: selected,
  };
}

async function resolve(pageUrl) {
  const u = new URL(pageUrl);
  await assertPublic(u);

  // 1) روابط المنصات المعروفة عبر yt-dlp (للمحتوى العام فقط؛ بلا ملفات تعريف ارتباط أو دخول).
  if (supportedExtractorHost(u.hostname)) {
    const extracted = await resolveWithYtDlp(u.href);
    if (extracted) return extracted;
  }

  // 2) رابط ملف مباشر
  if (MEDIA_EXT.test(u.pathname)) {
    const p = await probe(u.href);
    if (!p.ok) throw new HttpError(422, 'not media');
    const ext = extOf(u.href, p.type);
    return { title: fileName(u.href), formats: [{ label: ext.toUpperCase(), url: u.href, ext, size: p.size, audioOnly: AUDIO_EXT.has(ext) }] };
  }

  // 3) صفحة: نقرأ وسوم الوصف المفتوحة
  const res = await fetchSafe(u.href, { headers: { accept: 'text/html,application/xhtml+xml' } });
  if (!res.ok) throw new HttpError(422, 'page error');
  const ct = res.headers.get('content-type') || '';
  if (/^(video|audio)\//i.test(ct)) {
    const ext = extOf(u.href, ct);
    return { title: fileName(u.href), formats: [{ label: ext.toUpperCase(), url: u.href, ext, audioOnly: AUDIO_EXT.has(ext) }] };
  }
  if (!/html/i.test(ct)) throw new HttpError(422, 'unsupported content');
  const buf = Buffer.from(await res.arrayBuffer()).subarray(0, MAX_HTML);
  const html = buf.toString('utf8');
  const base = res.url || u.href;
  const abs = (s) => { try { return new URL(decode(s), base).href; } catch (_) { return null; } };

  const m = metas(html);
  const cand = new Map(); // url -> {label}
  const add = (s, label) => { const a = s && abs(s); if (a && /^https?:/.test(a) && !cand.has(a)) cand.set(a, label); };

  for (const k of ['og:video:secure_url', 'og:video:url', 'og:video', 'og:audio', 'twitter:player:stream']) (m[k] || []).forEach((v) => add(v));
  for (const v of jsonLdVideos(html)) { add(v.contentUrl); }
  for (const t of html.matchAll(/<(?:video|source|audio)\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>/gi)) {
    const h = (t[0].match(/\b(?:data-)?(?:res|label|title|size)\s*=\s*["']([^"']+)["']/i) || [])[1];
    add(t[1], h);
  }

  const formats = [];
  for (const [url, label] of cand) {
    if (/\.(m3u8|mpd)(\?|$)/i.test(url)) continue; // البث المجزّأ غير مدعوم
    try {
      const p = await probe(url);
      if (!p.ok) continue;
      const ext = extOf(url, p.type);
      formats.push({ label: label || ext.toUpperCase(), url, ext, size: p.size, audioOnly: AUDIO_EXT.has(ext) || /^audio\//i.test(p.type) });
    } catch (_) { /* نتخطى المرشح غير الصالح */ }
    if (formats.length >= 6) break;
  }
  if (!formats.length) throw new HttpError(422, 'no media found');

  const jl = jsonLdVideos(html)[0] || {};
  const title = (m['og:title'] || [])[0] || (html.match(/<title[^>]*>([^<]*)<\/title>/i) || [])[1] || jl.name || 'فيديو';
  const dur = jl.duration && /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?$/.exec(jl.duration);
  return {
    title: decode(String(title).trim()),
    author: (m['og:site_name'] || [])[0] || undefined,
    duration: dur ? Math.round((+dur[1] || 0) * 3600 + (+dur[2] || 0) * 60 + (+dur[3] || 0)) : undefined,
    thumbnail: abs((m['og:image'] || [])[0] || '') || undefined,
    formats,
  };
}

const server = http.createServer(async (req, res) => {
  const send = (status, body) => {
    res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
    res.end(JSON.stringify(body));
  };
  try {
    const u = new URL(req.url, 'http://x');
    if (u.pathname === '/health') return send(200, { ok: true });
    if (u.pathname !== '/resolve') return send(404, { error: 'not found' });
    const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').toString().split(',')[0].trim();
    if (limited(ip)) return send(429, { error: 'rate limited' });
    if (API_KEY && (req.headers['x-api-key'] || u.searchParams.get('key')) !== API_KEY) return send(401, { error: 'unauthorized' });
    const target = u.searchParams.get('url');
    if (!target) return send(422, { error: 'missing url' });
    send(200, await resolve(target));
  } catch (e) {
    if (e instanceof HttpError) return send(e.status, { error: e.message });
    send(422, { error: 'resolve failed' });
  }
});

if (require.main === module) server.listen(PORT, process.env.HOST_ONLY ? '127.0.0.1' : '0.0.0.0', () => console.log(`FlixGo resolver on :${PORT}`));
module.exports = { server, resolve, supportedExtractorHost, formatLabel };

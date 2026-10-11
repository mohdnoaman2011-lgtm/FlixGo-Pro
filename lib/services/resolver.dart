import 'package:dio/dio.dart';

import 'settings.dart';

class ResolveException implements Exception {
  ResolveException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VideoFormat {
  const VideoFormat({
    required this.label,
    required this.url,
    required this.ext,
    this.sizeBytes,
    this.audioOnly = false,
    this.httpHeaders = const {},
  });

  final String label; // 720p / 128k ...
  final String url; // رابط الملف المباشر
  final String ext;
  final int? sizeBytes;
  final bool audioOnly;
  /// Headers needed by some public media CDNs (never stores account cookies).
  final Map<String, String> httpHeaders;
}

class VideoInfo {
  const VideoInfo({
    required this.title,
    required this.formats,
    this.author,
    this.durationSec,
    this.thumbnail,
  });

  final String title;
  final String? author;
  final int? durationSec;
  final String? thumbnail;
  final List<VideoFormat> formats;

  List<VideoFormat> get video => formats.where((f) => !f.audioOnly).toList();
  List<VideoFormat> get audio => formats.where((f) => f.audioOnly).toList();
}

abstract class VideoResolver {
  Future<VideoInfo> resolve(String url);
}

/// يتعامل مع روابط ملفات الوسائط المباشرة (.mp4, .mp3 ...).
class DirectResolver implements VideoResolver {
  DirectResolver(this._dio);
  final Dio _dio;

  static const _videoExt = ['mp4', 'webm', 'mkv', 'mov', 'm4v', '3gp'];
  static const _audioExt = ['mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'];

  @override
  Future<VideoInfo> resolve(String url) async {
    final uri = Uri.parse(url);
    final ext = _extOf(uri.path);
    final known = _videoExt.contains(ext) || _audioExt.contains(ext);

    int? size;
    String? type;
    try {
      final r = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      type = r.headers.value('content-type');
      size = int.tryParse(r.headers.value('content-length') ?? '');
    } on DioException {
      if (!known) throw ResolveException('تعذّر الوصول إلى الرابط');
    }

    final isVideo = type?.startsWith('video/') ?? false;
    final isAudio = type?.startsWith('audio/') ?? false;
    if (!known && !isVideo && !isAudio) {
      throw ResolveException('ليس رابط ملف وسائط مباشراً');
    }

    final audio = _audioExt.contains(ext) || isAudio;
    final name = uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
        ? Uri.decodeComponent(uri.pathSegments.last)
        : uri.host;

    return VideoInfo(
      title: name,
      author: uri.host,
      formats: [
        VideoFormat(
          label: 'الأصلية',
          url: url,
          ext: ext.isEmpty ? (audio ? 'mp3' : 'mp4') : ext,
          sizeBytes: size,
          audioOnly: audio,
        ),
      ],
    );
  }

  String _extOf(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i + 1).toLowerCase();
  }
}

/// يسأل خادم استخراج تديره أنت. الصيغة في docs/BACKEND.md.
class BackendResolver implements VideoResolver {
  BackendResolver(this.baseUrl, this._dio);
  final String baseUrl;
  final Dio _dio;

  @override
  Future<VideoInfo> resolve(String url) async {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$base/resolve',
        queryParameters: {'url': url},
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 40),
        ),
      );
      final d = r.data;
      if (d == null) throw ResolveException('ردّ الخادم فارغ');
      final list = (d['formats'] as List? ?? [])
          .whereType<Map>()
          .map((m) => VideoFormat(
                label: '${m['label']}',
                url: '${m['url']}',
                ext: '${m['ext'] ?? 'mp4'}',
                sizeBytes: (m['size'] as num?)?.toInt(),
                audioOnly: m['audioOnly'] == true,
                httpHeaders: (m['httpHeaders'] as Map? ?? {}).map(
                  (k, v) => MapEntry('$k', '$v'),
                ),
              ))
          .toList();
      if (list.isEmpty) throw ResolveException('لا توجد صيغ متاحة لهذا الرابط');
      return VideoInfo(
        title: '${d['title'] ?? 'فيديو'}',
        author: d['author'] as String?,
        durationSec: (d['duration'] as num?)?.toInt(),
        thumbnail: d['thumbnail'] as String?,
        formats: list,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 422) {
        throw ResolveException('تعذّر استخراج هذا الرابط');
      }
      throw ResolveException('تعذّر الاتصال بخادم الاستخراج');
    }
  }
}

/// يجرّب الرابط المباشر أولاً، ثم خادم الاستخراج إن كان معرّفاً في الإعدادات.
class SmartResolver implements VideoResolver {
  SmartResolver() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  final Dio _dio;

  String? _platformName(String host) {
    final h = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (h == 'youtube.com' || h.endsWith('.youtube.com') || h == 'youtu.be') return 'YouTube';
    if (h == 'tiktok.com' || h.endsWith('.tiktok.com')) return 'TikTok';
    if (h == 'instagram.com' || h.endsWith('.instagram.com')) return 'Instagram';
    if (h == 'facebook.com' || h.endsWith('.facebook.com') || h == 'fb.watch') return 'Facebook';
    if (h == 'x.com' || h.endsWith('.x.com') || h == 'twitter.com' || h.endsWith('.twitter.com')) return 'X';
    if (h == 'vimeo.com' || h.endsWith('.vimeo.com')) return 'Vimeo';
    if (h == 'reddit.com' || h.endsWith('.reddit.com')) return 'Reddit';
    if (h == 'soundcloud.com' || h.endsWith('.soundcloud.com')) return 'SoundCloud';
    if (h == 'twitch.tv' || h.endsWith('.twitch.tv')) return 'Twitch';
    return null;
  }

  @override
  Future<VideoInfo> resolve(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw ResolveException('الرابط غير صالح');
    }
    try {
      return await DirectResolver(_dio).resolve(url);
    } on ResolveException {
      final backend = AppSettings.instance.backendUrl;
      if (backend.isEmpty) {
        final platform = _platformName(uri.host);
        throw ResolveException(
          platform == null
              ? 'هذا الرابط يحتاج خادم استخراج. أضف عنوانه من الإعدادات، أو استخدم رابط ملف مباشر.'
              : 'رابط $platform يحتاج خادم استخراج مفعّلاً. أضف عنوان الخادم من الإعدادات. يدعم الخادم الصفحات العامة المتوافقة فقط.',
        );
      }
      return BackendResolver(backend, _dio).resolve(url);
    }
  }
}

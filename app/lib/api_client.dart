import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, this.apiKey});

  final String baseUrl;
  final String? apiKey;
  final http.Client _http = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey != null) 'X-API-Key': apiKey!,
      };

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  dynamic _decode(http.Response r) {
    final body = utf8.decode(r.bodyBytes);
    final data = body.isEmpty ? null : jsonDecode(body);
    if (r.statusCode >= 400) {
      final detail = (data is Map && data['detail'] is String)
          ? data['detail'] as String
          : 'خطأ في الخادم (${r.statusCode})';
      throw ApiException(detail, r.statusCode);
    }
    return data;
  }

  Future<MediaInfo> analyze(String url) async {
    final r = await _http
        .post(_u('/api/analyze'), headers: _headers, body: jsonEncode({'url': url}))
        .timeout(const Duration(seconds: 60));
    return MediaInfo.fromJson(_decode(r) as Map<String, dynamic>);
  }

  Future<String> startDownload({
    required String url,
    required String kind,
    required int quality,
    required String format,
  }) async {
    final r = await _http.post(
      _u('/api/download'),
      headers: _headers,
      body: jsonEncode({'url': url, 'kind': kind, 'quality': quality, 'format': format}),
    );
    return (_decode(r) as Map<String, dynamic>)['job_id'] as String;
  }

  Future<JobStatus> status(String id) async {
    final r = await _http.get(_u('/api/jobs/$id'), headers: _headers);
    return JobStatus.fromJson(_decode(r) as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final r = await _http.delete(_u('/api/jobs/$id'), headers: _headers);
    _decode(r);
  }

  /// ينزّل الملف الجاهز من الخادم إلى [destPath] بالبث (دون تحميله كله في الذاكرة).
  Future<void> saveFile(
    String id,
    String destPath, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final req = http.Request('GET', _u('/api/files/$id'));
    if (apiKey != null) req.headers['X-API-Key'] = apiKey!;
    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw ApiException('تعذّر تنزيل الملف (${res.statusCode})', res.statusCode);
    }
    final file = File(destPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, res.contentLength);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}

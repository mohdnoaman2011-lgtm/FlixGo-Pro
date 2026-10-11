import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';
import 'notifier.dart';
import 'resolver.dart';
import 'settings.dart';

/// يدير طابور التحميل: تنزيل متدفق مع استئناف (Range)، وحد أقصى للتحميلات المتزامنة،
/// وحفظ السجل بين مرات التشغيل.
class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final instance = DownloadManager._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'FlixGo/1.0'},
  ));
  final tasks = <DownloadTask>[];
  final _tokens = <String, CancelToken>{};

  late SharedPreferences _prefs;
  late Directory _dir;

  Directory get dir => _dir;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    _dir = Directory('${base.path}/FlixGo');
    await _dir.create(recursive: true);

    final raw = _prefs.getString('tasks');
    if (raw != null) {
      for (final j in jsonDecode(raw) as List) {
        final t = DownloadTask.fromJson(Map<String, dynamic>.from(j as Map));
        if (t.state == TaskState.running || t.state == TaskState.queued) {
          t.state = TaskState.paused; // لا شيء يعمل بعد إعادة التشغيل
        }
        final f = File(t.path);
        if (t.state != TaskState.done && await f.exists()) {
          t.received = await f.length();
        }
        tasks.add(t);
      }
    }
  }

  // ───────────── واجهة الاستخدام ─────────────

  Future<DownloadTask> enqueue(VideoInfo info, VideoFormat f) async {
    await _checkNetwork();
    await Notifier.instance.requestPermissionOnce();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = _uniquePath('${_dir.path}/${_safeName(info.title, f.ext)}.${f.ext}');
    final t = DownloadTask(
      id: id,
      title: info.title,
      url: f.url,
      label: f.label,
      ext: f.ext,
      audioOnly: f.audioOnly,
      path: path,
      total: f.sizeBytes ?? 0,
    );
    tasks.insert(0, t);
    await _save();
    notifyListeners();
    _pump();
    return t;
  }

  void pause(String id) {
    final t = _find(id);
    if (t == null) return;
    if (t.state == TaskState.running) {
      t.state = TaskState.paused;
      _tokens[id]?.cancel();
    } else if (t.state == TaskState.queued) {
      t.state = TaskState.paused;
    }
    _save();
    notifyListeners();
  }

  /// استئناف أو إعادة محاولة (يكمل من حيث توقف إن دعم الخادم ذلك).
  Future<void> resume(String id) async {
    final t = _find(id);
    if (t == null) return;
    await _checkNetwork();
    t.state = TaskState.queued;
    t.error = null;
    await _save();
    notifyListeners();
    _pump();
  }

  Future<void> delete(String id) async {
    final t = _find(id);
    if (t == null) return;
    _tokens[id]?.cancel();
    tasks.remove(t);
    final f = File(t.path);
    if (await f.exists()) await f.delete();
    await _save();
    notifyListeners();
    _pump();
  }

  // ───────────── الداخل ─────────────

  DownloadTask? _find(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _checkNetwork() async {
    if (!AppSettings.instance.wifiOnly) return;
    final r = await Connectivity().checkConnectivity();
    final ok = r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
    if (!ok) throw ResolveException('الإعدادات تسمح بالتحميل عبر الواي فاي فقط');
  }

  void _pump() {
    final running = tasks.where((t) => t.state == TaskState.running).length;
    var slots = AppSettings.instance.maxConcurrent - running;
    // الأقدم أولاً
    for (final t in tasks.reversed) {
      if (slots <= 0) break;
      if (t.state == TaskState.queued) {
        slots--;
        t.state = TaskState.running;
        _run(t);
      }
    }
    _syncForeground(force: true);
    notifyListeners();
  }

  Future<void> _run(DownloadTask t) async {
    final token = CancelToken();
    _tokens[t.id] = token;
    final file = File(t.path);
    var offset = await file.exists() ? await file.length() : 0;
    IOSink? sink;

    try {
      final resp = await _dio.get<ResponseBody>(
        t.url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: offset > 0 ? {'range': 'bytes=$offset-'} : null,
          validateStatus: (s) => s == 200 || s == 206,
        ),
      );

      final partial = resp.statusCode == 206;
      if (!partial) offset = 0; // الخادم تجاهل Range: نبدأ من الصفر

      final range = resp.headers.value('content-range');
      final len = int.tryParse(resp.headers.value('content-length') ?? '');
      if (range != null && range.contains('/')) {
        t.total = int.tryParse(range.split('/').last) ?? t.total;
      } else if (len != null) {
        t.total = len + offset;
      }
      t.received = offset;

      sink = file.openWrite(mode: partial ? FileMode.append : FileMode.write);
      final clock = Stopwatch()..start();
      var lastTick = 0;
      var lastBytes = offset;

      await for (final chunk in resp.data!.stream) {
        sink.add(chunk);
        t.received += chunk.length;
        final now = clock.elapsedMilliseconds;
        if (now - lastTick >= 500) {
          t.speedBps = (t.received - lastBytes) / ((now - lastTick) / 1000);
          lastBytes = t.received;
          lastTick = now;
          _syncForeground();
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (t.total > 0 && t.received < t.total) {
        throw const FormatException('انقطع التحميل قبل اكتماله');
      }
      t.total = t.received;
      t.state = TaskState.done;
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        t.state = TaskState.failed;
        t.error = _dioMessage(e);
      }
    } on FormatException catch (e) {
      t.state = TaskState.failed;
      t.error = e.message;
    } catch (_) {
      t.state = TaskState.failed;
      t.error = 'تعذّر إكمال التحميل';
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      _tokens.remove(t.id);
      t.speedBps = 0;
      if (AppSettings.instance.notify) {
        if (t.state == TaskState.done) Notifier.instance.notifyDone(t);
        if (t.state == TaskState.failed) Notifier.instance.notifyFailed(t);
      }
      await _save();
      notifyListeners();
      _pump();
    }
  }

  DateTime _lastNotif = DateTime.fromMillisecondsSinceEpoch(0);

  /// يحدّث إشعار التقدم (والخدمة الأمامية) أو يوقفه حين لا يوجد تحميل جارٍ.
  void _syncForeground({bool force = false}) {
    final running = tasks.where((t) => t.state == TaskState.running).toList();
    if (running.isEmpty) {
      Notifier.instance.stopProgress();
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastNotif).inMilliseconds < 1000) return;
    _lastNotif = now;

    var received = 0;
    var total = 0;
    var known = true;
    for (final t in running) {
      received += t.received;
      if (t.total > 0) {
        total += t.total;
      } else {
        known = false;
      }
    }
    final pct = known && total > 0 ? (received * 100 / total).round().clamp(0, 100) : -1;
    final text = running.length == 1 ? running.first.title : '${running.length} تحميلات جارية';
    Notifier.instance.updateProgress(percent: pct, text: text);
  }

  String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
        return 'تعذّر الاتصال بالإنترنت';
      case DioExceptionType.badResponse:
        return 'رفض الخادم الطلب (${e.response?.statusCode})';
      default:
        return 'فشل التحميل';
    }
  }

  String _safeName(String title, String ext) {
    var s = title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_').trim();
    if (s.toLowerCase().endsWith('.${ext.toLowerCase()}')) {
      s = s.substring(0, s.length - ext.length - 1);
    }
    if (s.length > 80) s = s.substring(0, 80);
    return s.isEmpty ? 'video' : s;
  }

  String _uniquePath(String path) {
    if (!File(path).existsSync() && !tasks.any((t) => t.path == path)) return path;
    final dot = path.lastIndexOf('.');
    final stem = dot < 0 ? path : path.substring(0, dot);
    final ext = dot < 0 ? '' : path.substring(dot);
    var n = 1;
    while (File('$stem ($n)$ext').existsSync() || tasks.any((t) => t.path == '$stem ($n)$ext')) {
      n++;
    }
    return '$stem ($n)$ext';
  }

  Future<void> _save() => _prefs.setString(
        'tasks',
        jsonEncode(tasks.map((t) => t.toJson()).toList()),
      );
}

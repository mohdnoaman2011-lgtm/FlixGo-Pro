import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';
import 'models.dart';
import 'notifier.dart';
import 'settings_store.dart';
import 'storage.dart';

/// دورة التحميل: طابور محلي ← بدء على الخادم ← متابعة التقدم ← حفظ الملف على الجهاز.
class DownloadManager extends ChangeNotifier {
  DownloadManager(this._api, this._settings, this._notifier);

  final ApiClient _api;
  final SettingsStore _settings;
  final Notifier _notifier;
  final List<DownloadItem> items = [];
  final Map<String, Timer> _timers = {};
  final Set<String> _busy = {};

  Future<void> start(
    MediaInfo info, {
    required String kind,
    required int quality,
    required String format,
  }) async {
    if (_settings.wifiOnly && !await _onWifi()) {
      throw ApiException('التحميل عبر الواي فاي فقط مفعّل في الإعدادات');
    }
    items.insert(
      0,
      DownloadItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        url: info.url,
        title: info.title,
        thumbnail: info.thumbnail,
        kind: kind,
        quality: quality,
        format: format,
      ),
    );
    notifyListeners();
    _pump();
  }

  Future<bool> _onWifi() async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
  }

  /// يشغّل العناصر المنتظرة (الأقدم أولًا) ضمن حد التحميلات المتزامنة.
  void _pump() {
    var used = items.where((i) => i.started && i.isActive).length;
    for (final item in items.reversed) {
      if (used >= _settings.concurrent) break;
      if (!item.started && item.status == DlStatus.queued) {
        item.started = true;
        used++;
        _launch(item);
      }
    }
  }

  Future<void> _launch(DownloadItem item) async {
    try {
      final jobId = await _api.startDownload(
        url: item.url,
        kind: item.kind,
        quality: item.quality,
        format: item.format,
      );
      if (item.status == DlStatus.canceled) {
        _api.delete(jobId).catchError((_) {}); // أُلغي أثناء الإرسال
        return;
      }
      item.jobId = jobId;
      _timers[item.id] = Timer.periodic(const Duration(seconds: 1), (_) => _poll(item));
    } catch (e) {
      _finish(item, DlStatus.failed, e is ApiException ? e.message : 'تعذّر الاتصال بالخادم');
    }
  }

  void _finish(DownloadItem item, DlStatus status, [String? error]) {
    _stop(item.id);
    item
      ..status = status
      ..error = error;
    notifyListeners();
    _pump();
  }

  Future<void> _poll(DownloadItem item) async {
    final jobId = item.jobId;
    if (jobId == null || _busy.contains(item.id)) return;
    _busy.add(item.id);
    try {
      final s = await _api.status(jobId);
      if (!item.canCancel) return; // أُلغي أثناء الطلب
      item
        ..progress = s.progress
        ..speed = s.speed
        ..eta = s.eta;
      switch (s.status) {
        case 'queued':
          item.status = DlStatus.queued;
          break;
        case 'downloading':
          item.status = DlStatus.downloading;
          break;
        case 'processing':
          item.status = DlStatus.processing;
          break;
        case 'done':
          _stop(item.id);
          notifyListeners();
          await _save(item, s.filename);
          return;
        case 'error':
          _finish(item, DlStatus.failed, s.error);
          return;
        case 'canceled':
          _finish(item, DlStatus.canceled);
          return;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) _finish(item, DlStatus.failed, 'انتهت صلاحية المهمة على الخادم');
    } catch (_) {
      // انقطاع مؤقت في الشبكة: نعيد المحاولة في الدورة التالية
    } finally {
      _busy.remove(item.id);
      notifyListeners();
    }
  }

  Future<void> _save(DownloadItem item, String? filename) async {
    item
      ..status = DlStatus.saving
      ..progress = 0
      ..speed = null
      ..eta = null;
    notifyListeners();
    try {
      final dir = await downloadsDir();
      final path = await _uniquePath(dir, filename ?? '${item.id}.${item.format}');
      await _api.saveFile(item.jobId!, path, onProgress: (received, total) {
        if (total != null && total > 0) {
          item.progress = received / total * 100;
          notifyListeners();
        }
      });
      item
        ..localPath = path
        ..status = DlStatus.completed
        ..progress = 100;
      _api.delete(item.jobId!).catchError((_) {}); // حذف النسخة المؤقتة من الخادم
      if (_settings.saveToGallery && item.kind == 'video') {
        try {
          if (!await Gal.hasAccess()) await Gal.requestAccess();
          await Gal.putVideo(path);
        } catch (_) {}
      }
      if (_settings.notifyDone) _notifier.done(item.title);
    } catch (e) {
      item
        ..status = DlStatus.failed
        ..error = e is ApiException ? e.message : 'تعذّر حفظ الملف';
    }
    notifyListeners();
    _pump();
  }

  Future<void> cancel(DownloadItem item) async {
    final jobId = item.jobId;
    _stop(item.id);
    item.status = DlStatus.canceled;
    notifyListeners();
    if (jobId != null) {
      try {
        await _api.delete(jobId);
      } catch (_) {}
    }
    _pump();
  }

  void _stop(String id) => _timers.remove(id)?.cancel();

  Future<String> _uniquePath(Directory dir, String name) async {
    final stem = p.basenameWithoutExtension(name), ext = p.extension(name);
    var path = p.join(dir.path, name);
    for (var i = 1; await File(path).exists(); i++) {
      path = p.join(dir.path, '$stem ($i)$ext');
    }
    return path;
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

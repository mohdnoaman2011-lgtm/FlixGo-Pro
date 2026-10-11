import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/download_task.dart';

/// إشعار التقدم (خدمة أمامية تُبقي التطبيق حياً عند الخروج منه) وإشعارات الاكتمال والفشل.
class Notifier {
  Notifier._();
  static final instance = Notifier._();

  static const _fgId = 1;
  static const _icon = '@mipmap/ic_launcher';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _fgRunning = false;
  bool _permissionAsked = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings(_icon)),
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'progress',
      'التحميلات الجارية',
      importance: Importance.low,
      showBadge: false,
    ));
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'done',
      'اكتمال التحميل',
      importance: Importance.defaultImportance,
    ));
  }

  /// أندرويد 13+ يتطلب إذناً صريحاً؛ نطلبه مرة واحدة عند أول تحميل.
  Future<void> requestPermissionOnce() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await _android?.requestNotificationsPermission();
  }

  /// [percent] سالب = تقدم غير معروف.
  Future<void> updateProgress({required int percent, required String text}) async {
    const title = 'FlixGo — جارٍ التحميل';
    final details = AndroidNotificationDetails(
      'progress',
      'التحميلات الجارية',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: percent < 0 ? 0 : percent,
      indeterminate: percent < 0,
      icon: _icon,
    );
    try {
      if (!_fgRunning) {
        _fgRunning = true;
        await _android?.startForegroundService(
          _fgId,
          title,
          text,
          notificationDetails: details,
          foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeDataSync},
        );
      } else {
        await _plugin.show(_fgId, title, text, NotificationDetails(android: details));
      }
    } catch (_) {
      // رفض المستخدم الإشعارات أو فشلت الخدمة: التحميل يستمر بدون إشعار.
    }
  }

  Future<void> stopProgress() async {
    if (!_fgRunning) return;
    _fgRunning = false;
    try {
      await _android?.stopForegroundService();
    } catch (_) {}
  }

  Future<void> notifyDone(DownloadTask t) => _show(
        t,
        'اكتمل التحميل',
        t.title,
      );

  Future<void> notifyFailed(DownloadTask t) => _show(
        t,
        'فشل التحميل',
        '${t.title}${t.error == null ? '' : ' — ${t.error}'}',
      );

  Future<void> _show(DownloadTask t, String title, String body) async {
    try {
      await _plugin.show(
        t.id.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'done',
            'اكتمال التحميل',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: _icon,
          ),
        ),
      );
    } catch (_) {}
  }
}

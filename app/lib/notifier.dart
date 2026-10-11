import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(init);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  Future<void> done(String title) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'اكتمل التحميل',
        title,
        const NotificationDetails(
          android: AndroidNotificationDetails('downloads', 'التحميلات'),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}

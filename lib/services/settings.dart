import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  String get defaultQuality => _p.getString('quality') ?? '720p';
  bool get wifiOnly => _p.getBool('wifiOnly') ?? true;
  int get maxConcurrent => _p.getInt('maxConcurrent') ?? 3;
  bool get notify => _p.getBool('notify') ?? true;
  /// 'dark' | 'light' | 'system' (الافتراضي داكن)
  String get themeMode => _p.getString('theme') ?? 'dark';
  bool get copyToGallery => _p.getBool('gallery') ?? false;

  /// عنوان خادم الاستخراج الخاص بك (اختياري). مثال: https://example.com
  String get backendUrl => _p.getString('backendUrl') ?? '';

  Future<void> setDefaultQuality(String v) async {
    await _p.setString('quality', v);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool v) async {
    await _p.setBool('wifiOnly', v);
    notifyListeners();
  }

  Future<void> setCopyToGallery(bool v) async {
    await _p.setBool('gallery', v);
    notifyListeners();
  }

  Future<void> setThemeMode(String v) async {
    await _p.setString('theme', v);
    notifyListeners();
  }

  Future<void> setNotify(bool v) async {
    await _p.setBool('notify', v);
    notifyListeners();
  }

  Future<void> setMaxConcurrent(int v) async {
    await _p.setInt('maxConcurrent', v);
    notifyListeners();
  }

  Future<void> setBackendUrl(String v) async {
    await _p.setString('backendUrl', v.trim());
    notifyListeners();
  }
}

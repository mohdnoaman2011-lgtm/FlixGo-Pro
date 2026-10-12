import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الإعدادات المحفوظة على الجهاز.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._p);
  final SharedPreferences _p;

  static Future<SettingsStore> load() async =>
      SettingsStore._(await SharedPreferences.getInstance());

  static const _modes = [ThemeMode.dark, ThemeMode.light, ThemeMode.system];

  int get themeIndex {
    final v = _p.getInt('theme') ?? 0;
    return v >= 0 && v <= 2 ? v : 0;
  }

  ThemeMode get themeMode => _modes[themeIndex];
  int get defaultQuality => _p.getInt('quality') ?? 720;
  int get concurrent => _p.getInt('concurrent') ?? 3;
  bool get wifiOnly => _p.getBool('wifiOnly') ?? true;
  bool get notifyDone => _p.getBool('notify') ?? true;
  bool get saveToGallery => _p.getBool('gallery') ?? false;

  Future<void> setTheme(int v) => _set(() => _p.setInt('theme', v));
  Future<void> setQuality(int v) => _set(() => _p.setInt('quality', v));
  Future<void> setConcurrent(int v) => _set(() => _p.setInt('concurrent', v));
  Future<void> setWifiOnly(bool v) => _set(() => _p.setBool('wifiOnly', v));
  Future<void> setNotifyDone(bool v) => _set(() => _p.setBool('notify', v));
  Future<void> setSaveToGallery(bool v) => _set(() => _p.setBool('gallery', v));

  Future<void> _set(Future<bool> Function() write) async {
    await write();
    notifyListeners();
  }
}

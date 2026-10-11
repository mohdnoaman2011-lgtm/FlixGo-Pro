import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/download_manager.dart';
import 'services/notifier.dart';
import 'services/settings.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.init();
  await Notifier.instance.init();
  await DownloadManager.instance.init();
  runApp(const FlixGoApp());
}

class FlixGoApp extends StatefulWidget {
  const FlixGoApp({super.key});

  @override
  State<FlixGoApp> createState() => _FlixGoAppState();
}

class _FlixGoAppState extends State<FlixGoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.instance.addListener(_onSettings);
    _applyMode();
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // تغيّر مظهر النظام (يهمّ وضع «تلقائي»)
  @override
  void didChangePlatformBrightness() => _onSettings();

  void _applyMode() {
    final mode = AppSettings.instance.themeMode;
    C.dark = mode == 'system'
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
        : mode != 'light';
  }

  void _onSettings() {
    final before = C.dark;
    _applyMode();
    if (before == C.dark) return;
    setState(() {});
    // الألوان تُقرأ من C مباشرة، فنُجبر كل الويدجتات (حتى الثابتة) على إعادة البناء مع الحفاظ على حالتها
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlixGo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // واجهة عربية من اليمين لليسار
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Shell(),
    );
  }
}

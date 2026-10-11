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

class FlixGoApp extends StatelessWidget {
  const FlixGoApp({super.key});

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

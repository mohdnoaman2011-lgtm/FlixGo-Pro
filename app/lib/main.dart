import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'download_manager.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'notifier.dart';
import 'settings_screen.dart';
import 'settings_store.dart';
import 'splash_screen.dart';

// شغّل بـ: flutter run --dart-define=API_BASE=https://your-server --dart-define=API_KEY=xxxx
const kApiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');
const kApiKey = String.fromEnvironment('API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  final notifier = Notifier();
  await notifier.init();
  final api = ApiClient(baseUrl: kApiBase, apiKey: kApiKey.isEmpty ? null : kApiKey);
  runApp(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ChangeNotifierProvider(create: (_) => DownloadManager(api, settings, notifier)),
    ],
    child: const FlixGoApp(),
  ));
}

const _orange = Color(0xFFFF8A1F);

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: _orange,
          onPrimary: Color(0xFF1A0E00),
          surface: Color(0xFF141418),
          onSurface: Colors.white,
          onSurfaceVariant: Color(0xFF8A8F9C),
          outlineVariant: Color(0xFF26262D),
          surfaceContainerHighest: Color(0xFF22222A),
          secondary: _orange,
          onSecondary: Color(0xFF1A0E00),
          secondaryContainer: Color(0xFF3A2210),
          onSecondaryContainer: _orange,
        )
      : const ColorScheme.light(
          primary: _orange,
          onPrimary: Color(0xFF1A0E00),
          surface: Colors.white,
          onSurface: Color(0xFF101828),
          onSurfaceVariant: Color(0xFF667085),
          outlineVariant: Color(0xFFE1E4EA),
          surfaceContainerHighest: Color(0xFFE4E7EC),
          secondary: _orange,
          onSecondary: Color(0xFF1A0E00),
          secondaryContainer: Color(0xFFFFE6CC),
          onSecondaryContainer: Color(0xFFB45300),
        );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0B0B0E) : const Color(0xFFF4F5F7),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF111115) : Colors.white,
      indicatorColor: dark ? const Color(0xFF3A2210) : const Color(0xFFFFE6CC),
    ),
  );
}

class FlixGoApp extends StatelessWidget {
  const FlixGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlixGo',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: context.select<SettingsStore, ThemeMode>((s) => s.themeMode),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: SplashScreen(next: (_) => const Shell()),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: const [
        HomeScreen(),
        DownloadsScreen(),
        LibraryScreen(),
        SettingsScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'التحميلات'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'المكتبة'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

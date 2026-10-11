import 'package:flutter/material.dart';

import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  bool _splash = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_splash) return const _Splash();

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            DownloadsScreen(),
            LibraryScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.download_outlined), label: 'التحميلات'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'المكتبة'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // المجموعة مرفوعة قليلاً عن المنتصف لتوازن بصري أفضل
          Align(
            alignment: const Alignment(0, -0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                // نقصّ الهوامش الفارغة حول الشعار (الصورة بخلفية شفافة فتندمج مع الشاشة)
                SizedBox(
                  width: double.infinity,
                  height: 330,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: 426,
                      maxHeight: 426,
                      child: Transform.translate(
                        offset: const Offset(-3.4, 7.7),
                        child: Image.asset(
                          'assets/flixgo_logo.png',
                          width: 426,
                          height: 426,
                          semanticLabel: 'شعار FlixGo',
                        ),
                      ),
                    ),
                  ),
                ),
                const Text('حمّل فيديوهاتك بسهولة',
                    style: TextStyle(color: C.muted, fontSize: 15)),
              ],
            ),
          ),
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 120,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    backgroundColor: C.border,
                    color: C.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

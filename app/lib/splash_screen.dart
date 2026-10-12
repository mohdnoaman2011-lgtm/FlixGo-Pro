import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// شاشة البداية: الشعار يظهر تدريجيًا مع شريط تقدم، ثم تنتقل للتطبيق (أو بالضغط للتخطي).
/// تطابق لون وشعار شاشة البداية الأصلية (flutter_native_splash) لانتقال سلس.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  final WidgetBuilder next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF050509);
  static const _orange = Color(0xFFFF8A1F);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.35, curve: Curves.easeOut));
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
    _c.forward();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, _, __) => widget.next(ctx),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _go,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: Image.asset('assets/logo.png', width: 300, height: 300),
                ),
                const SizedBox(height: 56),
                SizedBox(
                  width: 120,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => LinearProgressIndicator(
                      value: _c.value,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                      backgroundColor: const Color(0xFF26262D),
                      color: _orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

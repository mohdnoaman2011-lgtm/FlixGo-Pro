import 'package:flutter/material.dart';

import '../theme.dart';

/// بطاقة بخلفية داكنة وحدود، تُستخدم في كل الشاشات.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children, this.padding = 16});

  final List<Widget> children;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: children,
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.text),
      );
}

/// صورة مصغرة: تعرض الصورة إن وُجدت، وإلا مربعاً بأيقونة.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.width,
    required this.height,
    this.duration,
    this.imageUrl,
    this.icon = Icons.play_arrow,
  });

  final double width;
  final double height;
  final String? duration;
  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(icon, color: C.muted);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: fallback),
            )
          else
            Center(child: fallback),
          if (duration != null)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(duration!, style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

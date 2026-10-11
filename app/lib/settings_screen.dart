import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_store.dart';
import 'storage.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          _Box(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المظهر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0, label: Text('داكن'), icon: Icon(Icons.dark_mode_outlined)),
                        ButtonSegment(value: 1, label: Text('فاتح'), icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(value: 2, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_outlined)),
                      ],
                      selected: {s.themeIndex},
                      onSelectionChanged: (v) => s.setTheme(v.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Box(children: [
            ListTile(
              title: const Text('الجودة الافتراضية'),
              subtitle: const Text('تُطبَّق على كل تحميل جديد إن توفرت'),
              trailing: _Choice(
                value: s.defaultQuality,
                values: const [360, 480, 720, 1080],
                label: (v) => '${v}p',
                onSelected: s.setQuality,
              ),
            ),
            ListTile(
              title: const Text('مجلد الحفظ'),
              subtitle: FutureBuilder<Directory>(
                future: downloadsDir(),
                builder: (_, snap) => Text(
                  snap.data?.path ?? '…',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
            ListTile(
              title: const Text('عدد التحميلات المتزامنة'),
              subtitle: Text('حتى ${s.concurrent} في وقت واحد'),
              trailing: _Choice(
                value: s.concurrent,
                values: const [1, 2, 3, 4, 5],
                label: (v) => '$v',
                onSelected: s.setConcurrent,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _Box(children: [
            SwitchListTile(
              title: const Text('التحميل عبر الواي فاي فقط'),
              value: s.wifiOnly,
              onChanged: s.setWifiOnly,
            ),
            SwitchListTile(
              title: const Text('إشعار عند اكتمال التحميل'),
              value: s.notifyDone,
              onChanged: s.setNotifyDone,
            ),
            SwitchListTile(
              title: const Text('نسخ الفيديوهات إلى معرض الصور'),
              value: s.saveToGallery,
              onChanged: s.setSaveToGallery,
            ),
          ]),
        ],
      ),
    );
  }
}

/// بطاقة مستديرة؛ تفصل بين عناصرها بخط رفيع.
class _Box extends StatelessWidget {
  const _Box({this.child, this.children});
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kids = children;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: kids == null
          ? child
          : Column(children: [
              for (var i = 0; i < kids.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                kids[i],
              ],
            ]),
    );
  }
}

/// شارة برتقالية تفتح قائمة اختيار.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.values,
    required this.label,
    required this.onSelected,
  });
  final int value;
  final List<int> values;
  final String Function(int) label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<int>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final v in values) PopupMenuItem(value: v, child: Text(label(v)))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withOpacity(.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label(value), style: TextStyle(color: primary, fontSize: 15)),
      ),
    );
  }
}

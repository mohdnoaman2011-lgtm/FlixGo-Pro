import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: ScreenTitle('الإعدادات')),
            const SizedBox(height: 16),
            _Group(children: [
              _ThemeRow(s.themeMode, s.setThemeMode),
            ]),
            const SizedBox(height: 16),
            _Group(children: [
              _ValueRow(
                title: 'الجودة الافتراضية',
                subtitle: 'تُطبَّق على كل تحميل جديد إن توفرت',
                value: s.defaultQuality,
                onTap: () async {
                  final v = await _pick<String>(
                    context,
                    'الجودة الافتراضية',
                    const ['360p', '480p', '720p', '1080p'],
                    (e) => e,
                  );
                  if (v != null) s.setDefaultQuality(v);
                },
              ),
              _ValueRow(
                title: 'مجلد الحفظ',
                subtitle: DownloadManager.instance.dir.path.replaceFirst(RegExp(r'^.*/Android/'), 'Android/'),
              ),
              _ValueRow(
                title: 'عدد التحميلات المتزامنة',
                subtitle: 'حتى ${s.maxConcurrent} في وقت واحد',
                value: '${s.maxConcurrent}',
                onTap: () async {
                  final v = await _pick<int>(
                    context,
                    'عدد التحميلات المتزامنة',
                    const [1, 2, 3, 4, 5],
                    (e) => '$e',
                  );
                  if (v != null) s.setMaxConcurrent(v);
                },
              ),
            ]),
            const SizedBox(height: 16),
            _Group(children: [
              _SwitchRow('التحميل عبر الواي فاي فقط', s.wifiOnly, s.setWifiOnly),
              _SwitchRow('إشعار عند اكتمال التحميل', s.notify, s.setNotify),
              _SwitchRow('نسخ الفيديوهات إلى معرض الصور', s.copyToGallery, s.setCopyToGallery),
              _ValueRow(
                title: 'خادم الاستخراج',
                subtitle: s.backendUrl.isEmpty ? 'غير مُعدّ — الروابط المباشرة فقط' : s.backendUrl,
                onTap: () => _editBackend(context, s),
              ),
            ]),
            const SizedBox(height: 16),
            Panel(children: [
              Text('حقوق المحتوى', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                'حمّل فقط المحتوى الذي تملك حق استخدامه أو الذي يسمح صاحبه بتنزيله، والتزم بشروط كل منصة.',
                style: TextStyle(fontSize: 13, color: C.muted, height: 1.7),
              ),
            ]),
          ],
        );
      },
    );
  }

  Future<T?> _pick<T>(BuildContext context, String title, List<T> options, String Function(T) label) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: C.surface,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final o in options)
            ListTile(title: Text(label(o)), onTap: () => Navigator.pop(c, o)),
        ]),
      ),
    );
  }

  Future<void> _editBackend(BuildContext context, AppSettings s) async {
    final ctrl = TextEditingController(text: s.backendUrl);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('خادم الاستخراج'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'عنوان خادم تديره أنت ويحوّل روابط الصفحات إلى روابط ملفات مباشرة. اتركه فارغاً لاستخدام الروابط المباشرة فقط.',
            style: TextStyle(fontSize: 13, color: C.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'https://example.com'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) s.setBackendUrl(v);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, color: C.border),
          children[i],
        ],
      ]),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.title, required this.subtitle, this.value, this.onTap});
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(spacing: 12, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          if (value != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: C.accentTint, borderRadius: BorderRadius.circular(999)),
              child: Text(value!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.accent)),
            ),
        ]),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow(this.mode, this.onChanged);
  final String mode;
  final Future<void> Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
        const Text('المظهر', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('داكن')),
              ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('فاتح')),
              ButtonSegment(value: 'system', icon: Icon(Icons.brightness_auto_outlined, size: 18), label: Text('تلقائي')),
            ],
            selected: {mode},
            onSelectionChanged: (v) => onChanged(v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? C.accentTint : Colors.transparent,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? C.accent : C.muted,
              ),
              side: WidgetStatePropertyAll(BorderSide(color: C.border2)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(this.title, this.value, this.onChanged);
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: C.accent,
          activeThumbColor: C.onAccent,
          inactiveTrackColor: C.border2,
          inactiveThumbColor: C.muted,
        ),
      ]),
    );
  }
}

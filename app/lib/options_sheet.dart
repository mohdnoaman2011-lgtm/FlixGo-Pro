import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'download_manager.dart';
import 'models.dart';
import 'settings_store.dart';

class OptionsSheet extends StatefulWidget {
  const OptionsSheet({super.key, required this.info});
  final MediaInfo info;

  @override
  State<OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<OptionsSheet> {
  String _kind = 'video';
  int? _quality;
  String _format = 'mp4';
  bool _starting = false;

  List<int> get _qualities {
    if (_kind == 'audio') return const [128, 192, 256, 320];
    const std = [360, 480, 720, 1080, 1440, 2160];
    final h = widget.info.heights;
    if (h.isEmpty) return const [360, 480, 720, 1080];
    final list = std.where((s) => h.any((x) => x >= s)).toList();
    return list.isEmpty ? [h.first] : list;
  }

  int get _q {
    final list = _qualities;
    if (_quality != null && list.contains(_quality)) return _quality!;
    if (_kind == 'audio') return list.contains(192) ? 192 : list.last;
    final pref = context.read<SettingsStore>().defaultQuality;
    final ok = list.where((q) => q <= pref);
    return ok.isEmpty ? list.first : ok.last;
  }

  List<String> get _formats => _kind == 'video' ? ['mp4', 'webm'] : ['mp3', 'm4a'];

  void _setKind(String k) => setState(() {
        _kind = k;
        _quality = null;
        _format = _formats.first;
      });

  Future<void> _start() async {
    setState(() => _starting = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<DownloadManager>().start(
            widget.info,
            kind: _kind,
            quality: _q,
            format: _format,
          );
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('بدأ التحميل')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _starting = false);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر الاتصال بالخادم')));
      if (mounted) setState(() => _starting = false);
    }
  }

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onTap(v),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info.thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    info.thumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(color: scheme.surfaceContainerHighest),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(info.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              [info.platform, info.durationText].where((e) => e.isNotEmpty).join(' · '),
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            _chips<String>(['video', 'audio'], _kind, (k) => k == 'video' ? 'فيديو' : 'صوت', _setKind),
            const SizedBox(height: 16),
            Text('الجودة', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            _chips<int>(_qualities, _q, (q) => _kind == 'video' ? '${q}p' : '${q}kbps',
                (q) => setState(() => _quality = q)),
            const SizedBox(height: 16),
            Text('الصيغة', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            _chips<String>(_formats, _format, (f) => f.toUpperCase(),
                (f) => setState(() => _format = f)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _starting ? null : _start,
                child: _starting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ابدأ التحميل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

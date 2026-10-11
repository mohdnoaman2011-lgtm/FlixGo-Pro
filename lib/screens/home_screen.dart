import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/download_manager.dart';
import '../services/resolver.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _url = TextEditingController();
  final _resolver = SmartResolver();

  VideoInfo? _info;
  bool _loading = false;
  String? _error;
  bool _audioOnly = false;
  VideoFormat? _fmt;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  List<VideoFormat> get _list =>
      _info == null ? const [] : (_audioOnly ? _info!.audio : _info!.video);

  VideoFormat? _pickDefault(List<VideoFormat> l) {
    if (l.isEmpty) return null;
    final q = AppSettings.instance.defaultQuality;
    return l.firstWhere((f) => f.label == q, orElse: () => l.last);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _url.text = text);
      _analyze();
    }
  }

  Future<void> _analyze() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _fmt = null;
    });
    try {
      final info = await _resolver.resolve(url);
      if (!mounted) return;
      setState(() {
        _info = info;
        _audioOnly = info.video.isEmpty;
        _fmt = _pickDefault(_audioOnly ? info.audio : info.video);
      });
    } on ResolveException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحليل الرابط');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    final info = _info;
    final f = _fmt;
    if (info == null || f == null) return;
    try {
      await DownloadManager.instance.enqueue(info, f);
      if (mounted) toast(context, 'أُضيف إلى التحميلات');
    } on ResolveException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('FlixGo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const Text('الصق الرابط وابدأ التحميل', style: TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 16),
        Panel(children: [
          const Text('رابط الفيديو', style: TextStyle(fontSize: 13, color: C.muted)),
          Row(spacing: 8, children: [
            Expanded(
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                textDirection: TextDirection.ltr,
                onSubmitted: (_) => _analyze(),
                decoration: InputDecoration(
                  hintText: 'الصق الرابط هنا',
                  filled: true,
                  fillColor: C.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: C.border2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: C.accent),
                  ),
                ),
              ),
            ),
            IconButton.filled(
              onPressed: _paste,
              tooltip: 'لصق من الحافظة',
              style: IconButton.styleFrom(
                backgroundColor: C.surface2,
                minimumSize: const Size(52, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.content_paste, color: C.text),
            ),
          ]),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _loading ? null : _analyze,
              style: FilledButton.styleFrom(
                backgroundColor: C.surface2,
                foregroundColor: C.text,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: C.accent),
                    )
                  : const Text('تحليل الرابط', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(fontSize: 13, color: C.danger, height: 1.6)),
        ]),
        if (_info != null) ...[
          const SizedBox(height: 16),
          _buildInfo(_info!),
        ],
        const SizedBox(height: 16),
        const Text(
          'حمّل فقط المحتوى الذي تملك حق استخدامه أو الذي يسمح صاحبه بتنزيله.',
          style: TextStyle(fontSize: 12, color: C.muted),
        ),
      ],
    );
  }

  Widget _buildInfo(VideoInfo info) {
    final hasBoth = info.video.isNotEmpty && info.audio.isNotEmpty;
    final list = _list;

    return Panel(children: [
      Row(spacing: 12, children: [
        Thumb(
          width: 112,
          height: 72,
          imageUrl: info.thumbnail,
          duration: info.durationSec == null ? null : fmtDuration(info.durationSec!),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(info.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (info.author != null)
              Text(info.author!, style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
      ]),
      if (hasBoth)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
          child: Row(spacing: 6, children: [
            _Seg('فيديو', !_audioOnly, () => setState(() {
                  _audioOnly = false;
                  _fmt = _pickDefault(info.video);
                })),
            _Seg('صوت فقط', _audioOnly, () => setState(() {
                  _audioOnly = true;
                  _fmt = _pickDefault(info.audio);
                })),
          ]),
        ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in list)
          SizedBox(
            width: 78,
            child: _QualityChip(
              f.label,
              f.sizeBytes == null ? '—' : fmtBytes(f.sizeBytes!),
              identical(_fmt, f),
              () => setState(() => _fmt = f),
            ),
          ),
      ]),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: _fmt == null ? null : _download,
          style: FilledButton.styleFrom(
            backgroundColor: C.accent,
            foregroundColor: C.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.download),
          label: Text('تحميل ${_fmt?.label ?? ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? C.onAccent : C.text2,
              )),
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip(this.label, this.size, this.selected, this.onTap);
  final String label;
  final String size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? C.accent : C.text2;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.accentTint : C.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? C.accent : C.border2, width: selected ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(size, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    );
  }
}

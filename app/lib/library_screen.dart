import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'download_manager.dart';
import 'models.dart';
import 'storage.dart';

const _exts = {'.mp4', '.webm', '.mkv', '.mp3', '.m4a'};

class LibFile {
  LibFile(this.file, this.size, this.modified);
  final File file;
  final int size;
  final DateTime modified;

  String get title => p.basenameWithoutExtension(file.path);
  String get ext => p.extension(file.path).replaceFirst('.', '').toLowerCase();
  bool get isAudio => ext == 'mp3' || ext == 'm4a';
  String get sizeText => size >= 1048576
      ? '${(size / 1048576).toStringAsFixed(1)} م.ب'
      : '${(size / 1024).toStringAsFixed(0)} ك.ب';
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  List<LibFile> _files = [];
  String _filter = 'all';
  int _seen = -1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final dir = await downloadsDir();
    final out = <LibFile>[];
    await for (final e in dir.list()) {
      if (e is File && _exts.contains(p.extension(e.path).toLowerCase())) {
        final st = await e.stat();
        out.add(LibFile(e, st.size, st.modified));
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    if (mounted) setState(() => _files = out);
  }

  Future<void> _open(LibFile f) async {
    final r = await OpenFilex.open(f.file.path);
    if (r.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('لا يوجد تطبيق لفتح هذا الملف')));
    }
  }

  Future<void> _delete(LibFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف؟'),
        content: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await f.file.delete();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    // نعيد قراءة المجلد كلما اكتمل تحميل جديد
    final doneCount = context
        .watch<DownloadManager>()
        .items
        .where((i) => i.status == DlStatus.completed)
        .length;
    if (doneCount != _seen) {
      _seen = doneCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }

    final scheme = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();
    final shown = _files
        .where((f) =>
            (_filter == 'all' || (_filter == 'audio') == f.isAudio) &&
            f.title.toLowerCase().contains(q))
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المكتبة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث عن فيديو',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final c in const [('all', 'الكل'), ('video', 'فيديو'), ('audio', 'صوت')])
                ChoiceChip(
                  label: Text(c.$2),
                  selected: _filter == c.$1,
                  onSelected: (_) => setState(() => _filter = c.$1),
                ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(_files.isEmpty ? 'المكتبة فارغة' : 'لا توجد نتائج',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    )
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final f = shown[i];
                        return Material(
                          color: scheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _open(f),
                            onLongPress: () => _delete(f),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(f.isAudio ? Icons.music_note_outlined : Icons.movie_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text('${f.ext.toUpperCase()} · ${f.sizeText}',
                                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('اضغط مطولاً على أي ملف لحذفه.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/download_task.dart';
import '../services/download_manager.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/panel.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  int _filter = 0;
  static const _filters = ['الكل', 'فيديو', 'صوت'];
  final _m = DownloadManager.instance;

  Future<void> _open(DownloadTask t) async {
    if (!File(t.path).existsSync()) {
      toast(context, 'الملف غير موجود');
      return;
    }
    final r = await OpenFilex.open(t.path);
    if (r.type != ResultType.done && mounted) toast(context, 'لا يوجد تطبيق لفتح هذا الملف');
  }

  Future<void> _confirmDelete(DownloadTask t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الملف؟'),
        content: Text(t.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await _m.delete(t.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _m,
      builder: (context, _) {
        final shown = _m.tasks.where((t) {
          if (t.state != TaskState.done) return false;
          final okFilter = _filter == 0 || (_filter == 1 ? !t.audioOnly : t.audioOnly);
          return okFilter && t.title.contains(_query);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
            const ScreenTitle('المكتبة'),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن فيديو',
                prefixIcon: Icon(Icons.search, color: C.muted),
                filled: true,
                fillColor: C.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: C.accent),
                ),
              ),
            ),
            Row(spacing: 8, children: [
              for (var i = 0; i < _filters.length; i++)
                ChoiceChip(
                  label: Text(_filters[i]),
                  selected: _filter == i,
                  onSelected: (_) => setState(() => _filter = i),
                  showCheckmark: false,
                  selectedColor: C.accent,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: _filter == i ? C.accent : C.border2),
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _filter == i ? C.onAccent : C.text2,
                  ),
                ),
            ]),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text('المكتبة فارغة', style: TextStyle(color: C.muted)))
                  : GridView.builder(
                      itemCount: shown.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 184,
                      ),
                      itemBuilder: (_, i) {
                        final t = shown[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _open(t),
                          onLongPress: () => _confirmDelete(t),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              LayoutBuilder(
                                builder: (_, c) => MediaThumb(
                                  width: c.maxWidth,
                                  height: 104,
                                  icon: t.audioOnly ? Icons.music_note : Icons.play_arrow,
                                ),
                              ),
                              Text(t.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${t.label} · ${fmtBytes(t.total)}',
                                  style: TextStyle(fontSize: 12, color: C.muted)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Text('اضغط مطولاً على أي ملف لحذفه.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ]),
        );
      },
    );
  }
}

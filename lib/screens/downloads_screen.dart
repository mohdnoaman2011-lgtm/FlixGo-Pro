import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../services/download_manager.dart';
import '../services/resolver.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/panel.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _tab = 0;
  final _m = DownloadManager.instance;

  bool _inTab(DownloadTask t, int tab) => switch (tab) {
        0 => t.state == TaskState.running || t.state == TaskState.queued || t.state == TaskState.paused,
        1 => t.state == TaskState.done,
        _ => t.state == TaskState.failed,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _m,
      builder: (context, _) {
        final counts = [for (var i = 0; i < 3; i++) _m.tasks.where((t) => _inTab(t, i)).length];
        final tabs = ['جارٍ (${counts[0]})', 'مكتملة (${counts[1]})', 'فشلت (${counts[2]})'];
        final items = _m.tasks.where((t) => _inTab(t, _tab)).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
            const ScreenTitle('التحميلات'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
              child: Row(spacing: 6, children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tab == i ? C.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(tabs[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _tab == i ? C.onAccent : C.text2,
                            )),
                      ),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('لا توجد عناصر', style: TextStyle(color: C.muted)),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _DownloadCard(items[i]),
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard(this.task);
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final m = DownloadManager.instance;
    final t = task;

    String sub;
    Color subColor = C.muted;
    switch (t.state) {
      case TaskState.running:
        sub = '${t.label} · ${t.ext.toUpperCase()}';
      case TaskState.queued:
        sub = 'في الانتظار';
      case TaskState.paused:
        sub = 'متوقف مؤقتاً';
        subColor = C.orange;
      case TaskState.failed:
        sub = t.error ?? 'فشل التحميل';
        subColor = C.danger;
      case TaskState.done:
        sub = '${t.label} · ${t.ext.toUpperCase()} · ${fmtBytes(t.total)}';
    }

    Future<void> guarded(Future<void> Function() f) async {
      try {
        await f();
      } on ResolveException catch (e) {
        if (context.mounted) toast(context, e.message);
      }
    }

    Widget action;
    switch (t.state) {
      case TaskState.running:
      case TaskState.queued:
        action = IconButton(
          tooltip: 'إيقاف مؤقت',
          onPressed: () => m.pause(t.id),
          icon: const Icon(Icons.pause),
        );
      case TaskState.paused:
        action = IconButton(
          tooltip: 'استئناف',
          onPressed: () => guarded(() => m.resume(t.id)),
          icon: const Icon(Icons.play_arrow, color: C.accent),
        );
      case TaskState.failed:
        action = IconButton(
          tooltip: 'إعادة المحاولة',
          onPressed: () => guarded(() => m.resume(t.id)),
          icon: const Icon(Icons.refresh, color: C.accent),
        );
      case TaskState.done:
        action = IconButton(
          tooltip: 'حذف',
          onPressed: () => m.delete(t.id),
          icon: const Icon(Icons.delete_outline, color: C.muted),
        );
    }

    final active = t.state == TaskState.running || t.state == TaskState.paused || t.state == TaskState.queued;
    final remaining = (t.total > 0 && t.speedBps > 0) ? ((t.total - t.received) / t.speedBps).round() : null;

    return Panel(padding: 14, children: [
      Row(spacing: 12, children: [
        MediaThumb(width: 88, height: 56, icon: t.audioOnly ? Icons.music_note : Icons.play_arrow),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(sub, style: TextStyle(fontSize: 12, color: subColor)),
          ]),
        ),
        action,
        if (t.state == TaskState.paused || t.state == TaskState.failed)
          IconButton(
            tooltip: 'حذف',
            onPressed: () => m.delete(t.id),
            icon: const Icon(Icons.delete_outline, color: C.muted),
          ),
      ]),
      if (active) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: t.progress,
            minHeight: 8,
            backgroundColor: C.border,
            color: t.state == TaskState.paused ? C.orange : C.accent,
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            t.progress == null ? fmtBytes(t.received) : '${(t.progress! * 100).round()}%',
            style: const TextStyle(fontSize: 12, color: C.muted),
          ),
          if (t.state == TaskState.running && t.speedBps > 0)
            Text(
              '${fmtSpeed(t.speedBps)}${remaining != null ? ' · متبقي ${fmtEta(remaining)}' : ''}',
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
        ]),
      ],
    ]);
  }
}

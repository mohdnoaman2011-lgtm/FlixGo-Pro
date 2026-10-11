import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'download_manager.dart';
import 'models.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<DownloadManager>().items;
    final running = items.where((i) => i.isActive).toList();
    final done = items.where((i) => i.status == DlStatus.completed).toList();
    final failed = items
        .where((i) => i.status == DlStatus.failed || i.status == DlStatus.canceled)
        .toList();
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('التحميلات',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
              ),
            ),
            TabBar(tabs: [
              Tab(text: 'جارٍ (${running.length})'),
              Tab(text: 'مكتملة (${done.length})'),
              Tab(text: 'فشلت (${failed.length})'),
            ]),
            Expanded(
              child: TabBarView(children: [
                _ItemList(items: running),
                _ItemList(items: done),
                _ItemList(items: failed),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});
  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('لا توجد عناصر',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ItemCard(item: items[i]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = item.status == DlStatus.failed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.thumbnail == null
                  ? ColoredBox(color: scheme.surfaceContainerHighest)
                  : Image.network(
                      item.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${item.format.toUpperCase()} · ${item.qualityLabel}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (item.isActive) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: item.progressValue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                const SizedBox(height: 6),
                Text(item.statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: failed ? const Color(0xFFFF6B5E) : scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (item.canCancel)
            IconButton(
              tooltip: 'إلغاء',
              icon: const Icon(Icons.close),
              onPressed: () => context.read<DownloadManager>().cancel(item),
            ),
        ],
      ),
    );
  }
}

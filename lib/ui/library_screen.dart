import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/native.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'widgets/common.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _q = '';
  int _filter = 0; // 0 all, 1 video, 2 audio

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(libraryItemsProvider);
    final items = all.where((i) {
      if (_filter == 1 && i.isAudio) return false;
      if (_filter == 2 && !i.isAudio) return false;
      final q = _q.trim().toLowerCase();
      return q.isEmpty || i.title.toLowerCase().contains(q) || (i.uploader ?? '').toLowerCase().contains(q);
    }).toList();

    final total = all.fold<int>(0, (a, i) => a + (i.size ?? 0));

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Library', style: Theme.of(context).textTheme.headlineMedium),
                if (all.isNotEmpty)
                  Text('${all.length} files · ${fmtBytes(total)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
            if (all.isNotEmpty)
              IconButton(
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _clearHistory(context),
              ),
          ]),
        ),
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search downloads',
                  prefixIcon: Icon(Icons.search_rounded),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                for (final (i, l) in ['All', 'Video', 'Audio'].indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(l), selected: _filter == i, onSelected: (_) => setState(() => _filter = i)),
                  ),
              ]),
            ]),
          ),
        Expanded(
          child: all.isEmpty
              ? const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'No downloads yet',
                  body: 'Finished files are saved to your Downloads folder and listed here.',
                )
              : items.isEmpty
                  ? const EmptyState(icon: Icons.search_off_rounded, title: 'No matches', body: 'Try a different search or filter.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _LibraryTile(item: items[i]),
                    ),
        ),
      ]),
    );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes the list only. Downloaded files stay on your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) ref.read(downloadsProvider.notifier).clearFinished();
  }
}

class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.item});
  final DownloadItem item;

  Future<void> _open(BuildContext context) async {
    if (item.uri == null) return;
    if (!await Native.I.fileExists(item.uri!)) {
      if (context.mounted) toast(context, 'File no longer exists');
      return;
    }
    try {
      await Native.I.openFile(item.uri!, item.mime);
    } catch (_) {
      if (context.mounted) toast(context, 'No app can open this file');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return PCard(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            SizedBox(
              width: 96,
              child: MediaThumb(url: item.thumbnail, aspect: 16 / 9, radius: 12, icon: item.isAudio ? Icons.music_note_rounded : Icons.movie_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 6),
                Text('${item.label}  ·  ${fmtBytes(item.size)}  ·  ${fmtAgo(item.createdAt)}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'open':
                    _open(context);
                  case 'share':
                    if (item.uri != null) Native.I.shareFile(item.uri!, item.mime);
                  case 'remove':
                    ref.read(downloadsProvider.notifier).remove(item);
                  case 'delete':
                    await ref.read(downloadsProvider.notifier).remove(item, deleteFile: true);
                    if (context.mounted) toast(context, 'File deleted');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Open')),
                PopupMenuItem(value: 'share', child: Text('Share')),
                PopupMenuItem(value: 'remove', child: Text('Remove from list')),
                PopupMenuItem(value: 'delete', child: Text('Delete file')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

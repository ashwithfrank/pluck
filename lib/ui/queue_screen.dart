import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'widgets/common.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(activeItemsProvider);
    final notifier = ref.read(downloadsProvider.notifier);
    final anyRunning = items.any((i) => i.isActive);
    final anyPaused = items.any((i) => i.status == Status.paused);

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
          child: Row(children: [
            Text('Queue', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            if (anyRunning)
              IconButton.filledTonal(
                tooltip: 'Pause all',
                onPressed: notifier.pauseAll,
                icon: const Icon(Icons.pause_rounded),
              ),
            if (anyPaused)
              IconButton.filledTonal(
                tooltip: 'Resume all',
                onPressed: notifier.resumeAll,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
          ]),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Nothing in the queue',
                  body: 'Paste a link on the Download tab. Active, waiting and failed downloads show up here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _QueueCard(item: items[i]),
                ),
        ),
      ]),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(downloadsProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final running = item.status == Status.running;

    final (String label, Color color) = switch (item.status) {
      Status.queued => ('Waiting', cs.onSurfaceVariant),
      Status.running => ('${item.progress.toStringAsFixed(0)}%', cs.primary),
      Status.paused => ('Paused', Brand.warn),
      Status.failed => ('Failed', Brand.bad),
      Status.cancelled => ('Cancelled', cs.onSurfaceVariant),
      Status.done => ('Done', Brand.ok),
    };

    return PCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 112,
              child: MediaThumb(url: item.thumbnail, aspect: 16 / 9, radius: 12, icon: item.isAudio ? Icons.music_note_rounded : Icons.movie_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Pill(item.label),
                  Pill(label, color: color),
                  if (running && item.eta != null) Pill(fmtEta(item.eta)),
                ]),
              ]),
            ),
          ]),
          if (running || item.status == Status.queued || item.status == Status.paused) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: running && item.progress > 0 ? item.progress / 100 : (item.status == Status.paused ? item.progress / 100 : null),
                color: item.status == Status.paused ? Brand.warn : null,
              ),
            ),
          ],
          if (item.status == Status.failed && item.error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(item.error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.bad, fontSize: 12.5, height: 1.3)),
            ),
          ],
          if (running && item.line.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_tidy(item.line), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
            ),
          ],
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (running || item.status == Status.queued)
              TextButton.icon(onPressed: () => n.pause(item), icon: const Icon(Icons.pause_rounded, size: 18), label: const Text('Pause')),
            if (item.status == Status.paused || item.status == Status.failed || item.status == Status.cancelled)
              TextButton.icon(
                onPressed: () => n.resume(item),
                icon: Icon(item.status == Status.paused ? Icons.play_arrow_rounded : Icons.refresh_rounded, size: 18),
                label: Text(item.status == Status.paused ? 'Resume' : 'Retry'),
              ),
            TextButton.icon(
              onPressed: () => (running || item.status == Status.queued) ? _cancelAndRemove(context, n) : n.remove(item),
              icon: Icon(running || item.status == Status.queued ? Icons.stop_rounded : Icons.delete_outline_rounded, size: 18),
              label: Text(running || item.status == Status.queued ? 'Cancel' : 'Remove'),
              style: TextButton.styleFrom(foregroundColor: Brand.bad),
            ),
          ]),
        ]),
      ),
    );
  }

  void _cancelAndRemove(BuildContext context, DownloadsNotifier n) {
    n.cancel(item);
    n.remove(item);
  }

  /// yt-dlp's raw line is verbose ("[download]  42.0% of ..."); trim the tag.
  String _tidy(String s) => s.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '').trim();
}

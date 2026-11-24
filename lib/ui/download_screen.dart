import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/ui_state.dart';
import 'widgets/choice_panel.dart';
import 'widgets/common.dart';
import 'widgets/playlist_sheet.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  late DownloadChoice _choice;
  List<PlaylistEntry>? _picked; // playlist subset

  @override
  void initState() {
    super.initState();
    _choice = ref.read(settingsProvider).choice.copy();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _analyze([String? raw]) async {
    final url = extractUrl(raw ?? _ctl.text) ?? (raw ?? _ctl.text).trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      toast(context, 'That doesn\'t look like a link');
      return;
    }
    _ctl.text = url;
    _focus.unfocus();
    _picked = null;
    // Apply saved defaults fresh for every new link.
    _choice = ref.read(settingsProvider).choice.copy();
    await ref.read(analyzeProvider.notifier).run(url);
    if (mounted) setState(() {});
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = extractUrl(data?.text);
    if (url == null) {
      if (mounted) toast(context, 'Clipboard has no link');
      return;
    }
    _analyze(url);
  }

  void _clear() {
    _ctl.clear();
    _picked = null;
    ref.read(analyzeProvider.notifier).clear();
    setState(() {});
  }

  Future<void> _download(MediaInfo info) async {
    final targets = info.isPlaylist ? (_picked ?? info.entries) : null;
    if (info.isPlaylist && (targets == null || targets.isEmpty)) {
      toast(context, 'Choose at least one video');
      return;
    }
    final n = await ref.read(downloadsProvider.notifier).enqueue(info: info, choice: _choice.copy(), entries: targets);
    if (!mounted) return;
    toast(context, n == 1 ? 'Added to queue' : '$n items added to queue');
    _clear();
    ref.read(tabProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    // Links arriving via Share → Pluck
    ref.listen<String?>(incomingUrlProvider, (_, url) {
      if (url == null) return;
      ref.read(incomingUrlProvider.notifier).state = null;
      _analyze(url);
    });

    final engine = ref.watch(engineProvider);
    final analysis = ref.watch(analyzeProvider);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _header(context, engine),
          const SizedBox(height: 22),
          TextField(
            controller: _ctl,
            focusNode: _focus,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _analyze(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Paste a video or playlist link',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: _ctl.text.isEmpty
                  ? IconButton(tooltip: 'Paste', icon: const Icon(Icons.content_paste_rounded), onPressed: _paste)
                  : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: _clear),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (!engine.ready || analysis.isLoading || _ctl.text.trim().isEmpty) ? null : () => _analyze(),
            icon: analysis.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary.withValues(alpha: 0.6)))
                : const Icon(Icons.search_rounded),
            label: Text(analysis.isLoading ? 'Reading link…' : 'Analyze'),
          ),
          const SizedBox(height: 8),
          analysis.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => _error(context, e.toString()),
            data: (info) => info == null ? _empty(context, engine) : _result(context, info),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, EngineState engine) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.south_rounded, color: cs.onPrimary, size: 26),
      ),
      const SizedBox(width: 12),
      Text('Pluck', style: Theme.of(context).textTheme.headlineMedium),
      const Spacer(),
      if (engine.error != null)
        ActionChip(
          avatar: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Engine error'),
          onPressed: () => ref.read(engineProvider.notifier).retry(),
        )
      else if (!engine.ready)
        const Pill('Starting engine…')
      else
        Pill('yt-dlp ${engine.version}', icon: Icons.bolt_rounded, color: cs.primary),
    ]);
  }

  Widget _empty(BuildContext context, EngineState engine) {
    final cs = Theme.of(context).colorScheme;
    if (engine.error != null) {
      return _error(context, 'Could not start the download engine.\n${engine.error}');
    }
    Widget tip(IconData i, String t, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Icon(i, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: Theme.of(context).textTheme.titleMedium),
                Text(s, style: TextStyle(color: cs.onSurfaceVariant, height: 1.35)),
              ]),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(children: [
        tip(Icons.share_rounded, 'Share straight in', 'Use Share → Pluck from any app or browser.'),
        tip(Icons.queue_play_next_rounded, 'Queue & resume', 'Downloads keep running in the background and can be paused.'),
        tip(Icons.playlist_add_check_rounded, 'Playlists', 'Pick exactly which videos you want.'),
        tip(Icons.language_rounded, '1000+ sites', 'Anything yt-dlp supports. Update the engine from Settings.'),
      ]),
    );
  }

  Widget _error(BuildContext context, String msg) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PCard(
        color: cs.errorContainer.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_rounded, color: cs.error),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: const TextStyle(height: 1.35))),
          ]),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, MediaInfo info) {
    final cs = Theme.of(context).colorScheme;
    final count = info.isPlaylist ? (_picked ?? info.entries).length : 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      PCard(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            MediaThumb(url: info.thumbnail, aspect: 16 / 9, radius: 0),
            if (info.duration != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                  child: Text(fmtDuration(info.duration),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            if (info.isPlaylist)
              Positioned(
                left: 10,
                bottom: 10,
                child: Pill('${info.entries.length} videos', icon: Icons.playlist_play_rounded, color: Colors.white, onImage: true),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              if (info.uploader != null) ...[
                const SizedBox(height: 4),
                Text(info.uploader!, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
              if (info.isPlaylist) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await pickPlaylistEntries(context, info);
                    if (r != null) setState(() => _picked = r);
                  },
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(_picked == null ? 'Choose videos (all selected)' : 'Choose videos (${_picked!.length} selected)'),
                ),
              ],
            ]),
          ),
        ]),
      ),
      const Section('Format'),
      ChoicePanel(choice: _choice, info: info.isPlaylist ? null : info, onChanged: () => setState(() {})),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _download(info),
        icon: const Icon(Icons.download_rounded),
        label: Text(count > 1 ? 'Download $count · ${_choice.label}' : 'Download · ${_choice.label}'),
      ),
    ]);
  }
}

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import 'common.dart';

/// Inline "what do you want?" panel: Video/Audio, quality, container, extras.
class ChoicePanel extends StatelessWidget {
  const ChoicePanel({
    super.key,
    required this.choice,
    required this.onChanged,
    this.info,
  });

  final DownloadChoice choice;
  final MediaInfo? info;
  final VoidCallback onChanged;

  static const _fallbackHeights = [2160, 1440, 1080, 720, 480, 360];

  void _set(VoidCallback f) {
    f();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heights = (info != null && info!.hasVideo) ? info!.heights : _fallbackHeights;
    // keep list short & useful: standard steps that exist, plus the true max
    final steps = <int>{
      for (final h in heights)
        if (const [2160, 1440, 1080, 720, 480, 360, 240].contains(h)) h,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    if (steps.isEmpty && heights.isNotEmpty) steps.add(heights.first);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<Kind>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(0, 48),
            selectedBackgroundColor: cs.primary,
            selectedForegroundColor: cs.onPrimary,
          ),
          segments: const [
            ButtonSegment(value: Kind.video, icon: Icon(Icons.movie_outlined), label: Text('Video')),
            ButtonSegment(value: Kind.audio, icon: Icon(Icons.graphic_eq_rounded), label: Text('Audio')),
          ],
          selected: {choice.kind},
          onSelectionChanged: (s) => _set(() => choice.kind = s.first),
        ),
      ),
      const SizedBox(height: 18),
      if (choice.kind == Kind.video) ..._video(context, steps) else ..._audio(context),
      const SizedBox(height: 6),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('Extras', style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(_extrasSummary(), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          children: [
            _sw('Embed metadata', 'Title, artist, date', choice.embedMetadata,
                (v) => _set(() => choice.embedMetadata = v)),
            _sw('Embed thumbnail', 'Cover art inside the file', choice.embedThumbnail,
                (v) => _set(() => choice.embedThumbnail = v)),
            _sw('Chapters', 'Keep chapter markers', choice.chapters, (v) => _set(() => choice.chapters = v)),
            if (choice.kind == Kind.video)
              _sw('Subtitles', 'Embed English subs when available', choice.subtitles,
                  (v) => _set(() => choice.subtitles = v)),
            _sw('SponsorBlock', 'Cut sponsor / self-promo segments', choice.sponsorblock,
                (v) => _set(() => choice.sponsorblock = v)),
          ],
        ),
      ),
    ]);
  }

  String _extrasSummary() {
    final on = <String>[
      if (choice.embedMetadata) 'metadata',
      if (choice.embedThumbnail) 'thumbnail',
      if (choice.chapters) 'chapters',
      if (choice.subtitles && choice.kind == Kind.video) 'subtitles',
      if (choice.sponsorblock) 'SponsorBlock',
    ];
    return on.isEmpty ? 'None' : on.join(' · ');
  }

  Widget _sw(String t, String s, bool v, ValueChanged<bool> c) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(t),
        subtitle: Text(s),
        value: v,
        onChanged: c,
      );

  List<Widget> _video(BuildContext context, List<int> steps) {
    final cs = Theme.of(context).colorScheme;
    return [
      Text('Quality', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(context, 'Best', choice.height == null, () => _set(() => choice.height = null),
            sub: info?.estimate(info!.heights.isNotEmpty ? info!.heights.first : 0)),
        for (final h in steps)
          _chip(context, _hLabel(h), choice.height == h, () => _set(() => choice.height = h),
              sub: info?.estimate(h)),
      ]),
      const SizedBox(height: 18),
      Text('Container', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [
        for (final c in VideoContainer.values)
          ChoiceChip(
            label: Text(c.name.toUpperCase()),
            selected: choice.container == c,
            onSelected: (_) => _set(() => choice.container = c),
          ),
      ]),
      if (choice.container == VideoContainer.mp4)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('MP4 plays everywhere. MKV keeps any codec untouched.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
    ];
  }

  List<Widget> _audio(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lossless = choice.audio == AudioFormat.flac || choice.audio == AudioFormat.wav;
    return [
      Text('Format', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in AudioFormat.values)
          ChoiceChip(
            label: Text(a.name.toUpperCase()),
            selected: choice.audio == a,
            onSelected: (_) => _set(() => choice.audio = a),
          ),
      ]),
      const SizedBox(height: 18),
      if (!lossless) ...[
        Row(children: [
          Text('Quality', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          const Spacer(),
          Pill(choice.audioQuality == 0 ? 'Best' : choice.audioQuality >= 5 ? 'Small file' : 'Balanced'),
        ]),
        Slider(
          value: (10 - choice.audioQuality).toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) => _set(() => choice.audioQuality = 10 - v.round()),
        ),
      ] else
        Text('Lossless output. Files are large.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ];
  }

  String _hLabel(int h) => switch (h) {
        2160 => '4K',
        1440 => '2K',
        _ => '${h}p',
      };

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap, {int? sub}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: selected ? cs.onPrimary : cs.onSurface, fontSize: 14.5)),
          if (sub != null)
            Text('≈ ${fmtBytes(sub)}',
                style: TextStyle(
                    fontSize: 10.5,
                    color: (selected ? cs.onPrimary : cs.onSurfaceVariant).withValues(alpha: 0.85))),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Network thumbnail with a tidy placeholder; no extra packages needed.
class MediaThumb extends StatelessWidget {
  const MediaThumb({super.key, this.url, this.radius = 14, this.aspect, this.icon = Icons.movie_outlined});
  final String? url;
  final double radius;
  final double? aspect;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: cs.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(icon, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
    );
    Widget child = (url == null || url!.isEmpty)
        ? placeholder
        : Image.network(
            url!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (_, w, p) => p == null ? w : placeholder,
          );
    if (aspect != null) child = AspectRatio(aspectRatio: aspect!, child: child);
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon, this.onImage = false});
  final String text;
  final Color? color;
  final IconData? icon;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: onImage ? Colors.black.withValues(alpha: 0.65) : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.2)),
      ]),
    );
  }
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 38, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        ]),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Color statusColor(BuildContext context, String s) {
  switch (s) {
    case 'done':
      return Brand.ok;
    case 'failed':
      return Brand.bad;
    case 'paused':
      return Brand.warn;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

/// Rounded outlined surface. Used instead of the theme's cardTheme so the
/// project builds on any Flutter 3.27+ without CardTheme/CardThemeData churn.
class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.color, this.clipBehavior = Clip.none});
  final Widget child;
  final Color? color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color ?? cs.surfaceContainerLow,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

String fmtBytes(num? b) {
  if (b == null || b <= 0) return '—';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${u[i]}';
}

String fmtDuration(num? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final s = seconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

String fmtEta(int? seconds) {
  if (seconds == null || seconds < 0) return '';
  return '${fmtDuration(seconds)} left';
}

String fmtAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

final _urlRe = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// Pulls the first URL out of arbitrary shared text.
String? extractUrl(String? text) {
  if (text == null) return null;
  return _urlRe.firstMatch(text)?.group(0);
}

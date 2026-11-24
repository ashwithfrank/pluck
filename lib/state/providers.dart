import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/native.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';

// ------------------------------------------------------------------ engine

class EngineState {
  const EngineState({this.ready = false, this.version, this.aria = false, this.error});
  final bool ready;
  final String? version;
  final bool aria;
  final String? error;
}

class EngineNotifier extends Notifier<EngineState> {
  @override
  EngineState build() {
    _init();
    return const EngineState();
  }

  Future<void> _init() async {
    try {
      final r = await Native.I.init();
      state = EngineState(ready: true, version: r.version, aria: r.aria);
    } catch (e) {
      state = EngineState(error: e.toString());
    }
  }

  Future<void> retry() async {
    state = const EngineState();
    await _init();
  }

  /// Returns a human-readable result.
  Future<String> update() async {
    final nightly = ref.read(settingsProvider).nightly;
    try {
      final r = await Native.I.updateBinary(nightly: nightly);
      final v = await Native.I.init();
      state = EngineState(ready: true, version: v.version, aria: v.aria);
      return r == 'ALREADY_UP_TO_DATE' ? 'Already up to date (${v.version})' : 'Updated to ${v.version}';
    } catch (e) {
      return 'Update failed: $e';
    }
  }
}

final engineProvider = NotifierProvider<EngineNotifier, EngineState>(EngineNotifier.new);

// ---------------------------------------------------------------- settings

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    _load();
    return Settings(defaults: DownloadChoice());
  }

  Future<void> _load() async => state = await Settings.load();

  void edit(void Function(Settings s) change) {
    final s = state.copy();
    change(s);
    state = s;
    s.save();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ----------------------------------------------------------------- analyze

class AnalyzeNotifier extends Notifier<AsyncValue<MediaInfo?>> {
  int _token = 0;

  @override
  AsyncValue<MediaInfo?> build() => const AsyncData(null);

  Future<void> run(String url) async {
    final my = ++_token;
    state = const AsyncLoading();
    try {
      final raw = await Native.I.analyze(url);
      if (my != _token) return;
      state = AsyncData(MediaInfo.fromJson(raw, url));
    } catch (e, st) {
      if (my != _token) return;
      state = AsyncError(_friendly(e), st);
    }
  }

  void clear() {
    _token++;
    state = const AsyncData(null);
  }

  static String _friendly(Object e) {
    final s = e is PlatformException ? (e.message ?? e.toString()) : e.toString();
    final lines = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return 'Unknown error';
    final line = lines.lastWhere(
      (l) => l.startsWith('ERROR') || l.contains('Unsupported URL'),
      orElse: () => lines.first,
    );
    return line.replaceFirst(RegExp(r'^.*ERROR:\s*'), '').trim();
  }
}

final analyzeProvider =
    NotifierProvider<AnalyzeNotifier, AsyncValue<MediaInfo?>>(AnalyzeNotifier.new);

// --------------------------------------------------------------- downloads

class DownloadsNotifier extends Notifier<List<DownloadItem>> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _shareCtl = StreamController<String>.broadcast();

  /// URLs shared into the app from other apps ("Share → Pluck").
  Stream<String> get shared => _shareCtl.stream;

  @override
  List<DownloadItem> build() {
    ref.onDispose(() {
      _sub?.cancel();
      _shareCtl.close();
    });
    _boot();
    return const [];
  }

  Future<void> _boot() async {
    final saved = await Db.I.all();
    final live = {for (final m in await Native.I.snapshot()) m['id'] as String: m};

    for (final i in saved) {
      final m = live[i.id];
      if (m != null) {
        _apply(i, m);
      } else if (i.status == Status.running) {
        // process died while we were away: keep the .part files, let the user resume
        i.status = Status.paused;
      }
    }
    state = saved;

    _sub = Native.I.events.listen(_onEvent);
    final first = extractUrl(await Native.I.initialShare());
    if (first != null) _shareCtl.add(first);
    _pump();
  }

  void _onEvent(Map<String, dynamic> e) {
    if (e['type'] == 'share') {
      final u = extractUrl(e['text'] as String?);
      if (u != null) _shareCtl.add(u);
      return;
    }
    if (e['type'] != 'progress') return;
    final idx = state.indexWhere((i) => i.id == e['id']);
    if (idx < 0) return;
    final item = state[idx];
    final before = item.status;
    _apply(item, e);
    state = [...state];
    if (item.status != before && item.status != Status.running) {
      Db.I.upsert(item);
      _pump();
      if (item.status == Status.done || item.status == Status.failed) {
        Native.I.forget(item.id);
      }
    }
  }

  void _apply(DownloadItem i, Map<String, dynamic> m) {
    i.status = switch (m['status']) {
      'done' => Status.done,
      'failed' => Status.failed,
      'cancelled' => Status.cancelled,
      'paused' => Status.paused,
      _ => Status.running,
    };
    i.progress = ((m['progress'] as num?)?.toDouble() ?? i.progress).clamp(0, 100).toDouble();
    final eta = (m['eta'] as num?)?.toInt();
    i.eta = (eta == null || eta < 0) ? null : eta;
    i.line = (m['line'] as String?) ?? i.line;
    i.uri = m['uri'] as String? ?? i.uri;
    i.name = m['name'] as String? ?? i.name;
    i.size = (m['size'] as num?)?.toInt() ?? i.size;
    i.mime = m['mime'] as String? ?? i.mime;
    i.error = m['error'] as String? ?? i.error;
  }

  // ------------------------------------------------------------- scheduling

  void _pump() {
    final max = ref.read(settingsProvider).maxParallel;
    var running = state.where((i) => i.status == Status.running).length;
    // oldest queued first
    final queued = state.where((i) => i.status == Status.queued).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final i in queued) {
      if (running >= max) break;
      _launch(i);
      running++;
    }
  }

  Future<void> _launch(DownloadItem i) async {
    final s = ref.read(settingsProvider);
    i.status = Status.running;
    i.error = null;
    state = [...state];
    try {
      await Native.I.start(
        id: i.id,
        url: i.url,
        title: i.title,
        options: i.options,
        subdir: s.subdir,
        aria: s.useAria,
        connections: s.connections,
      );
    } catch (e) {
      i.status = Status.failed;
      i.error = e.toString();
      state = [...state];
      Db.I.upsert(i);
    }
  }

  // -------------------------------------------------------------------- API

  /// Adds one download per target. Returns how many were queued.
  Future<int> enqueue({
    required MediaInfo info,
    required DownloadChoice choice,
    List<PlaylistEntry>? entries,
  }) async {
    final opts = DownloadItem.encodeOptions(choice.toOptions());
    final now = DateTime.now();
    final targets = entries ??
        [PlaylistEntry(url: info.url, title: info.title, duration: info.duration, thumbnail: info.thumbnail)];

    final items = <DownloadItem>[];
    for (var n = 0; n < targets.length; n++) {
      final t = targets[n];
      items.add(DownloadItem(
        id: '${now.microsecondsSinceEpoch}_$n',
        url: t.url,
        title: t.title,
        label: choice.label,
        optionsJson: opts,
        // keep playlist order: +n ms
        createdAt: now.add(Duration(milliseconds: n)),
        thumbnail: t.thumbnail ?? info.thumbnail,
        uploader: info.uploader,
        duration: t.duration,
        isAudio: choice.kind == Kind.audio,
      ));
    }
    for (final i in items) {
      await Db.I.upsert(i);
    }
    state = [...items.reversed, ...state];
    _pump();
    return items.length;
  }

  void pause(DownloadItem i) {
    if (i.status == Status.running) {
      Native.I.cancel(i.id, pause: true);
    } else if (i.status == Status.queued) {
      i.status = Status.paused;
      state = [...state];
      Db.I.upsert(i);
    }
  }

  void resume(DownloadItem i) {
    if (i.status != Status.paused && i.status != Status.failed && i.status != Status.cancelled) return;
    i.status = Status.queued;
    i.error = null;
    state = [...state];
    Db.I.upsert(i);
    _pump();
  }

  void cancel(DownloadItem i) {
    if (i.status == Status.running) {
      Native.I.cancel(i.id);
    } else {
      i.status = Status.cancelled;
      state = [...state];
      Db.I.upsert(i);
    }
  }

  Future<void> remove(DownloadItem i, {bool deleteFile = false}) async {
    if (i.status == Status.running) Native.I.cancel(i.id);
    if (deleteFile && i.uri != null) await Native.I.deleteFile(i.uri!);
    await Db.I.remove(i.id);
    Native.I.forget(i.id);
    state = state.where((x) => x.id != i.id).toList();
    _pump();
  }

  Future<void> clearFinished() async {
    await Db.I.clearFinished();
    state = state.where((i) => i.status != Status.done).toList();
  }

  void pauseAll() {
    for (final i in [...state]) {
      if (i.isActive) pause(i);
    }
  }

  void resumeAll() {
    for (final i in [...state]) {
      if (i.status == Status.paused) resume(i);
    }
  }

  /// Settings changed (e.g. parallel limit) — let waiting items start.
  void repump() => _pump();

  @visibleForTesting
  void debugSet(List<DownloadItem> items) => state = items;
}

final downloadsProvider = NotifierProvider<DownloadsNotifier, List<DownloadItem>>(DownloadsNotifier.new);

final activeItemsProvider = Provider<List<DownloadItem>>((ref) {
  final all = ref.watch(downloadsProvider);
  return all.where((i) => i.status != Status.done).toList();
});

final libraryItemsProvider = Provider<List<DownloadItem>>((ref) {
  final all = ref.watch(downloadsProvider);
  final done = all.where((i) => i.status == Status.done).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return done;
});

import 'dart:async';

import 'package:flutter/services.dart';

/// Thin typed wrapper over the Kotlin side (pluck/engine + pluck/events).
class Native {
  Native._();
  static final Native I = Native._();

  static const _engine = MethodChannel('pluck/engine');
  static const _events = EventChannel('pluck/events');

  Stream<Map<String, dynamic>>? _stream;

  /// Broadcast stream of {type: progress|share, ...} maps.
  Stream<Map<String, dynamic>> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map))
      .asBroadcastStream();

  Future<({String version, bool aria})> init() async {
    final r = Map<String, dynamic>.from(await _engine.invokeMethod('init') as Map);
    return (version: r['version'] as String, aria: r['aria2'] as bool);
  }

  Future<String> analyze(String url, {bool noPlaylist = false}) async {
    return await _engine.invokeMethod<String>('analyze', {'url': url, 'noPlaylist': noPlaylist}) ?? '{}';
  }

  Future<void> start({
    required String id,
    required String url,
    required String title,
    required List<MapEntry<String, String?>> options,
    required String subdir,
    required bool aria,
    required int connections,
  }) {
    return _engine.invokeMethod('start', {
      'id': id,
      'url': url,
      'title': title,
      'subdir': subdir,
      'aria': aria,
      'connections': connections,
      'options': [
        for (final o in options) {'k': o.key, 'v': o.value},
      ],
    });
  }

  Future<void> cancel(String id, {bool pause = false}) =>
      _engine.invokeMethod('cancel', {'id': id, 'pause': pause});

  Future<void> forget(String id) => _engine.invokeMethod('forget', {'id': id});

  Future<List<Map<String, dynamic>>> snapshot() async {
    final r = await _engine.invokeMethod<List<dynamic>>('snapshot') ?? [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> updateBinary({required bool nightly}) async =>
      await _engine.invokeMethod<String>('update', {'nightly': nightly}) ?? 'UNKNOWN';

  Future<int> sdkInt() async => await _engine.invokeMethod<int>('sdkInt') ?? 0;

  Future<String?> initialShare() => _engine.invokeMethod<String>('initialShare');

  Future<bool> fileExists(String uri) async => await _engine.invokeMethod<bool>('fileExists', {'uri': uri}) ?? false;

  Future<bool> deleteFile(String uri) async => await _engine.invokeMethod<bool>('deleteFile', {'uri': uri}) ?? false;

  Future<void> openFile(String uri, String? mime) => _engine.invokeMethod('openFile', {'uri': uri, 'mime': mime});

  Future<void> shareFile(String uri, String? mime) => _engine.invokeMethod('shareFile', {'uri': uri, 'mime': mime});
}

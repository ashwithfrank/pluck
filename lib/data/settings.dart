import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Settings {
  Settings({
    this.maxParallel = 2,
    this.useAria = true,
    this.connections = 8,
    this.nightly = false,
    this.subdir = 'Pluck',
    this.themeMode = 'system',
    this.defaults,
  });

  int maxParallel;
  bool useAria;
  int connections;
  bool nightly;
  String subdir;
  String themeMode; // system | light | dark
  DownloadChoice? defaults;

  DownloadChoice get choice => defaults ?? DownloadChoice();

  Settings copy() => Settings(
        maxParallel: maxParallel,
        useAria: useAria,
        connections: connections,
        nightly: nightly,
        subdir: subdir,
        themeMode: themeMode,
        defaults: defaults?.copy(),
      );

  static Future<Settings> load() async {
    final sp = await SharedPreferences.getInstance();
    final d = DownloadChoice(
      kind: sp.getString('d.kind') == 'audio' ? Kind.audio : Kind.video,
      container: VideoContainer.values.firstWhere(
        (c) => c.name == sp.getString('d.container'),
        orElse: () => VideoContainer.mp4,
      ),
      audio: AudioFormat.values.firstWhere(
        (c) => c.name == sp.getString('d.audio'),
        orElse: () => AudioFormat.mp3,
      ),
      embedMetadata: sp.getBool('d.meta') ?? true,
      embedThumbnail: sp.getBool('d.thumb') ?? false,
      sponsorblock: sp.getBool('d.sb') ?? false,
      chapters: sp.getBool('d.chap') ?? true,
    );
    return Settings(
      maxParallel: sp.getInt('maxParallel') ?? 2,
      useAria: sp.getBool('useAria') ?? true,
      connections: sp.getInt('connections') ?? 8,
      nightly: sp.getBool('nightly') ?? false,
      subdir: sp.getString('subdir') ?? 'Pluck',
      themeMode: sp.getString('themeMode') ?? 'system',
      defaults: d,
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('maxParallel', maxParallel);
    await sp.setBool('useAria', useAria);
    await sp.setInt('connections', connections);
    await sp.setBool('nightly', nightly);
    await sp.setString('subdir', subdir);
    await sp.setString('themeMode', themeMode);
    final d = choice;
    await sp.setString('d.kind', d.kind.name);
    await sp.setString('d.container', d.container.name);
    await sp.setString('d.audio', d.audio.name);
    await sp.setBool('d.meta', d.embedMetadata);
    await sp.setBool('d.thumb', d.embedThumbnail);
    await sp.setBool('d.sb', d.sponsorblock);
    await sp.setBool('d.chap', d.chapters);
  }
}

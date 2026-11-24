import 'dart:convert';

// ---------------------------------------------------------------- media info

class PlaylistEntry {
  PlaylistEntry({required this.url, required this.title, this.duration, this.thumbnail});
  final String url;
  final String title;
  final double? duration;
  final String? thumbnail;
}

class MediaInfo {
  MediaInfo({
    required this.url,
    required this.title,
    this.uploader,
    this.thumbnail,
    this.duration,
    this.heights = const [],
    this.videoSizes = const {},
    this.audioSize,
    this.entries = const [],
    this.isPlaylist = false,
  });

  final String url;
  final String title;
  final String? uploader;
  final String? thumbnail;
  final double? duration;

  /// Available video heights, highest first.
  final List<int> heights;

  /// Approx. bytes of the best video-only stream at each height.
  final Map<int, int> videoSizes;
  final int? audioSize;
  final bool isPlaylist;
  final List<PlaylistEntry> entries;

  bool get hasVideo => heights.isNotEmpty;

  int? estimate(int height) {
    final v = videoSizes[height];
    if (v == null) return null;
    return v + (audioSize ?? 0);
  }

  factory MediaInfo.fromJson(String raw, String originalUrl) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final isPlaylist = j['_type'] == 'playlist' || j['entries'] != null;
    final thumb = _thumb(j);

    if (isPlaylist) {
      final entries = <PlaylistEntry>[];
      for (final e in (j['entries'] as List? ?? const [])) {
        if (e is! Map) continue;
        final u = (e['url'] ?? e['webpage_url'])?.toString();
        if (u == null) continue;
        final full = u.startsWith('http')
            ? u
            : (e['ie_key'] == 'Youtube' ? 'https://www.youtube.com/watch?v=$u' : u);
        entries.add(PlaylistEntry(
          url: full,
          title: (e['title'] ?? 'Untitled').toString(),
          duration: (e['duration'] as num?)?.toDouble(),
          thumbnail: _thumb(Map<String, dynamic>.from(e)),
        ));
      }
      return MediaInfo(
        url: originalUrl,
        title: (j['title'] ?? 'Playlist').toString(),
        uploader: (j['uploader'] ?? j['channel'])?.toString(),
        thumbnail: thumb ?? (entries.isNotEmpty ? entries.first.thumbnail : null),
        entries: entries,
        isPlaylist: true,
      );
    }

    final sizes = <int, int>{};
    int? audio;
    for (final f in (j['formats'] as List? ?? const [])) {
      if (f is! Map) continue;
      final size = ((f['filesize'] ?? f['filesize_approx']) as num?)?.toInt();
      final hasV = f['vcodec'] != null && f['vcodec'] != 'none';
      final hasA = f['acodec'] != null && f['acodec'] != 'none';
      final h = (f['height'] as num?)?.toInt();
      if (hasV && h != null && h > 0) {
        final prev = sizes[h];
        sizes[h] = size == null ? (prev ?? 0) : (prev == null || size > prev ? size : prev);
      } else if (hasA && !hasV && size != null) {
        if (audio == null || size > audio) audio = size;
      }
    }
    final heights = sizes.keys.toList()..sort((a, b) => b.compareTo(a));

    return MediaInfo(
      url: (j['webpage_url'] ?? originalUrl).toString(),
      title: (j['title'] ?? 'Untitled').toString(),
      uploader: (j['uploader'] ?? j['channel'])?.toString(),
      thumbnail: thumb,
      duration: (j['duration'] as num?)?.toDouble(),
      heights: heights,
      videoSizes: {for (final e in sizes.entries) if (e.value > 0) e.key: e.value},
      audioSize: audio,
    );
  }

  static String? _thumb(Map<String, dynamic> j) {
    final t = j['thumbnail']?.toString();
    if (t != null && t.isNotEmpty) return t;
    final list = j['thumbnails'];
    if (list is List && list.isNotEmpty) {
      final last = list.last;
      if (last is Map && last['url'] != null) return last['url'].toString();
    }
    return null;
  }
}

// ------------------------------------------------------------ user choices

enum Kind { video, audio }

enum VideoContainer { mp4, mkv, webm }

enum AudioFormat { mp3, m4a, opus, flac, wav }

class DownloadChoice {
  DownloadChoice({
    this.kind = Kind.video,
    this.height, // null = best available
    this.container = VideoContainer.mp4,
    this.audio = AudioFormat.mp3,
    this.audioQuality = 0, // 0 = best ... 10 = worst (yt-dlp --audio-quality)
    this.embedMetadata = true,
    this.embedThumbnail = false,
    this.subtitles = false,
    this.subLangs = 'en.*',
    this.sponsorblock = false,
    this.chapters = true,
  });

  Kind kind;
  int? height;
  VideoContainer container;
  AudioFormat audio;
  int audioQuality;
  bool embedMetadata;
  bool embedThumbnail;
  bool subtitles;
  String subLangs;
  bool sponsorblock;
  bool chapters;

  DownloadChoice copy() => DownloadChoice(
        kind: kind,
        height: height,
        container: container,
        audio: audio,
        audioQuality: audioQuality,
        embedMetadata: embedMetadata,
        embedThumbnail: embedThumbnail,
        subtitles: subtitles,
        subLangs: subLangs,
        sponsorblock: sponsorblock,
        chapters: chapters,
      );

  String get label {
    if (kind == Kind.audio) return audio.name.toUpperCase();
    final q = height == null ? 'Best' : '${height}p';
    return '$q ${container.name.toUpperCase()}';
  }

  /// Translates the choice into yt-dlp arguments.
  List<MapEntry<String, String?>> toOptions() {
    final o = <MapEntry<String, String?>>[];
    if (kind == Kind.audio) {
      o.add(const MapEntry('-f', 'ba/b'));
      o.add(const MapEntry('-x', null));
      o.add(MapEntry('--audio-format', audio.name));
      if (audio != AudioFormat.flac && audio != AudioFormat.wav) {
        o.add(MapEntry('--audio-quality', '$audioQuality'));
      }
    } else {
      final h = height;
      final f = h == null ? 'bv*+ba/b' : 'bv*[height<=$h]+ba/b[height<=$h]';
      o.add(MapEntry('-f', f));
      switch (container) {
        case VideoContainer.mp4:
          // Prefer mp4/m4a streams so the merge is a cheap remux.
          o.add(const MapEntry('-S', 'ext:mp4:m4a'));
          o.add(const MapEntry('--merge-output-format', 'mp4'));
        case VideoContainer.mkv:
          o.add(const MapEntry('--merge-output-format', 'mkv'));
        case VideoContainer.webm:
          o.add(const MapEntry('-S', 'ext:webm'));
          o.add(const MapEntry('--merge-output-format', 'webm'));
      }
    }
    if (embedMetadata) o.add(const MapEntry('--embed-metadata', null));
    if (embedThumbnail) {
      o.add(const MapEntry('--embed-thumbnail', null));
    }
    if (chapters) o.add(const MapEntry('--embed-chapters', null));
    if (subtitles && kind == Kind.video) {
      o.add(const MapEntry('--write-subs', null));
      o.add(const MapEntry('--write-auto-subs', null));
      o.add(MapEntry('--sub-langs', subLangs));
      o.add(const MapEntry('--embed-subs', null));
    }
    if (sponsorblock) {
      o.add(const MapEntry('--sponsorblock-remove', 'sponsor,selfpromo,interaction'));
    }
    return o;
  }
}

// ------------------------------------------------------------- queue items

enum Status { queued, running, paused, done, failed, cancelled }

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.label,
    required this.optionsJson,
    required this.createdAt,
    this.thumbnail,
    this.uploader,
    this.duration,
    this.isAudio = false,
    this.status = Status.queued,
    this.progress = 0,
    this.eta,
    this.line = '',
    this.uri,
    this.name,
    this.size,
    this.mime,
    this.error,
  });

  final String id;
  final String url;
  String title;
  final String label;
  final String optionsJson;
  final DateTime createdAt;
  final String? thumbnail;
  final String? uploader;
  final double? duration;
  final bool isAudio;

  Status status;
  double progress;
  int? eta;
  String line;
  String? uri;
  String? name;
  int? size;
  String? mime;
  String? error;

  bool get isActive => status == Status.queued || status == Status.running;
  bool get isFinished => status == Status.done;

  List<MapEntry<String, String?>> get options => [
        for (final e in (jsonDecode(optionsJson) as List))
          MapEntry((e as Map)['k'] as String, e['v'] as String?),
      ];

  static String encodeOptions(List<MapEntry<String, String?>> o) =>
      jsonEncode([for (final e in o) {'k': e.key, 'v': e.value}]);

  Map<String, Object?> toRow() => {
        'id': id,
        'url': url,
        'title': title,
        'label': label,
        'options': optionsJson,
        'created_at': createdAt.millisecondsSinceEpoch,
        'thumbnail': thumbnail,
        'uploader': uploader,
        'duration': duration,
        'is_audio': isAudio ? 1 : 0,
        'status': status.name,
        'progress': progress,
        'uri': uri,
        'name': name,
        'size': size,
        'mime': mime,
        'error': error,
      };

  factory DownloadItem.fromRow(Map<String, Object?> r) => DownloadItem(
        id: r['id'] as String,
        url: r['url'] as String,
        title: r['title'] as String,
        label: r['label'] as String,
        optionsJson: r['options'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        thumbnail: r['thumbnail'] as String?,
        uploader: r['uploader'] as String?,
        duration: (r['duration'] as num?)?.toDouble(),
        isAudio: (r['is_audio'] as int) == 1,
        status: Status.values.firstWhere((s) => s.name == r['status'], orElse: () => Status.failed),
        progress: (r['progress'] as num?)?.toDouble() ?? 0,
        uri: r['uri'] as String?,
        name: r['name'] as String?,
        size: r['size'] as int?,
        mime: r['mime'] as String?,
        error: r['error'] as String?,
      );
}

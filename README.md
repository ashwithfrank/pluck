# Pluck

A clean Android GUI for **yt-dlp**, built with Flutter + Kotlin. By AlphaOmega Studio.

Paste or share a link, pick Video/Audio and a quality, and Pluck downloads it in the background with a queue, pause/resume, notifications and a library. The yt-dlp, FFmpeg and aria2 binaries run on-device through [youtubedl-android](https://github.com/yausername/youtubedl-android).

## Setup (5 minutes)

This zip contains only the files that are new or changed. Layer it onto a fresh Flutter project:

```bash
flutter create --org com.aos --project-name pluck --platforms android pluck
cd pluck
# unzip pluck.zip here and allow overwrites (lib/, android/app/, pubspec.yaml)
flutter pub get
flutter run            # real device recommended; first launch unpacks the engine
```

Requirements: Flutter 3.27 or newer (Dart 3.4+), JDK 17, a device on Android 7.0 (API 24) or newer.

Two things to check if the Gradle sync complains:

1. `android/app/build.gradle.kts` replaces the generated one. If your Flutter version generated a different layout (for example Groovy `build.gradle`), copy the `defaultConfig.minSdk = 24`, `abiFilters`, `packaging.jniLibs.useLegacyPackaging = true` and the three `youtubedl-android` dependencies into yours.
2. Library version is `0.16.0` (`io.github.junkfood02.youtubedl-android`, Maven Central). If a newer one exists, bump the `ytdl` value in `dependencies`.

Build a release APK per CPU: `flutter build apk --split-per-abi` (most phones want `arm64-v8a`).

## Architecture

```
Flutter UI  ──MethodChannel "pluck/engine"──►  MainActivity
            ◄─EventChannel  "pluck/events"──   Engine (yt-dlp, aria2, FFmpeg)
                                                 ├─ DownloadService  (foreground service)
                                                 ├─ Notifier         (progress + done notifications)
                                                 └─ MediaSaver       (MediaStore → Downloads/Pluck)
```

- **Dart** owns the queue, scheduling (max parallel), persistence (sqflite) and all UI state (Riverpod).
- **Kotlin** owns the processes. Each job gets a stable work folder, so pause/resume continues from the `.part` files.
- Finished files are copied to `Downloads/<folder>/` through MediaStore (scoped storage safe, no storage permission on Android 10+).

## Features

- Paste, clipboard button, or Share → Pluck from any app
- Video quality picker with size estimates, MP4/MKV/WebM, or audio-only (MP3, M4A, Opus, FLAC, WAV)
- Playlists with per-video selection
- Queue with pause, resume, retry, cancel; limit of simultaneous downloads
- aria2 multi-connection mode
- Embed metadata, thumbnail, chapters, subtitles; SponsorBlock
- Library with search, filter, open, share, delete
- In-app yt-dlp updater (stable or nightly)
- Light, dark and auto themes

## Distribution and legal

Google Play does not allow YouTube downloaders. Publish through **GitHub Releases** or **F-Droid**. Because the bundled library is GPL-3.0, release this project's source under GPL-3.0 too. The About screen links the licenses of yt-dlp, FFmpeg, aria2 and youtubedl-android. The app tells users to download only content they own or have permission to save.

## Known limits (v1)

- No login/cookies support yet (age-gated or private videos fail).
- Pause on a download that is merging or converting restarts that last step.
- Queue order is oldest-first; no drag-to-reorder yet.

# Pluck: design notes

## Product

One job: turn a link into a file with the fewest decisions. Everything advanced is one tap deeper.

**Audience:** people who want yt-dlp's power without a terminal.
**Principle:** the default path is paste → Download. Choices appear only after the link is understood.

## Screens

| Tab | Purpose | Key elements |
|---|---|---|
| Download | Link in, choice made | URL field with paste/clear, Analyze, result card (thumbnail, title, uploader, duration), Video/Audio switch, quality chips with size estimates, container chips, Extras drawer, one primary Download button |
| Queue | What is happening now | Card per item: thumbnail, status pills (format, %, ETA), progress bar, Pause/Resume/Retry/Cancel; Pause all / Resume all; badge count on the tab |
| Library | What I have | Search, All/Video/Audio filter, total size, tap to open, menu: share, remove from list, delete file |
| Settings | Rarely touched | Engine version + update + nightly, parallel downloads, aria2 connections, save folder, defaults, theme, licenses |

## Flow

```
paste / share link
      │
  Analyze (yt-dlp -J --flat-playlist)
      │
  ┌───┴─────────────┐
single video     playlist ── choose videos
  └───┬─────────────┘
 Video/Audio + quality + extras
      │
 Download ─► Queue (switches tab) ─► Library + notification
```

## Visual language

- Ink-dark surfaces, one electric-lime accent (`#C6F135`), used for primary actions, progress and selection only.
- 20 px card radius, 14–16 px controls, 1 px low-contrast outlines instead of shadows.
- Tight, heavy headings; quiet secondary text. Status colors: green done, amber paused, red failed.
- Light theme uses a deepened olive primary so contrast stays accessible.
- Shared across the AlphaOmega family of tool apps: same tokens in `core/theme.dart`.

## States covered

Engine starting, engine error (retry chip), analyzing, analyze error with a readable message, empty tabs with guidance, playlist selection, queued, running, paused, failed (with reason and Retry), cancelled, done, file deleted outside the app (toast on open), notification permission denied (downloads still run).

## Code map

```
lib/
  main.dart, app.dart            shell, theme mode, nav, share-intent hookup
  core/    native.dart  theme.dart  format.dart
  data/    models.dart  db.dart  settings.dart
  state/   providers.dart  ui_state.dart
  ui/      download_screen  queue_screen  library_screen  settings_screen
           widgets/ common  choice_panel  playlist_sheet
android/app/src/main/kotlin/com/aos/
  MainActivity  Engine  DownloadService  Notifier  MediaSaver
```

## Portfolio talking points

Platform channels both ways (method + event stream), a foreground service with progress notifications, MediaStore scoped storage, process management with resume, Riverpod state with SQLite persistence, share-intent handling, and bundling native binaries (python, ffmpeg, aria2) in an APK with ABI splits.

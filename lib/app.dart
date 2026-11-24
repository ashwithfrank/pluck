import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme.dart';
import 'state/providers.dart';
import 'state/ui_state.dart';
import 'ui/download_screen.dart';
import 'ui/library_screen.dart';
import 'ui/queue_screen.dart';
import 'ui/settings_screen.dart';

class PluckApp extends ConsumerWidget {
  const PluckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Pluck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: const _Shell(),
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  @override
  void initState() {
    super.initState();
    // Ask once for notification permission (Android 13+); downloads work without it.
    WidgetsBinding.instance.addPostFrameCallback((_) => Permission.notification.request());
    // Make sure the downloads notifier is alive so it can catch share intents.
    ref.read(downloadsProvider);
    ref.read(downloadsProvider.notifier).shared.listen((url) {
      ref.read(incomingUrlProvider.notifier).state = url;
      ref.read(tabProvider.notifier).state = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(tabProvider);
    final active = ref.watch(activeItemsProvider).where((i) => i.isActive).length;

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [DownloadScreen(), QueueScreen(), LibraryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.south_rounded),
            selectedIcon: Icon(Icons.south_rounded),
            label: 'Download',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: active > 0, label: Text('$active'), child: const Icon(Icons.stacked_line_chart_rounded)),
            label: 'Queue',
          ),
          const NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Library'),
          const NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

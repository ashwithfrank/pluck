import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../state/providers.dart';
import 'widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final engine = ref.watch(engineProvider);
    final cs = Theme.of(context).colorScheme;
    final n = ref.read(settingsProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),

          const Section('Engine'),
          PCard(
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.bolt_rounded, color: cs.primary),
                title: const Text('yt-dlp'),
                subtitle: Text(engine.ready ? 'Version ${engine.version}' : (engine.error ?? 'Starting…')),
                trailing: _updating
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: engine.ready ? _update : null,
                        child: const Text('Update'),
                      ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.science_outlined),
                title: const Text('Nightly channel'),
                subtitle: const Text('Newer fixes sooner, slightly less tested'),
                value: s.nightly,
                onChanged: (v) => n.edit((x) => x.nightly = v),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Sites stopped working?'),
                subtitle: Text('Sites change often. Updating yt-dlp usually fixes errors.'),
              ),
            ]),
          ),

          const Section('Downloads'),
          PCard(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Simultaneous downloads'),
                subtitle: Slider(
                  value: s.maxParallel.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '${s.maxParallel}',
                  onChanged: (v) => n.edit((x) => x.maxParallel = v.round()),
                  onChangeEnd: (_) => ref.read(downloadsProvider.notifier).repump(),
                ),
                trailing: Text('${s.maxParallel}', style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.speed_rounded),
                title: const Text('Faster downloads (aria2)'),
                subtitle: Text(engine.aria
                    ? 'Multiple connections per file'
                    : 'Not available on this build'),
                value: s.useAria && engine.aria,
                onChanged: engine.aria ? (v) => n.edit((x) => x.useAria = v) : null,
              ),
              if (s.useAria && engine.aria) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.call_split_rounded),
                  title: const Text('Connections per file'),
                  subtitle: Slider(
                    value: s.connections.toDouble(),
                    min: 1,
                    max: 16,
                    divisions: 15,
                    label: '${s.connections}',
                    onChanged: (v) => n.edit((x) => x.connections = v.round()),
                  ),
                  trailing: Text('${s.connections}', style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Save folder'),
                subtitle: Text('Downloads / ${s.subdir}'),
                onTap: () => _editFolder(s.subdir),
              ),
            ]),
          ),

          const Section('Defaults for new links'),
          PCard(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Default type'),
                trailing: SegmentedButton<Kind>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: Kind.video, label: Text('Video')),
                    ButtonSegment(value: Kind.audio, label: Text('Audio')),
                  ],
                  selected: {s.choice.kind},
                  onSelectionChanged: (v) => n.edit((x) => x.choice.kind = v.first),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Video container'),
                trailing: DropdownButton<VideoContainer>(
                  value: s.choice.container,
                  underline: const SizedBox.shrink(),
                  items: [for (final c in VideoContainer.values) DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))],
                  onChanged: (v) => n.edit((x) => x.choice.container = v!),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.audiotrack_outlined),
                title: const Text('Audio format'),
                trailing: DropdownButton<AudioFormat>(
                  value: s.choice.audio,
                  underline: const SizedBox.shrink(),
                  items: [for (final a in AudioFormat.values) DropdownMenuItem(value: a, child: Text(a.name.toUpperCase()))],
                  onChanged: (v) => n.edit((x) => x.choice.audio = v!),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.label_outline_rounded),
                title: const Text('Embed metadata'),
                value: s.choice.embedMetadata,
                onChanged: (v) => n.edit((x) => x.choice.embedMetadata = v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.image_outlined),
                title: const Text('Embed thumbnail'),
                value: s.choice.embedThumbnail,
                onChanged: (v) => n.edit((x) => x.choice.embedThumbnail = v),
              ),
            ]),
          ),

          const Section('Appearance'),
          PCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'system', icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                    ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                    ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => n.edit((x) => x.themeMode = v.first),
                ),
              ),
            ),
          ),

          const Section('About'),
          PCard(
            child: Column(children: [
              const ListTile(
                leading: Icon(Icons.south_rounded),
                title: Text('Pluck 1.0.0'),
                subtitle: Text('By AlphaOmega Studio'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licenses'),
                subtitle: const Text('yt-dlp (Unlicense), FFmpeg (LGPL/GPL), aria2 (GPL), youtubedl-android (GPL-3.0)'),
                onTap: () => showLicensePage(context: context, applicationName: 'Pluck', applicationVersion: '1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('yt-dlp supported sites'),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.gavel_rounded),
                title: Text('Use responsibly'),
                subtitle: Text('Only download content you own or have permission to save. You are responsible for following each site\'s terms and your local laws.'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _update() async {
    setState(() => _updating = true);
    final msg = await ref.read(engineProvider.notifier).update();
    if (!mounted) return;
    setState(() => _updating = false);
    toast(context, msg);
  }

  Future<void> _editFolder(String current) async {
    final c = TextEditingController(text: current);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Folder name'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Pluck')),
          const SizedBox(height: 10),
          const Text('Created inside your Downloads folder.', style: TextStyle(fontSize: 12.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final clean = v?.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    if (clean != null && clean.isNotEmpty) ref.read(settingsProvider.notifier).edit((x) => x.subdir = clean);
  }
}

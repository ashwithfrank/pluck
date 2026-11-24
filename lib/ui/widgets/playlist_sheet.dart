import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import 'common.dart';

/// Pick which playlist entries to download. Returns the chosen entries.
Future<List<PlaylistEntry>?> pickPlaylistEntries(BuildContext context, MediaInfo info) {
  return showModalBottomSheet<List<PlaylistEntry>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlaylistSheet(info: info),
  );
}

class _PlaylistSheet extends StatefulWidget {
  const _PlaylistSheet({required this.info});
  final MediaInfo info;

  @override
  State<_PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<_PlaylistSheet> {
  late final Set<int> _picked = {for (var i = 0; i < widget.info.entries.length; i++) i};

  @override
  Widget build(BuildContext context) {
    final entries = widget.info.entries;
    final cs = Theme.of(context).colorScheme;
    final all = _picked.length == entries.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.info.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                Text('${_picked.length} of ${entries.length} selected',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
            TextButton(
              onPressed: () => setState(() {
                if (all) {
                  _picked.clear();
                } else {
                  _picked.addAll([for (var i = 0; i < entries.length; i++) i]);
                }
              }),
              child: Text(all ? 'None' : 'All'),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final on = _picked.contains(i);
              return CheckboxListTile(
                value: on,
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                onChanged: (v) => setState(() => v == true ? _picked.add(i) : _picked.remove(i)),
                title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${i + 1}${e.duration != null ? '  ·  ${fmtDuration(e.duration)}' : ''}'),
                secondary: SizedBox(width: 84, child: MediaThumb(url: e.thumbnail, aspect: 16 / 9, radius: 10)),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.pop(context, [for (final i in _picked.toList()..sort()) entries[i]]),
                child: Text('Use ${_picked.length} selected'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

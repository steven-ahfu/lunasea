import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrEventTile extends StatefulWidget {
  final ChaptarrEvent event;
  final ChaptarrAPI api;
  final bool history;
  final bool showBook;
  final VoidCallback refresh;
  const ChaptarrEventTile({
    super.key,
    required this.event,
    required this.api,
    required this.history,
    required this.refresh,
    this.showBook = true,
  });
  @override
  State<ChaptarrEventTile> createState() => _EventState();
}

class _EventState extends State<ChaptarrEventTile> {
  bool busy = false;
  Future<void> open() async {
    if (busy) return;
    setState(() => busy = true);
    final e = widget.event;
    final row = e.details;
    try {
      final action = await chaptarrChoice(context, e.title, {
        'details': 'chaptarr.EventDetails'.tr(),
        if (widget.showBook && (e.bookId ?? 0) > 0)
          'book': 'chaptarr.BookDetails'.tr(),
        if (widget.history &&
            e.id != null &&
            e.status.toLowerCase() == 'grabbed')
          'failed': 'chaptarr.MarkFailed'.tr(),
        if (!widget.history && e.id != null) ...{
          if ([
            'delay',
            'downloadclientunavailable',
          ].contains(e.status.toLowerCase()))
            'grab': 'chaptarr.GrabNow'.tr(),
          if (row['downloadId'] is String) 'import': 'radarr.ManualImport'.tr(),
          'remove': 'chaptarr.RemoveQueue'.tr(),
        },
      });
      if (!mounted || action == null) return;
      switch (action) {
        case 'book':
          await context.push('/chaptarr/book/${e.bookId}');
        case 'details':
          final fields = <String, dynamic>{
            'Status': e.status,
            'Date': row['date'],
            'Download client': row['downloadClient'],
            'Indexer': row['indexer'],
            'Quality': row['quality']?['quality']?['name'],
            'Time left': row['timeleft'],
            'Output path': row['outputPath'],
            if (row['data'] is Map) ...Map<String, dynamic>.from(row['data']),
          };
          final messages = [
            for (final item
                in (row['statusMessages'] as List? ?? []).whereType<Map>())
              ...?item['messages'] as List?,
          ];
          await LunaDialogs().textPreview(
            context,
            e.title,
            [
              for (final entry in fields.entries)
                if (entry.value != null && entry.value.toString().isNotEmpty)
                  '${entry.key}: ${entry.value}',
              ...messages.whereType<String>(),
            ].join('\n'),
            alignLeft: true,
          );
        case 'import':
          await context.push(
            Uri(
              path: '/chaptarr/import',
              queryParameters: {
                'downloadId': row['downloadId'].toString(),
                'format':
                    row['book']?['mediaType'] ?? row['mediaType'] ?? 'ebook',
              },
            ).toString(),
          );
          if (mounted) widget.refresh();
        case 'failed':
          if (await chaptarrConfirm(
                context,
                'chaptarr.MarkFailed'.tr(),
                e.title,
              ) ==
              null)
            return;
          await widget.api.markFailed(e.id!);
          if (mounted) widget.refresh();
        case 'grab':
          if (await chaptarrConfirm(
                context,
                'chaptarr.GrabNow'.tr(),
                e.title,
              ) ==
              null)
            return;
          await widget.api.grabQueued(e.id!);
          if (mounted) widget.refresh();
        case 'remove':
          final selected = await chaptarrConfirm(
            context,
            'chaptarr.RemoveQueue'.tr(),
            e.title,
            options: {
              'client': 'chaptarr.RemoveFromClient'.tr(),
              'block': 'chaptarr.Blocklist'.tr(),
              'skip': 'chaptarr.SkipRedownload'.tr(),
            },
          );
          if (selected == null) return;
          await widget.api.removeQueued(
            e.id!,
            removeFromClient: selected.contains('client'),
            blocklist: selected.contains('block'),
            skipRedownload: selected.contains('skip'),
          );
          if (mounted) widget.refresh();
      }
    } catch (error) {
      if (mounted)
        showLunaErrorSnackBar(
          title: 'chaptarr.ActionFailed'.tr(),
          error: error,
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LunaBlock(
    title: widget.event.title,
    body: [
      TextSpan(text: widget.event.status),
      TextSpan(text: widget.event.subtitle),
    ],
    bodyLeadingIcons: [
      widget.history ? Icons.history_rounded : Icons.downloading_rounded,
      Icons.info_outline_rounded,
    ],
    trailing: const LunaIconButton.arrow(),
    onTap: open,
  );
}

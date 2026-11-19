import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrEditBook extends StatefulWidget {
  final ChaptarrAPI api;
  final int bookId;
  final bool author;
  const ChaptarrEditBook({
    super.key,
    required this.api,
    required this.bookId,
    this.author = false,
  });
  @override
  State<ChaptarrEditBook> createState() => _EditState();
}

class _EditState extends State<ChaptarrEditBook>
    with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  late Future<void> request = load();
  ChaptarrResource book = {}, author = {};
  List<ChaptarrResource> editions = [],
      qualities = [],
      metadata = [],
      roots = [],
      tags = [];
  final changes = <String, dynamic>{};
  int? editionId;
  bool busy = false;

  ChaptarrFormat? get format => ChaptarrFormat.parse(book['mediaType']);
  int? get authorId => book['authorId'] ?? book['author']?['id'];
  dynamic value(String field) => changes.containsKey(field)
      ? changes[field]
      : (widget.author ? author : book)[field];

  Future<void> load() async {
    book = await widget.api.bookSettings(widget.bookId);
    if (widget.author) {
      author = await widget.api.authorSettings(authorId!);
      final rows = await Future.wait([
        widget.api.qualityProfiles(),
        widget.api.metadataProfiles(),
        widget.api.rootFolders(),
        widget.api.tags(),
      ]);
      qualities = rows[0];
      metadata = rows[1];
      roots = rows[2];
      tags = rows[3];
    } else {
      editions = await widget.api.editions(widget.bookId);
    }
  }

  void change(String key, dynamic next) => setState(() {
    if (next == (widget.author ? author : book)[key]) {
      changes.remove(key);
    } else {
      changes[key] = next;
    }
  });

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (widget.author && changes.isNotEmpty) {
        var move = false;
        if (changes.containsKey('${format!.name}Folder')) {
          final answer = await chaptarrChoice(
            context,
            'chaptarr.MoveAuthorFiles'.tr(),
            {
              false: 'chaptarr.ChangePathOnly'.tr(),
              true: 'chaptarr.MoveFiles'.tr(),
            },
          );
          if (answer == null || !mounted) return;
          move = answer;
        }
        await widget.api.updateAuthor(
          authorId!,
          changes,
          format: format!,
          moveFiles: move,
        );
      } else if (!widget.author && (changes.isNotEmpty || editionId != null)) {
        await widget.api.updateBook(
          widget.bookId,
          monitored: changes['monitored'],
          anyEditionOk: changes['anyEditionOk'],
          editionId: editionId,
        );
      }
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: request,
    builder: (_, snapshot) {
      final ready =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError;
      return LunaScaffold(
        scaffoldKey: scaffold,
        appBar: LunaAppBar(
          title:
              (widget.author ? 'chaptarr.AuthorSettings' : 'chaptarr.EditBook')
                  .tr(),
          scrollControllers: [scrollController],
        ),
        body: snapshot.hasError
            ? LunaMessage.error(onTap: () => setState(() => request = load()))
            : !ready
            ? const LunaLoader()
            : AbsorbPointer(
                absorbing: busy,
                child: LunaListView(
                  controller: scrollController,
                  children: widget.author ? authorFields() : bookFields(),
                ),
              ),
        bottomNavigationBar: ready
            ? LunaBottomActionBar(
                actions: [
                  LunaButton(
                    type: LunaButtonType.TEXT,
                    text: 'lunasea.Update'.tr(),
                    icon: Icons.edit_rounded,
                    loadingState: busy
                        ? LunaLoadingState.ACTIVE
                        : LunaLoadingState.INACTIVE,
                    onTap: save,
                  ),
                ],
              )
            : null,
      );
    },
  );

  Widget toggle(String label, String key) => LunaBlock(
    title: label,
    trailing: LunaSwitch(
      value: value(key) == true,
      onChanged: (v) => change(key, v),
    ),
  );

  List<Widget> bookFields() {
    final int? current =
        editionId ??
        editions.where((e) => e['monitored'] == true).firstOrNull?['id'];
    final choices = {
      for (final e in editions)
        if (e['id'] is int) e['id'] as int: editionLabel(e),
    };
    final locked =
        value('anyEditionOk') == true &&
        (book['statistics']?['bookFileCount'] ?? 0) > 0;
    return [
      toggle('radarr.Monitored'.tr(), 'monitored'),
      toggle('chaptarr.AutomaticEdition'.tr(), 'anyEditionOk'),
      chaptarrSetting(
        'chaptarr.Edition'.tr(),
        choices[current] ?? '',
        choices.isEmpty || locked
            ? null
            : () async {
                final next = await chaptarrChoice(
                  context,
                  'chaptarr.Edition'.tr(),
                  choices,
                  current: current,
                );
                if (next != null && mounted) {
                  setState(() => editionId = next);
                  change('anyEditionOk', false);
                }
              },
      ),
      if (format != null && authorId != null)
        chaptarrSetting(
          'chaptarr.AuthorSettings'.tr(),
          'chaptarr.AuthorSettingsHint'.tr(
            args: [
              book['author']?['authorName'] ?? book['authorTitle'] ?? '',
              format!.label,
            ],
          ),
          () => context.push('/chaptarr/book/${widget.bookId}/edit/author'),
        ),
    ];
  }

  List<Widget> authorFields() {
    final media = format!;
    final prefix = media.name;
    Widget select<T>(String label, String field, Map<T, String> choices) =>
        chaptarrSetting(
          label,
          choices[value(field)] ?? value(field)?.toString() ?? '',
          choices.isEmpty
              ? null
              : () async {
                  final next = await chaptarrChoice(
                    context,
                    label,
                    choices,
                    current: value(field) as T?,
                  );
                  if (mounted && next != null) change(field, next);
                },
        );
    final tagKey = '${prefix}Tags';
    final assigned = ((value(tagKey) ?? author['tags'] ?? []) as List)
        .cast<int>();
    final labels = {
      for (final tag in tags) tag['id'] as int: tag['label'] as String,
    };
    return [
      LunaBlock(
        title: author['authorName'] ?? '',
        body: [
          TextSpan(
            text: 'chaptarr.SharedAuthorSettings'.tr(args: [media.label]),
          ),
        ],
      ),
      select(
        'radarr.QualityProfile'.tr(),
        '${prefix}QualityProfileId',
        chaptarrProfileNames(qualities, media),
      ),
      toggle(
        'chaptarr.MonitorAuthor'.tr(args: [media.label]),
        '${prefix}Monitored',
      ),
      select(
        (author['syncMonitoredAcrossFormats'] == true
                ? 'chaptarr.SyncPolicy'
                : 'chaptarr.MonitorNewBooks')
            .tr(),
        '${prefix}MonitorNewItems',
        {
          'all': 'chaptarr.AllNewBooks'.tr(),
          'new': 'chaptarr.FutureReleases'.tr(),
          'none': 'chaptarr.NoNewBooks'.tr(),
        },
      ),
      select(
        'chaptarr.MetadataProfile'.tr(),
        '${prefix}MetadataProfileId',
        chaptarrProfileNames(metadata, media),
      ),
      select('chaptarr.RootFolder'.tr(), '${prefix}RootFolderPath', {
        for (final r in roots)
          if (r['folderType'] == 0 || r['folderType'] == media.folderType)
            r['path'] as String: r['path'] as String,
      }),
      chaptarrSetting(
        'chaptarr.AuthorPath'.tr(),
        value('${prefix}Folder') ?? '',
        () async {
          final path = await LunaDialogs().editText(
            context,
            'chaptarr.AuthorPath'.tr(),
            prefill: value('${prefix}Folder') ?? '',
          );
          if (mounted && path.item1)
            change('${prefix}Folder', path.item2.trim());
        },
      ),
      chaptarrSetting(
        'radarr.Tags'.tr(),
        assigned.map((id) => labels[id] ?? '#$id').join(', '),
        () async {
          final result = await chaptarrConfirm(
            context,
            'radarr.Tags'.tr(),
            labels.isEmpty ? 'radarr.NoTagsFound'.tr() : '',
            options: {for (final e in labels.entries) '${e.key}': e.value},
            initial: assigned.map((i) => '$i').toSet(),
            action: 'lunasea.Update'.tr(),
          );
          if (mounted && result != null)
            change(tagKey, result.map(int.parse).toList());
        },
      ),
    ];
  }
}

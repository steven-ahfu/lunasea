import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrManualImport extends StatefulWidget {
  final ChaptarrAPI api;
  final ChaptarrFormat format;
  final String? downloadId;
  const ChaptarrManualImport({
    super.key,
    required this.api,
    required this.format,
    this.downloadId,
  });
  @override
  State<ChaptarrManualImport> createState() => _ImportState();
}

class _ImportState extends State<ChaptarrManualImport>
    with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  String folder = '';
  late bool preview = widget.downloadId != null;
  List<ChaptarrResource> rows = [];
  final selected = <String>{};
  String? parent;
  late Future<void> request = load();
  bool busy = false;

  Future<void> load() async {
    if (preview) {
      rows = await widget.api.importPreview(
        folder: widget.downloadId == null ? folder : null,
        downloadId: widget.downloadId,
        format: widget.format,
      );
      selected.clear();
    } else {
      final listing = await widget.api.browse(folder);
      parent = listing['parent'];
      rows = (listing['directories'] as List).cast<ChaptarrResource>();
    }
  }

  void navigate(String path, {bool scan = false}) => setState(() {
    folder = path;
    preview = scan;
    request = load();
  });

  static ChaptarrResource? file(ChaptarrResource row) {
    final local =
        (row['author']?['id'] ?? 0) > 0 &&
        (row['book']?['id'] ?? 0) > 0 &&
        (row['editionId'] ?? 0) > 0;
    final suggested =
        !local &&
        row['suggestedForeignAuthorId'] != null &&
        row['suggestedForeignBookId'] != null;
    if ((!local && !suggested) || row['quality'] == null) return null;
    return {
      'path': row['path'],
      'authorId': local ? row['author']['id'] : 0,
      'bookId': local ? row['book']['id'] : 0,
      'editionId': local ? row['editionId'] : 0,
      if (suggested) ...{
        'foreignAuthorId': row['suggestedForeignAuthorId'],
        'foreignAuthorName': row['suggestedAuthorName'],
        'foreignBookId': row['suggestedForeignBookId'],
        'foreignBookTitle': row['suggestedBookTitle'],
        'foreignEditionId': row['suggestedForeignEditionId'],
        'foreignEditionTitle': row['suggestedEditionTitle'],
      },
      'selectionSource': suggested ? 'userMetadataSuggestion' : 'automatic',
      for (final key in [
        'quality',
        'releaseGroup',
        'indexerFlags',
        'downloadId',
        'disableReleaseSwitching',
      ])
        if (row.containsKey(key)) key: row[key],
    };
  }

  Future<void> match(ChaptarrResource row) async {
    final query = await LunaDialogs().editText(
      context,
      'chaptarr.SearchLibrary'.tr(),
    );
    if (!mounted || !query.item1 || query.item2.trim().isEmpty) return;
    await perform(() async {
      final matches = await widget.api.searchLibrary(
        query.item2.trim(),
        widget.format,
      );
      if (!mounted) return;
      if (matches.isEmpty) {
        await LunaDialogs().textPreview(
          context,
          'chaptarr.SearchLibrary'.tr(),
          'chaptarr.NoResults'.tr(),
        );
        return;
      }
      final book = await chaptarrChoice(context, 'chaptarr.Title'.tr(), {
        for (final b in matches)
          if (b.id != null) b: '${b.title} · ${b.author}',
      });
      if (book == null || !mounted) return;
      final editions = await widget.api.editions(book.id!);
      if (!mounted) return;
      final edition = await chaptarrChoice(context, 'chaptarr.Edition'.tr(), {
        for (final e in editions) e['id'] as int: editionLabel(e),
      });
      if (edition == null) return;
      final author =
          book.authorId ??
          (await widget.api.bookSettings(book.id!))['authorId'] as int;
      final updated = await widget.api.matchImport(
        row,
        authorId: author,
        bookId: book.id!,
        editionId: edition,
      );
      updateRow(updated);
    });
  }

  void updateRow(ChaptarrResource updated) {
    if (mounted)
      setState(() {
        rows = [
          for (final row in rows)
            row['path'] == updated['path'] ? updated : row,
        ];
        selected.remove(updated['path']);
      });
  }

  Future<void> editRow(ChaptarrResource row) async {
    final choice = await chaptarrChoice(context, row['path'], {
      'book': 'chaptarr.MatchBook'.tr(),
      'quality': 'radarr.Quality'.tr(),
    });
    if (!mounted || choice == null) return;
    if (choice == 'book') {
      await match(row);
      return;
    }
    await perform(() async {
      final profiles = await widget.api.qualityProfiles();
      final ids = chaptarrProfileNames(profiles, widget.format).keys;
      final options = <int, ChaptarrResource>{};
      void collect(List<dynamic> items) {
        for (final item in items.whereType<Map>()) {
          final quality = item['quality'];
          if (quality is ChaptarrResource && quality['id'] is int)
            options[quality['id']] = quality;
          collect(item['items'] as List? ?? []);
        }
      }

      for (final profile in profiles.where((p) => ids.contains(p['id']))) {
        collect(profile['items'] as List? ?? []);
      }
      if (!mounted) return;
      final id = await chaptarrChoice<int>(context, 'radarr.Quality'.tr(), {
        for (final e in options.entries) e.key: e.value['name'] as String,
      }, current: row['quality']?['quality']?['id']);
      if (id == null) return;
      final updated = await widget.api.matchImport(
        row,
        quality: {
          ...?row['quality'] as ChaptarrResource?,
          'quality': options[id],
        },
      );
      updateRow(updated);
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() => perform(() async {
    final mode = await chaptarrChoice(context, 'radarr.ImportMode'.tr(), {
      'auto': 'chaptarr.ImportAuto'.tr(),
      'copy': 'chaptarr.ImportCopy'.tr(),
      'move': 'chaptarr.MoveFiles'.tr(),
    });
    if (mode == null || !mounted) return;
    final chosen = rows.where((r) => selected.contains(r['path'])).toList();
    if (preview && chosen.isEmpty) return;
    if (await chaptarrConfirm(
          context,
          'radarr.Import'.tr(),
          preview ? chosen.map((r) => r['path']).join('\n') : folder,
        ) ==
        null)
      return;
    if (preview) {
      await widget.api.importFiles(
        [
          for (final row in chosen)
            {
              ...file(row)!,
              'downloadId': row['downloadId'] ?? widget.downloadId,
            },
        ],
        [
          for (final row in rows)
            {
              'path': row['path'],
              'bookId': row['book']?['id'] ?? 0,
              'downloadId': row['downloadId'] ?? widget.downloadId,
            },
        ],
        mode,
      );
    } else {
      await widget.api.quickImport(folder, mode);
    }
    if (mounted) {
      showLunaSuccessSnackBar(
        title: 'chaptarr.CommandQueued'.tr(),
        message: 'radarr.Import'.tr(),
      );
      context.pop();
    }
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: request,
    builder: (_, snap) {
      final ready =
          snap.connectionState == ConnectionState.done && !snap.hasError;
      return LunaScaffold(
        scaffoldKey: scaffold,
        appBar: LunaAppBar(
          title: 'radarr.ManualImport'.tr(),
          scrollControllers: [scrollController],
        ),
        body: !ready
            ? (snap.hasError
                  ? LunaMessage.error(
                      onTap: () => setState(() => request = load()),
                    )
                  : const LunaLoader())
            : AbsorbPointer(
                absorbing: busy,
                child: LunaListView(
                  controller: scrollController,
                  children: [
                    if (widget.downloadId == null)
                      chaptarrSetting(
                        'radarr.FileBrowser'.tr(),
                        folder,
                        () async {
                          final text = await LunaDialogs().editText(
                            context,
                            'radarr.FileBrowser'.tr(),
                            prefill: folder,
                          );
                          if (mounted && text.item1)
                            navigate(text.item2.trim());
                        },
                      ),
                    if (!preview && folder.isNotEmpty)
                      LunaBlock(
                        title: 'radarr.ParentDirectory'.tr(),
                        onTap: () => navigate(parent ?? ''),
                      ),
                    if (preview && widget.downloadId == null)
                      LunaBlock(
                        title: 'radarr.FileBrowser'.tr(),
                        onTap: () => navigate(folder),
                      ),
                    if (rows.isEmpty)
                      LunaMessage.inList(
                        text:
                            (preview
                                    ? 'radarr.NoFilesFound'
                                    : 'radarr.NoSubdirectoriesFound')
                                .tr(),
                      ),
                    for (final row in rows)
                      if (!preview)
                        chaptarrSetting(
                          row['name'] ?? row['path'],
                          row['path'],
                          () => navigate(row['path']),
                        )
                      else
                        LunaBlock(
                          title: row['path'],
                          body: [
                            TextSpan(
                              text:
                                  row['book']?['title'] ??
                                  row['suggestedBookTitle'] ??
                                  'chaptarr.MatchBook'.tr(),
                            ),
                            for (final rejection
                                in (row['rejections'] as List? ?? [])
                                    .whereType<Map>())
                              TextSpan(text: rejection['reason']),
                          ],
                          onTap: () => editRow(row),
                          trailing: Checkbox(
                            value: selected.contains(row['path']),
                            onChanged: file(row) == null
                                ? null
                                : (v) => setState(() {
                                    if (v == true) {
                                      selected.add(row['path']);
                                    } else {
                                      selected.remove(row['path']);
                                    }
                                  }),
                          ),
                        ),
                  ],
                ),
              ),
        bottomNavigationBar:
            !ready || busy || (preview ? selected.isEmpty : folder.isEmpty)
            ? null
            : LunaBottomActionBar(
                actions: [
                  if (!preview)
                    LunaButton.text(
                      text: 'radarr.Interactive'.tr(),
                      icon: Icons.person_rounded,
                      onTap: () => navigate(folder, scan: true),
                    ),
                  LunaButton.text(
                    text: (preview ? 'radarr.Import' : 'radarr.Quick').tr(),
                    icon: Icons.download_done_rounded,
                    onTap: submit,
                  ),
                ],
              ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/chaptarr/routes/book_actions.dart';
import 'package:lunasea/modules/chaptarr/routes/paged.dart';
import 'package:lunasea/modules/chaptarr/routes/event_tile.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrDetails extends StatefulWidget {
  final ChaptarrAPI api;
  final int id;
  const ChaptarrDetails({super.key, required this.api, required this.id});
  @override
  State<ChaptarrDetails> createState() => _DetailsState();
}

class _DetailsState extends State<ChaptarrDetails>
    with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  final pages = LunaPageController();
  final filesScroll = ScrollController();
  final historyScroll = ScrollController();
  late Future<ChaptarrBook> request = widget.api.book(widget.id);
  bool busy = false;
  int revision = 0;

  @override
  void dispose() {
    pages.dispose();
    filesScroll.dispose();
    historyScroll.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      revision++;
      request = widget.api.book(widget.id);
    });
  }

  Future<void> settings(ChaptarrBook book) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await showBookActions(context, widget.api, book);
      if (!mounted || result == null) return;
      if (result == ChaptarrBookChange.removed) {
        context.go('/chaptarr');
      } else {
        reload();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(
    Future<void> Function() action, {
    bool search = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      if (search) {
        showLunaSuccessSnackBar(
          title: 'chaptarr.SearchQueued'.tr(),
          message: '',
        );
      } else {
        reload();
      }
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: scaffold,
    appBar: LunaAppBar(
      title: 'chaptarr.BookDetails'.tr(),
      actions: [
        FutureBuilder<ChaptarrBook>(
          future: request,
          builder: (_, snapshot) {
            final book = snapshot.data;
            if (book == null) return const SizedBox();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (book.links.isNotEmpty)
                  Tooltip(
                    message: 'chaptarr.Links'.tr(),
                    child: LunaIconButton.appBar(
                      icon: LunaIcons.LINK,
                      onPressed: () async {
                        final link = await chaptarrChoice(
                          context,
                          'chaptarr.Links'.tr(),
                          {for (final e in book.links.entries) e.value: e.key},
                        );
                        if (link != null) await link.openLink();
                      },
                    ),
                  ),
                Tooltip(
                  message: 'chaptarr.EditBook'.tr(),
                  child: LunaIconButton.appBar(
                    icon: LunaIcons.EDIT,
                    onPressed: busy
                        ? null
                        : () async {
                            await context.push(
                              '/chaptarr/book/${widget.id}/edit',
                            );
                            if (mounted) reload();
                          },
                  ),
                ),
                Tooltip(
                  message:
                      (book.monitored
                              ? 'chaptarr.Monitored'
                              : 'chaptarr.Unmonitored')
                          .tr(),
                  child: LunaIconButton.appBar(
                    icon: book.monitored
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    onPressed: busy
                        ? null
                        : () => act(
                            () => widget.api.setMonitored(
                              widget.id,
                              !book.monitored,
                            ),
                          ),
                  ),
                ),
                Tooltip(
                  message: 'lunasea.Settings'.tr(),
                  child: LunaIconButton.appBar(
                    icon: Icons.more_vert_rounded,
                    onPressed: busy ? null : () => settings(book),
                  ),
                ),
              ],
            );
          },
        ),
      ],
      pageController: pages,
      scrollControllers: [scrollController, filesScroll, historyScroll],
    ),
    bottomNavigationBar: LunaBottomNavigationBar(
      topActions: [
        LunaButton(
          type: LunaButtonType.TEXT,
          text: 'radarr.Automatic'.tr(),
          icon: Icons.search_rounded,
          loadingState: busy
              ? LunaLoadingState.ACTIVE
              : LunaLoadingState.INACTIVE,
          onTap: () =>
              act(() => widget.api.searchReleases(widget.id), search: true),
        ),
        LunaButton.text(
          text: 'radarr.Interactive'.tr(),
          icon: Icons.person_rounded,
          onTap: () => context.push('/chaptarr/book/${widget.id}/releases'),
        ),
      ],
      pageController: pages,
      scrollControllers: [scrollController, filesScroll, historyScroll],
      icons: const [
        Icons.subject_rounded,
        Icons.insert_drive_file_outlined,
        Icons.history_rounded,
      ],
      titles: [
        'chaptarr.Overview'.tr(),
        'sonarr.Files'.tr(),
        'chaptarr.History'.tr(),
      ],
    ),
    body: LunaPageView(
      controller: pages,
      children: [
        overview(),
        _BookFiles(
          key: ValueKey(revision),
          api: widget.api,
          id: widget.id,
          scroll: filesScroll,
          onChanged: reload,
        ),
        ChaptarrPaged<ChaptarrEvent>(
          key: ValueKey(('history', revision)),
          scroll: historyScroll,
          empty: 'chaptarr.EmptyHistory'.tr(),
          load: (page) =>
              widget.api.activity(history: true, page: page, bookId: widget.id),
          tile: (event) => ChaptarrEventTile(
            api: widget.api,
            event: event,
            history: true,
            showBook: false,
            refresh: reload,
          ),
        ),
      ],
    ),
  );

  Widget overview() => FutureBuilder<ChaptarrBook>(
    future: request,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const LunaLoader();
      if (snapshot.hasError) return LunaMessage.error(onTap: reload);
      final b = snapshot.requireData;
      return LunaListView(
        controller: scrollController,
        children: [
          ChaptarrDescriptionTile(api: widget.api, book: b),
          LunaTableCard(
            content: [
              LunaTableContent(title: 'author', body: b.author),
              LunaTableContent(title: 'format', body: b.format?.label),
              if (b.narrator.isNotEmpty)
                LunaTableContent(title: 'narrator', body: b.narrator),
              LunaTableContent(
                title: 'monitoring',
                body:
                    (b.monitored
                            ? 'chaptarr.Monitored'
                            : 'chaptarr.Unmonitored')
                        .tr(),
              ),
              LunaTableContent(
                title: 'status',
                body: (b.hasFiles ? 'chaptarr.Downloaded' : 'radarr.Missing')
                    .tr(),
              ),
              if (b.sizeOnDisk > 0)
                LunaTableContent(title: 'size', body: b.sizeOnDisk.asBytes()),
              LunaTableContent.spacer(),
              if (b.releaseDate != null)
                LunaTableContent(
                  title: 'published',
                  body: DateFormat.yMMMMd().format(b.releaseDate!),
                ),
              if (b.added != null)
                LunaTableContent(
                  title: 'added on',
                  body: b.added!.asDateOnly(),
                ),
              if (b.pageCount > 0 && b.format == ChaptarrFormat.ebook)
                LunaTableContent(title: 'pages', body: '${b.pageCount}'),
              if (b.genres.isNotEmpty)
                LunaTableContent(title: 'genres', body: b.genres.join(', ')),
            ],
          ),
        ],
      );
    },
  );
}

class _BookFiles extends StatefulWidget {
  final ChaptarrAPI api;
  final int id;
  final ScrollController scroll;
  final VoidCallback onChanged;
  const _BookFiles({
    super.key,
    required this.api,
    required this.id,
    required this.scroll,
    required this.onChanged,
  });
  @override
  State<_BookFiles> createState() => _FilesState();
}

class _FilesState extends State<_BookFiles> {
  final deleting = <int>{};
  Future<void> deleteFile(ChaptarrBookFile file) async {
    final id = file.id!;
    if (deleting.contains(id)) return;
    setState(() => deleting.add(id));
    try {
      if (await chaptarrConfirm(
            context,
            'chaptarr.DeleteFile'.tr(),
            file.path,
          ) ==
          null)
        return;
      await widget.api.removeFile(id);
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => deleting.remove(id));
    }
  }

  late Future<List<ChaptarrBookFile>> files = widget.api.files(widget.id);
  Future<void> refresh() async {
    setState(() {
      files = widget.api.files(widget.id);
    });
    try {
      await files;
    } catch (_) {
      /* FutureBuilder provides retry. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ChaptarrBookFile>>(
    future: files,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const LunaLoader();
      if (snapshot.hasError) return LunaMessage.error(onTap: refresh);
      final rows = snapshot.requireData;
      if (rows.isEmpty)
        return LunaMessage(
          text: 'radarr.NoFilesFound'.tr(),
          buttonText: 'lunasea.Refresh'.tr(),
          onTap: refresh,
        );
      return LunaRefreshIndicator(
        context: context,
        onRefresh: refresh,
        child: LunaListViewBuilder(
          controller: widget.scroll,
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final file = rows[i];
            return LunaTableCard(
              content: [
                LunaTableContent(
                  title: 'file',
                  body: file.path.split(RegExp(r'[/\\]')).last,
                ),
                LunaTableContent(title: 'path', body: file.path),
                LunaTableContent(title: 'quality', body: file.quality),
                LunaTableContent(title: 'size', body: file.size.asBytes()),
                if (file.dateAdded != null)
                  LunaTableContent(
                    title: 'added on',
                    body: file.dateAdded!.asDateOnly(),
                  ),
              ],
              buttons: [
                if (file.mediaInfo.isNotEmpty)
                  LunaButton.text(
                    text: 'chaptarr.MediaInfo'.tr(),
                    icon: Icons.info_outline_rounded,
                    onTap: () => LunaDialogs().textPreview(
                      context,
                      'chaptarr.MediaInfo'.tr(),
                      file.mediaInfo.entries
                          .where(
                            (e) =>
                                e.value != null &&
                                e.value.toString().isNotEmpty,
                          )
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                      alignLeft: true,
                    ),
                  ),
                if (file.id != null)
                  LunaButton(
                    type: LunaButtonType.TEXT,
                    text: 'chaptarr.DeleteFile'.tr(),
                    icon: Icons.delete_rounded,
                    color: LunaColours.red,
                    loadingState: deleting.contains(file.id)
                        ? LunaLoadingState.ACTIVE
                        : LunaLoadingState.INACTIVE,
                    onTap: () => deleteFile(file),
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}

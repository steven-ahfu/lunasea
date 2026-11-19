import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/chaptarr/routes/paged.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/extensions/datetime.dart';

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

  @override
  void dispose() {
    pages.dispose();
    filesScroll.dispose();
    historyScroll.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      request = widget.api.book(widget.id);
    });
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
            return Tooltip(
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
                        () =>
                            widget.api.setMonitored(widget.id, !book.monitored),
                      ),
              ),
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
        _BookFiles(api: widget.api, id: widget.id, scroll: filesScroll),
        ChaptarrPaged<ChaptarrEvent>(
          scroll: historyScroll,
          empty: 'chaptarr.EmptyHistory'.tr(),
          load: (page) =>
              widget.api.activity(history: true, page: page, bookId: widget.id),
          tile: (event) => LunaBlock(
            title: event.title,
            body: [
              TextSpan(text: event.status),
              TextSpan(text: event.subtitle),
            ],
            bodyLeadingIcons: const [
              Icons.history_rounded,
              Icons.access_time_rounded,
            ],
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
  const _BookFiles({required this.api, required this.id, required this.scroll});
  @override
  State<_BookFiles> createState() => _FilesState();
}

class _FilesState extends State<_BookFiles> {
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
            return LunaBlock(
              title: file.path.split(RegExp(r'[/\\]')).last,
              body: [
                TextSpan(
                  text: [
                    if (file.quality.isNotEmpty) file.quality,
                    file.size.asBytes(),
                  ].join(' · '),
                ),
                TextSpan(text: file.path),
              ],
              bodyLeadingIcons: const [
                Icons.description_rounded,
                Icons.folder_rounded,
              ],
            );
          },
        ),
      );
    },
  );
}

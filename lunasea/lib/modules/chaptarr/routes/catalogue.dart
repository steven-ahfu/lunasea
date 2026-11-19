import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/chaptarr/routes/paged.dart';
import 'package:lunasea/widgets/ui/catalogue_toolbar.dart';
import 'package:lunasea/extensions/scroll_controller.dart';

enum _CatalogueFilter {
  all('radarr.All'),
  monitored('chaptarr.Monitored'),
  unmonitored('chaptarr.Unmonitored'),
  missing('radarr.Missing'),
  downloaded('chaptarr.Downloaded');

  final String label;
  const _CatalogueFilter(this.label);
}

class ChaptarrCatalogue extends StatefulWidget {
  final ChaptarrAPI api;
  final ChaptarrFormat format;
  final bool upcoming;
  final ScrollController scroll;
  final ValueChanged<int> onBook;
  final ValueChanged<ChaptarrBook> onBookActions;
  final int revision;

  const ChaptarrCatalogue({
    super.key,
    required this.api,
    required this.format,
    required this.upcoming,
    required this.scroll,
    required this.onBook,
    required this.onBookActions,
    required this.revision,
  });

  @override
  State<ChaptarrCatalogue> createState() => _CatalogueState();
}

class _CatalogueState extends State<ChaptarrCatalogue>
    with AutomaticKeepAliveClientMixin {
  final query = TextEditingController();
  final scaffold = GlobalKey<ScaffoldState>();
  late bool ascending =
      widget.upcoming || ChaptarrDatabase.SORT_ASCENDING.read();
  late bool grid = ChaptarrDatabase.GRID_VIEW.read();
  late bool byAuthor =
      !widget.upcoming && ChaptarrDatabase.SORT_BY_AUTHOR.read();
  late _CatalogueFilter filter = widget.upcoming
      ? _CatalogueFilter.all
      : _CatalogueFilter.values
                .where(
                  (f) => f.name == ChaptarrDatabase.CATALOGUE_FILTER.read(),
                )
                .firstOrNull ??
            _CatalogueFilter.all;
  String term = '';
  Timer? debounce;
  Future<List<ChaptarrBook>>? request;

  @override
  void initState() {
    super.initState();
    if (widget.upcoming) request = load();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(ChaptarrCatalogue old) {
    super.didUpdateWidget(old);
    if ((widget.upcoming || term.length >= 2) &&
        (old.format != widget.format || old.revision != widget.revision))
      request = load();
  }

  Future<List<ChaptarrBook>> load() => widget.upcoming
      ? widget.api.upcoming(DateTime.now())
      : widget.api.searchLibrary(term, widget.format);

  void search(String value) {
    debounce?.cancel();
    void update() => setState(() {
      term = value.trim();
      request = term.length >= 2 ? load() : null;
    });
    if (value.trim().isEmpty) {
      update();
    } else {
      debounce = Timer(const Duration(milliseconds: 350), update);
    }
  }

  Future<void> refresh() async {
    setState(() {
      request = load();
    });
    try {
      await request;
    } catch (_) {
      /* FutureBuilder provides retry. */
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(
      scaffoldKey: scaffold,
      appBar: widget.upcoming
          ? null
          : LunaAppBar.empty(
              height: LunaTextInputBar.defaultAppBarHeight,
              child: LunaCatalogueToolbar(
                controller: query,
                scroll: widget.scroll,
                onChanged: search,
                actions: [
                  LunaCatalogueMenu<_CatalogueFilter>(
                    tooltip: 'radarr.FilterCatalogue'.tr(),
                    icon: LunaIcons.FILTER,
                    selected: filter,
                    options: {
                      for (final value in _CatalogueFilter.values)
                        value: value.label.tr(),
                    },
                    onSelected: (value) {
                      setState(() => filter = value);
                      ChaptarrDatabase.CATALOGUE_FILTER.update(value.name);
                      widget.scroll.animateToStart();
                    },
                  ),
                  LunaCatalogueMenu<bool>(
                    tooltip: 'radarr.SortCatalogue'.tr(),
                    icon: LunaIcons.SORT,
                    selected: byAuthor,
                    ascending: ascending,
                    options: {
                      false: 'chaptarr.Title'.tr(),
                      true: 'chaptarr.Author'.tr(),
                    },
                    onSelected: (value) {
                      setState(() {
                        ascending = value == byAuthor ? !ascending : true;
                        byAuthor = value;
                      });
                      ChaptarrDatabase.SORT_BY_AUTHOR.update(byAuthor);
                      ChaptarrDatabase.SORT_ASCENDING.update(ascending);
                      widget.scroll.animateToStart();
                    },
                  ),
                  LunaCatalogueMenu<bool>(
                    tooltip: 'lunasea.View'.tr(),
                    icon: LunaIcons.VIEW,
                    selected: grid,
                    options: {
                      false: 'lunasea.BlockView'.tr(),
                      true: 'lunasea.GridView'.tr(),
                    },
                    onSelected: (value) {
                      setState(() => grid = value);
                      ChaptarrDatabase.GRID_VIEW.update(value);
                      widget.scroll.animateToStart();
                    },
                  ),
                ],
              ),
            ),
      body: Column(
        children: [
          Expanded(
            child: !widget.upcoming && term.length < 2
                ? ChaptarrPaged<ChaptarrBook>(
                    key: ValueKey((
                      widget.format,
                      widget.revision,
                      byAuthor,
                      ascending,
                      filter,
                      term,
                    )),
                    grid: grid,
                    scroll: widget.scroll,
                    empty:
                        (term.isEmpty
                                ? 'chaptarr.EmptyLibrary'
                                : 'chaptarr.NoResults')
                            .tr(),
                    matches: term.isEmpty
                        ? null
                        : (book) => book.title.toLowerCase().contains(
                            term.toLowerCase(),
                          ),
                    load: (page) => widget.api.library(
                      widget.format,
                      page,
                      byAuthor: byAuthor,
                      ascending: ascending,
                      monitored: switch (filter) {
                        _CatalogueFilter.monitored ||
                        _CatalogueFilter.missing => true,
                        _CatalogueFilter.unmonitored => false,
                        _ => null,
                      },
                      downloaded: switch (filter) {
                        _CatalogueFilter.downloaded => true,
                        _CatalogueFilter.missing => false,
                        _ => null,
                      },
                    ),
                    tile: (book) => ChaptarrBookTile(
                      api: widget.api,
                      book: book,
                      grid: grid,
                      onLongPress: () => widget.onBookActions(book),
                      onTap: book.id == null
                          ? null
                          : () => widget.onBook(book.id!),
                    ),
                  )
                : FutureBuilder<List<ChaptarrBook>>(
                    future: request,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done)
                        return const LunaLoader();
                      if (snapshot.hasError)
                        return LunaMessage.error(onTap: refresh);
                      final books = snapshot.requireData
                          .where(
                            (book) =>
                                book.format == widget.format &&
                                (filter != _CatalogueFilter.unmonitored ||
                                    !book.monitored) &&
                                (filter != _CatalogueFilter.missing ||
                                    (book.monitored && !book.hasFiles)) &&
                                (filter != _CatalogueFilter.monitored ||
                                    book.monitored) &&
                                (filter != _CatalogueFilter.downloaded ||
                                    book.hasFiles),
                          )
                          .toList();
                      books.sort((a, b) {
                        if (widget.upcoming) {
                          final dates =
                              (a.releaseDate?.millisecondsSinceEpoch ?? 0)
                                  .compareTo(
                                    b.releaseDate?.millisecondsSinceEpoch ?? 0,
                                  );
                          if (dates != 0) return dates;
                        } else if (byAuthor) {
                          final authors = a.author.toLowerCase().compareTo(
                            b.author.toLowerCase(),
                          );
                          if (authors != 0)
                            return ascending ? authors : -authors;
                        }
                        final titles = a.title.toLowerCase().compareTo(
                          b.title.toLowerCase(),
                        );
                        return ascending ? titles : -titles;
                      });
                      if (books.isEmpty)
                        return LunaMessage(
                          text:
                              (term.isNotEmpty
                                      ? 'chaptarr.NoResults'
                                      : widget.upcoming
                                      ? 'chaptarr.EmptyUpcoming'
                                      : 'chaptarr.EmptyLibrary')
                                  .tr(),
                          buttonText: 'lunasea.Refresh'.tr(),
                          onTap: refresh,
                        );
                      final covers = !widget.upcoming && grid;
                      Widget tile(BuildContext context, int i) =>
                          ChaptarrBookTile(
                            api: widget.api,
                            book: books[i],
                            grid: covers,
                            onLongPress: () => widget.onBookActions(books[i]),
                            onTap: books[i].id == null
                                ? null
                                : () => widget.onBook(books[i].id!),
                          );
                      return LunaRefreshIndicator(
                        context: context,
                        onRefresh: refresh,
                        child: covers
                            ? LunaGridViewBuilder(
                                controller: widget.scroll,
                                sliverGridDelegate:
                                    LunaGridBlock.getMaxCrossAxisExtent(),
                                itemCount: books.length,
                                itemBuilder: tile,
                              )
                            : LunaListViewBuilder(
                                controller: widget.scroll,
                                itemExtent: LunaBlock.calculateItemExtent(
                                  2,
                                  hasBottom: true,
                                ),
                                itemCount: books.length,
                                itemBuilder: tile,
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

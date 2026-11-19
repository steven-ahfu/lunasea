import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';

class ChaptarrPaged<T> extends StatefulWidget {
  final ScrollController scroll;
  final Future<ChaptarrPage<T>> Function(int) load;
  final Widget Function(T) tile;
  final String empty;
  final bool grid;
  final bool Function(T)? matches;
  const ChaptarrPaged({
    super.key,
    required this.scroll,
    required this.load,
    required this.tile,
    required this.empty,
    this.grid = false,
    this.matches,
  });
  @override
  State<ChaptarrPaged<T>> createState() => _PagedState<T>();
}

class _PagedState<T> extends State<ChaptarrPaged<T>> {
  final refresh = GlobalKey<RefreshIndicatorState>();
  final nextPage = <int, int?>{};
  late final paging = PagingController<int, T>(
    getNextPageKey: (state) =>
        state.keys == null ? 1 : nextPage[state.keys!.last],
    fetchPage: fetch,
  );

  Future<List<T>> fetch(int firstPage) async {
    // Chaptarr's indexed search requires two characters. For shorter queries,
    // skip empty source pages and resume from the last page actually consumed.
    for (var page = firstPage; mounted; page++) {
      final result = await widget.load(page);
      if (!mounted) return [];
      final matches = widget.matches;
      final rows = matches == null
          ? result.records
          : result.records.where(matches).toList();
      final end =
          result.records.length < ChaptarrAPI.pageSize ||
          page * ChaptarrAPI.pageSize >= result.total;
      if (rows.isNotEmpty || end) {
        nextPage[firstPage] = end ? null : page + 1;
        return rows;
      }
    }
    return [];
  }

  @override
  void dispose() {
    paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.grid) {
      return LunaRefreshIndicator(
        context: context,
        onRefresh: () async => paging.refresh(),
        child: PagingListener<int, T>(
          controller: paging,
          builder: (context, state, fetchNextPage) => PagedGridView<int, T>(
            state: state,
            fetchNextPage: fetchNextPage,
            scrollController: widget.scroll,
            padding: LunaUI.MARGIN_HALF,
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: LunaGridBlock.getMaxCrossAxisExtent(),
            builderDelegate: PagedChildBuilderDelegate<T>(
              itemBuilder: (_, row, _) => widget.tile(row),
              firstPageProgressIndicatorBuilder: (_) => const LunaLoader(),
              firstPageErrorIndicatorBuilder: (_) =>
                  LunaMessage.error(onTap: paging.refresh),
              noItemsFoundIndicatorBuilder: (_) => LunaMessage(
                text: widget.empty,
                buttonText: 'lunasea.Refresh'.tr(),
                onTap: paging.refresh,
              ),
            ),
          ),
        ),
      );
    }
    return LunaPagedListView<T>(
      refreshKey: refresh,
      pagingController: paging,
      scrollController: widget.scroll,
      noItemsFoundMessage: widget.empty,
      itemBuilder: (_, row, _) => widget.tile(row),
    );
  }
}

class ChaptarrActivity extends StatefulWidget {
  final ChaptarrAPI api;
  final bool history;
  const ChaptarrActivity({super.key, required this.api, required this.history});
  @override
  State<ChaptarrActivity> createState() => _ActivityState();
}

class _ActivityState extends State<ChaptarrActivity>
    with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: scaffold,
    appBar: LunaAppBar(
      title: (widget.history ? 'chaptarr.History' : 'chaptarr.Queue').tr(),
      scrollControllers: [scrollController],
    ),
    body: ChaptarrPaged<ChaptarrEvent>(
      scroll: scrollController,
      empty: (widget.history ? 'chaptarr.EmptyHistory' : 'chaptarr.EmptyQueue')
          .tr(),
      load: (page) => widget.api.activity(history: widget.history, page: page),
      tile: (event) => LunaBlock(
        title: event.title,
        body: [
          TextSpan(text: event.status),
          TextSpan(text: event.subtitle),
        ],
        bodyLeadingIcons: [
          widget.history ? Icons.history_rounded : Icons.downloading_rounded,
          Icons.info_outline_rounded,
        ],
        onTap: (event.bookId ?? 0) > 0
            ? () => context.push('/chaptarr/book/${event.bookId}')
            : null,
      ),
    ),
  );
}

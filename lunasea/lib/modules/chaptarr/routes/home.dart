import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/router/routes/chaptarr.dart';
import 'package:lunasea/router/routes/settings.dart';

class ChaptarrHome extends StatefulWidget {
  final ChaptarrAPI? api;
  const ChaptarrHome({super.key, required this.api});
  @override
  State<ChaptarrHome> createState() => _HomeState();
}

class _HomeState extends State<ChaptarrHome> {
  final scaffold = GlobalKey<ScaffoldState>();
  late int tab = ChaptarrDatabase.NAVIGATION_INDEX.read().clamp(0, 2);
  ChaptarrFormat format = ChaptarrFormat.ebook;
  int revision = 0;

  Future<void> open(String path) async {
    await context.push('/chaptarr/$path');
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final profiles = LunaProfile.list
        .where((name) => LunaProfile.get(name).chaptarrEnabled)
        .toList();
    return LunaScaffold(
      scaffoldKey: scaffold,
      module: LunaModule.CHAPTARR,
      drawer: LunaDrawer(page: LunaModule.CHAPTARR.key),
      appBar: LunaAppBar.dropdown(
        title: LunaModule.CHAPTARR.title,
        profiles: profiles,
        actions: [
          if (api != null)
            IconButton(
              tooltip: 'chaptarr.FindBook'.tr(),
              icon: const Icon(Icons.add_rounded),
              onPressed: () =>
                  open('${ChaptarrRoutes.LOOKUP.path}?format=${format.name}'),
            ),
        ],
      ),
      bottomNavigationBar: api == null
          ? null
          : BottomNavigationBar(
              currentIndex: tab,
              onTap: (value) {
                setState(() => tab = value);
                ChaptarrDatabase.NAVIGATION_INDEX.update(value);
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.menu_book),
                  label: 'chaptarr.Library'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.download),
                  label: 'chaptarr.Queue'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history),
                  label: 'chaptarr.History'.tr(),
                ),
              ],
            ),
      body: api == null
          ? LunaMessage(
              text: 'chaptarr.Configure'.tr(),
              buttonText: 'settings.ConnectionDetails'.tr(),
              onTap: SettingsRoutes.CONFIGURATION_CHAPTARR.go,
            )
          : Column(
              children: [
                if (tab == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SegmentedButton<ChaptarrFormat>(
                      segments: [
                        ButtonSegment(
                          value: ChaptarrFormat.ebook,
                          label: Text('chaptarr.Ebooks'.tr()),
                        ),
                        ButtonSegment(
                          value: ChaptarrFormat.audiobook,
                          label: Text('chaptarr.Audiobooks'.tr()),
                        ),
                      ],
                      selected: {format},
                      onSelectionChanged: (s) =>
                          setState(() => format = s.single),
                    ),
                  ),
                Expanded(
                  child: tab == 0
                      ? _PagedList<ChaptarrBook>(
                          key: ValueKey((format, revision)),
                          load: (page) => api.library(format, page),
                          empty: 'chaptarr.EmptyLibrary'.tr(),
                          tile: (book) => LunaBlock(
                            title: book.title,
                            posterUrl: api.coverUrl(book.id),
                            posterHeaders: api.coverHeaders,
                            posterPlaceholderIcon: Icons.menu_book,
                            body: [
                              TextSpan(
                                text: [
                                  book.author,
                                  if (book.hasFiles) 'chaptarr.Downloaded'.tr(),
                                ].where((s) => s.isNotEmpty).join(' · '),
                              ),
                            ],
                            trailing: Icon(
                              book.monitored
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              semanticLabel:
                                  (book.monitored
                                          ? 'chaptarr.Monitored'
                                          : 'chaptarr.Unmonitored')
                                      .tr(),
                            ),
                            onTap: book.id == null
                                ? null
                                : () => open('book/${book.id}'),
                          ),
                        )
                      : _PagedList<ChaptarrEvent>(
                          key: ValueKey((tab, revision)),
                          load: (page) =>
                              api.activity(history: tab == 2, page: page),
                          empty:
                              (tab == 1
                                      ? 'chaptarr.EmptyQueue'
                                      : 'chaptarr.EmptyHistory')
                                  .tr(),
                          tile: (event) => LunaBlock(
                            title: event.title,
                            body: [
                              TextSpan(
                                text: [
                                  event.status,
                                  event.subtitle,
                                ].where((s) => s.isNotEmpty).join(' · '),
                              ),
                            ],
                            onTap: (event.bookId ?? 0) <= 0
                                ? null
                                : () => open('book/${event.bookId}'),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _PagedList<T> extends StatefulWidget {
  final Future<ChaptarrPage<T>> Function(int) load;
  final Widget Function(T) tile;
  final String empty;
  const _PagedList({
    super.key,
    required this.load,
    required this.tile,
    required this.empty,
  });
  @override
  State<_PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<_PagedList<T>> {
  int page = 1;
  late Future<ChaptarrPage<T>> request = widget.load(page);

  Future<void> showPage(int target) async {
    final next = widget.load(target);
    setState(() {
      page = target;
      request = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder renders the retry action. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ChaptarrPage<T>>(
    future: request,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return LunaMessage.error(onTap: () => showPage(page));
      final data = snapshot.requireData;
      final pages = (data.total / ChaptarrAPI.pageSize).ceil();
      return Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => showPage(page),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: data.records.isEmpty ? 1 : data.records.length,
                itemBuilder: (_, i) => data.records.isEmpty
                    ? LunaMessage.inList(text: widget.empty)
                    : widget.tile(data.records[i]),
              ),
            ),
          ),
          if (pages > 1 || page > 1)
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'chaptarr.Previous'.tr(),
                    onPressed: page > 1 ? () => showPage(page - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$page / ${pages < page ? page : pages}'),
                  IconButton(
                    tooltip: 'chaptarr.Next'.tr(),
                    onPressed: page < pages ? () => showPage(page + 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

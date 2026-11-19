import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/chaptarr/routes/book_actions.dart';
import 'package:lunasea/modules/chaptarr/routes/catalogue.dart';
import 'package:lunasea/modules/chaptarr/routes/paged.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrHome extends StatefulWidget {
  final ChaptarrAPI? api;
  const ChaptarrHome({super.key, required this.api});
  @override
  State<ChaptarrHome> createState() => _HomeState();
}

class _HomeState extends State<ChaptarrHome> {
  final scaffold = GlobalKey<ScaffoldState>();
  final scroll = List.generate(4, (_) => ScrollController());
  late final pages = LunaPageController(
    initialPage: ChaptarrDatabase.HOME_TAB.read().clamp(0, 3),
  );
  late ChaptarrFormat format =
      ChaptarrFormat.parse(ChaptarrDatabase.FORMAT.read()) ??
      ChaptarrFormat.ebook;
  int revision = 0;
  Future<void> bookActions(ChaptarrBook book) async {
    final result = await showBookActions(context, widget.api!, book);
    if (mounted && result != null) setState(() => revision++);
  }

  bool running = false;
  Future<void> tools(ChaptarrAPI api) async {
    final commands = {
      'web': 'radarr.ViewWebGUI'.tr(),
      'RssSync': 'radarr.RunRSSSync'.tr(),
      'MissingBookSearch': 'radarr.SearchAllMissing'.tr(),
      'RefreshAuthor': 'radarr.UpdateLibrary'.tr(),
      'Backup': 'radarr.BackupDatabase'.tr(),
    };
    final key = await chaptarrChoice(
      context,
      'lunasea.Settings'.tr(),
      commands,
    );
    if (!mounted || key == null || running) return;
    if (key == 'web') {
      await api.webUrl.openLink();
      return;
    }
    if (key == 'MissingBookSearch' &&
        await chaptarrConfirm(context, commands[key]!, format.label) == null)
      return;
    if (!mounted) return;
    setState(() => running = true);
    try {
      await api.libraryCommand(
        key,
        format: key == 'MissingBookSearch' ? format : null,
      );
      if (mounted)
        showLunaSuccessSnackBar(
          title: 'chaptarr.CommandQueued'.tr(),
          message: commands[key]!,
        );
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<void> open(String path) async {
    await context.push('/chaptarr/$path');
    if (mounted) setState(() => revision++);
  }

  void select(ChaptarrFormat value) {
    setState(() => format = value);
    ChaptarrDatabase.FORMAT.update(value.name);
  }

  @override
  void dispose() {
    pages.dispose();
    for (final controller in scroll) {
      controller.dispose();
    }
    super.dispose();
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
        useDrawer: true,
        profiles: profiles,
        pageController: pages,
        scrollControllers: scroll,
        actions: [
          if (api != null)
            Tooltip(
              message: 'chaptarr.AddBook'.tr(),
              child: LunaIconButton.appBar(
                icon: Icons.add_rounded,
                onPressed: () => open('lookup?format=${format.name}'),
              ),
            ),
          if (api != null) ChaptarrFormatMenu(value: format, onChanged: select),
          if (api != null)
            Tooltip(
              message: 'lunasea.Settings'.tr(),
              child: LunaIconButton.appBar(
                icon: Icons.more_vert_rounded,
                onPressed: running ? null : () => tools(api),
              ),
            ),
        ],
      ),
      bottomNavigationBar: api == null
          ? null
          : LunaBottomNavigationBar(
              pageController: pages,
              scrollControllers: scroll,
              onTabChange: (index) => ChaptarrDatabase.HOME_TAB.update(index),
              icons: const [
                Icons.menu_book_rounded,
                Icons.insert_invitation_rounded,
                Icons.event_busy_rounded,
                Icons.more_horiz_rounded,
              ],
              titles: [
                'chaptarr.Library'.tr(),
                'sonarr.Upcoming'.tr(),
                'sonarr.Missing'.tr(),
                'sonarr.More'.tr(),
              ],
            ),
      body: api == null
          ? LunaMessage(
              text: 'chaptarr.Configure'.tr(),
              buttonText: 'settings.ConnectionDetails'.tr(),
              onTap: SettingsRoutes.CONFIGURATION_CHAPTARR.go,
            )
          : LunaPageView(
              controller: pages,
              children: [
                for (final upcoming in [false, true])
                  ChaptarrCatalogue(
                    key: ValueKey(upcoming),
                    revision: revision,
                    api: api,
                    format: format,
                    upcoming: upcoming,
                    scroll: scroll[upcoming ? 1 : 0],
                    onBook: (id) => open('book/$id'),
                    onBookActions: bookActions,
                  ),
                ChaptarrPaged<ChaptarrBook>(
                  key: ValueKey((format, revision)),
                  scroll: scroll[2],
                  load: (page) => api.missing(format, page),
                  empty: 'chaptarr.EmptyMissing'.tr(),
                  tile: (book) => ChaptarrBookTile(
                    api: api,
                    book: book,
                    onLongPress: () => bookActions(book),
                    onTap: book.id == null
                        ? null
                        : () => open('book/${book.id}'),
                  ),
                ),
                LunaListView(
                  controller: scroll[3],
                  children: [
                    for (final item in [
                      ('history', 'radarr.History', Icons.history_rounded),
                      (
                        'import?format=${format.name}',
                        'radarr.ManualImport',
                        Icons.download_done_rounded,
                      ),
                      ('queue', 'radarr.Queue', Icons.queue_play_next_rounded),
                      ('system', 'radarr.SystemStatus', Icons.computer_rounded),
                      ('tags', 'radarr.Tags', Icons.style_rounded),
                    ].indexed)
                      LunaBlock(
                        title: item.$2.$2.tr(),
                        body: [TextSpan(text: '${item.$2.$2}Description'.tr())],
                        trailing: LunaIconButton(
                          icon: item.$2.$3,
                          color: LunaColours().byListIndex(item.$1),
                        ),
                        onTap: () => open(item.$2.$1),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

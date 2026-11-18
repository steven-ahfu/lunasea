import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lunasea/api/radarr/models.dart';
import 'package:lunasea/api/sonarr/models.dart';
import 'package:lunasea/modules/lidarr.dart';
import 'package:lunasea/modules/radarr/routes/releases/widgets/release_tile.dart';
import 'package:lunasea/modules/sonarr/routes/releases/widgets/release_tile.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/types/release_filters.dart';
import 'package:lunasea/vendor.dart' show ChangeNotifierProvider;
import 'package:lunasea/widgets/ui/release_filters_button.dart';

enum _Approval { all, approved, rejected }

class _Harness extends StatefulWidget {
  final List<LunaReleaseFilterData> releases;

  const _Harness({super.key, required this.releases});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  LunaReleaseFilters filters = LunaReleaseFilters();
  _Approval approval = _Approval.all;
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LunaReleaseFiltersButton<_Approval>(
      controller: controller,
      tooltip: 'Filter releases',
      approvalOptions: const {
        _Approval.all: 'All',
        _Approval.approved: 'Approved',
        _Approval.rejected: 'Rejected',
      },
      approval: approval,
      allApproval: _Approval.all,
      onApprovalChanged: (value) => setState(() => approval = value),
      filters: filters,
      onFiltersChanged: (value) => setState(() => filters = value),
      releases: Future.value(widget.releases),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, dynamic> translations;

  setUpAll(() async {
    translations =
        jsonDecode(File('assets/localization/en.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(translations['lunasea.ReleaseFilterAny'], 'Any');
    Localization.load(
      const Locale('en'),
      translations: Translations(translations),
    );
    directory = await Directory.systemTemp.createTemp('lunasea-filter-tests-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>('lunasea');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<GlobalKey<_HarnessState>> pumpMenu(
    WidgetTester tester, {
    int trackerCount = 2,
  }) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: false),
        home: _Harness(
          key: key,
          releases: [
            for (var i = 1; i <= trackerCount; i++)
              LunaReleaseFilterData(
                title: i == 1 ? 'Movie.TrueHD.7.1' : 'Movie.AAC',
                values: {
                  LunaReleaseFilter.indexer: [
                    LunaReleaseFilterOption.named('Tracker $i', id: i),
                  ],
                  LunaReleaseFilter.resolution: [
                    LunaReleaseFilterOption.resolution(1080),
                  ],
                },
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect('lunasea.ReleaseFilterAny'.tr(), 'Any');
    return key;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Filter releases'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Lidarr audio picker uses album quality, falls back to title, and clears',
    (tester) async {
      LidarrReleaseData album(String title, String quality) =>
          LidarrReleaseData(
            title: title,
            quality: quality,
            guid: title,
            protocol: 'torrent',
            indexer: 'Tracker',
            infoUrl: '',
            approved: true,
            releaseWeight: 1,
            size: 100,
            indexerId: 1,
            ageHours: 1,
            rejections: [],
          );
      final albums = [
        album('Album One', 'FLAC 24bit'),
        album('Album Two FLAC', 'MP3-320'),
        album('Album Three [flac]', 'Unknown'),
        album('Album Four', 'Unknown'),
        album('Album Five', 'ALAC'),
      ];
      var filters = LunaReleaseFilters();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LidarrState(),
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) => LidarrReleasesSearchBar(
                  scrollController: controller,
                  releases: albums,
                  filters: filters,
                  onFiltersChanged: (value) => setState(() => filters = value),
                ),
              ),
            ),
          ),
        ),
      );

      Future<void> openAudio() async {
        await tester.tap(find.byTooltip('Audio format'));
        await tester.pumpAndSettle();
      }

      await openAudio();
      for (final label in ['FLAC', 'MP3', 'ALAC', 'Unknown']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('FLAC'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        albums
            .where((a) => filters.matches(a.lunaFilterData))
            .map((a) => a.title),
        ['Album One', 'Album Three [flac]'],
      );
      await openAudio();
      await tester.tap(find.text('Clear'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(filters.activeCount, 0);
    },
  );

  for (final service in ['Radarr', 'Sonarr']) {
    testWidgets(
      '$service card state belongs to the release when the first result is removed',
      (tester) async {
        Widget card(String indexer) {
          final json = {
            'title': 'Shared movie title',
            'indexer': indexer,
            'customFormats': [
              {'id': 1, 'name': '$indexer format'},
            ],
            'protocol': 'torrent',
            'approved': true,
            'rejected': false,
          };
          return service == 'Radarr'
              ? RadarrReleasesTile(release: RadarrRelease.fromJson(json))
              : SonarrReleasesTile(release: SonarrRelease.fromJson(json));
        }

        final first = card('First tracker');
        final second = card('Second tracker');
        Future<void> show(List<Widget> cards) async {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: LunaRouter.navigator,
              home: Scaffold(
                body: ListView.builder(
                  itemCount: cards.length,
                  itemBuilder: (_, i) => cards[i],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show([first, second]);
        final firstState = tester.state(find.byWidget(first));
        await tester.tap(
          find
              .textContaining('First tracker', findRichText: true)
              .hitTestable()
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('First tracker format').hitTestable(), findsOneWidget);
        await show([second]);
        expect(tester.state(find.byWidget(second)), isNot(same(firstState)));
        expect(
          find.textContaining('Second tracker', findRichText: true),
          findsWidgets,
        );
        expect(
          find.textContaining('First tracker', findRichText: true),
          findsNothing,
        );
        expect(find.text('Second tracker format').hitTestable(), findsNothing);
        await tester.tap(
          find
              .textContaining('Second tracker', findRichText: true)
              .hitTestable()
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Second tracker format').hitTestable(),
          findsOneWidget,
        );
      },
    );
  }

  Future<void> openTracker(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.textContaining('Tracker / indexer:'));
    await tester.pumpAndSettle();
  }

  testWidgets('release dropdown exposes the supported filter groups', (
    tester,
  ) async {
    await pumpMenu(tester);
    await openMenu(tester);
    for (final title in [
      'All',
      'Approved',
      'Rejected',
      'Tracker / indexer: Any',
      'Quality: Any',
      'Resolution: Any',
      'Dual audio: Any',
      'Audio format: Any',
      'Language: Any',
      'Custom formats (match all): Any',
      'Clear all filters',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('Seeders'), findsNothing);
    expect(find.textContaining('Size:'), findsNothing);
    expect(find.textContaining('Protocol:'), findsNothing);
    expect(find.textContaining('Age:'), findsNothing);
  });

  testWidgets('audio format picker applies TrueHD to the matching releases', (
    tester,
  ) async {
    final key = await pumpMenu(tester);
    await openMenu(tester);
    await tester.tap(find.text('Audio format: Any'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TrueHD'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    expect(
      state.widget.releases.where(state.filters.matches).map((r) => r.title),
      ['Movie.TrueHD.7.1'],
    );
  });

  testWidgets(
    'multi-select applies together; cancel preserves active filters',
    (tester) async {
      final key = await pumpMenu(tester);
      await openTracker(tester);
      await tester.tap(find.text('Tracker 1'));
      await tester.tap(find.text('Tracker 2'));
      expect(key.currentState!.filters.activeCount, 0);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        key.currentState!.filters.selectedFor(LunaReleaseFilter.indexer).length,
        2,
      );
      await openTracker(tester);
      await tester.tap(find.text('Tracker 1'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        key.currentState!.filters.selectedFor(LunaReleaseFilter.indexer).length,
        2,
      );
      await openMenu(tester);
      await tester.tap(find.text('Resolution: Any'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1080p'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(key.currentState!.filters.activeCount, 2);
      expect(
        key.currentState!.filters.selectedFor(LunaReleaseFilter.indexer).length,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear-all resets approval and extra filters', (tester) async {
    final key = await pumpMenu(tester);
    await openTracker(tester);
    await tester.tap(find.text('Tracker 1'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    expect(key.currentState!.filters.activeCount, 1);
    await openMenu(tester);
    await tester.ensureVisible(find.text('Clear all filters'));
    await tester.tap(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    expect(key.currentState!.filters.activeCount, 0);
    expect(key.currentState!.approval, _Approval.all);
  });

  testWidgets('searching choices retains hidden selections', (tester) async {
    final key = await pumpMenu(tester, trackerCount: 12);
    await openTracker(tester);
    await tester.enterText(find.byType(TextField), 'Tracker 1');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Tracker 1'));
    await tester.enterText(find.byType(TextField), 'Tracker 2');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Tracker 2'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      key.currentState!.filters.selectedFor(LunaReleaseFilter.indexer).length,
      2,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/add_book.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes/chaptarr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/localization/en.json').readAsStringSync()),
      ),
    );
    temp = await Directory.systemTemp.createTemp('chaptarr-ui-');
    Hive.init(temp.path);
    await Hive.openBox<dynamic>('lunasea', bytes: Uint8List(0));
    await Hive.openBox<LunaProfile>('profiles', bytes: Uint8List(0));
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets(
    'library, upcoming, missing, activity and slow book import at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dio = Dio(BaseOptions(baseUrl: 'https://chaptarr.example/api/v1/'));
      final release = Completer<void>();
      int posts = 0;
      int bookUpdates = 0;
      int authorUpdates = 0;
      var quality = 1;
      var monitored = true;
      var selectedEdition = 101;
      final libraryBook = {
        'id': 14,
        'title': 'Library book',
        'mediaType': 'ebook',
        'monitored': true,
        'authorTitle': 'Example author',
      };
      final toAdd = {
        'title': 'New title',
        'foreignBookId': 'gr:101',
        'author': {'foreignAuthorId': 'gr:1', 'authorName': 'Example author'},
      };
      final requests = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, handler) async {
            requests.add(req.path);
            Object body;
            switch (req.path) {
              case 'book/paged':
                body = {
                  'records': [libraryBook],
                  'totalCount': 1,
                };
              case 'calendar':
                body = [
                  {
                    ...libraryBook,
                    'title': 'Coming soon',
                    'releaseDate': '2026-11-24T00:00:00Z',
                  },
                ];
              case 'wanted/missing':
                body = {
                  'records': [
                    {...libraryBook, 'title': 'Missing title'},
                  ],
                  'totalRecords': 1,
                };
              case 'queue':
              case 'history':
                if (req.path == 'history')
                  expect(req.queryParameters['bookId'], 19);
                body = {'records': [], 'totalRecords': 0};
              case 'bookfile':
                expect(req.queryParameters['bookId'], 19);
                body = [
                  {
                    'path': '/ebooks/Example.epub',
                    'size': 2048,
                    'quality': {
                      'quality': {'name': 'EPUB'},
                    },
                  },
                ];
              case 'book/lookup':
                body = [
                  {
                    ...toAdd,
                    if (release.isCompleted)
                      'localEbookBooks': [
                        {'id': 19, 'title': 'New title'},
                      ],
                  },
                ];
              case 'rootfolder':
                body = [
                  {
                    'folderType': 2,
                    'path': '/ebooks',
                    'ebookQualityProfileId': 1,
                    'ebookMetadataProfileId': 2,
                  },
                ];
              case 'book/import':
                posts++;
                expect(req.data['rootFolder'], '/ebooks');
                expect(req.data['mediaType'], 'ebook');
                await release.future;
                body = {'id': 19};
              case 'book/19':
                if (req.method == 'PUT') {
                  bookUpdates++;
                  expect(req.data['ebookMonitored'], false);
                  expect(req.data['audiobookMonitored'], true);
                  expect(req.data['anyEditionOk'], false);
                  expect(req.data['foreignBookId'], toAdd['foreignBookId']);
                  final active = (req.data['editions'] as List).where(
                    (e) => e['monitored'] == true,
                  );
                  selectedEdition = active.single['id'];
                  expect(active.single['publisher'], 'New press');
                  monitored = req.data['monitored'];
                }
                body = {
                  ...toAdd,
                  'id': 19,
                  'mediaType': 'ebook',
                  'monitored': monitored,
                  'anyEditionOk': bookUpdates == 0,
                  'audiobookMonitored': true,
                  'authorId': 4,
                };
              case 'edition':
                expect(req.queryParameters['bookId'], 19);
                body = [
                  for (final id in [101, 102])
                    {
                      'id': id,
                      'title': id == 101
                          ? 'Original edition'
                          : 'Second edition',
                      'publisher': id == 101 ? 'First press' : 'New press',
                      'monitored': selectedEdition == id,
                    },
                ];
              case 'author/4':
                if (req.method == 'PUT') {
                  authorUpdates++;
                  expect(req.data['audiobookQualityProfileId'], 3);
                  expect(req.queryParameters['moveFiles'], false);
                  quality = req.data['ebookQualityProfileId'];
                }
                body = {
                  'id': 4,
                  'authorName': 'Example author',
                  'ebookQualityProfileId': quality,
                  'audiobookQualityProfileId': 3,
                  'ebookMetadataProfileId': 2,
                  'ebookRootFolderPath': '/ebooks',
                  'ebookTags': [],
                };
              case 'qualityprofile':
                body = [
                  {'id': 1, 'name': 'Default books', 'profileType': 'ebook'},
                  {'id': 2, 'name': 'EPUB only', 'profileType': 'ebook'},
                  {'id': 3, 'name': 'Audio only', 'profileType': 'audiobook'},
                ];
              case 'metadataprofile':
                body = [
                  {'id': 2, 'name': 'Book metadata', 'profileType': 2},
                ];
              case 'tag':
                body = [];
              case 'release':
                if (req.method == 'POST') {
                  expect(req.data, {
                    'bookId': 19,
                    'guid': 'release-42',
                    'indexerId': 7,
                  });
                  body = {};
                } else {
                  expect(req.queryParameters['bookId'], 19);
                  body = {
                    'releases': [
                      {
                        'title': 'Example EPUB',
                        'guid': 'release-42',
                        'indexerId': 7,
                        'protocol': 'torrent',
                        'indexer': 'Books tracker',
                        'size': 8192,
                        'seeders': 12,
                        'quality': {
                          'quality': {'name': 'EPUB'},
                        },
                        'downloadAllowed': true,
                      },
                    ],
                    'hiddenReleases': [
                      {
                        'title': 'Wrong format',
                        'rejections': ['Wrong format'],
                        'hasHardFilters': true,
                      },
                    ],
                  };
                }
              default:
                throw StateError(req.path);
            }
            handler.resolve(
              Response(requestOptions: req, statusCode: 200, data: body),
            );
          },
        ),
      );
      final state = ChaptarrState()
        ..enabled = true
        ..api = ChaptarrAPI.withClient(dio);
      final router = GoRouter(
        navigatorKey: LunaRouter.navigator,
        initialLocation: '/chaptarr',
        routes: [ChaptarrRoutes.HOME.routes],
      );
      LunaRouter.router = router;
      addTearDown(router.dispose);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp.router(
            theme: ThemeData.dark(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
      }

      await settle();
      expect(find.text('Library book', findRichText: true), findsOneWidget);
      final search = find.byType(TextField);
      final compactWidth = tester.getSize(search).width;
      await tester.enterText(search, 'z');
      await tester.pump(const Duration(milliseconds: 400));
      await settle();
      expect(tester.getSize(search).width, greaterThan(compactWidth + 100));
      expect(find.text('Library book', findRichText: true), findsNothing);
      await tester.enterText(search, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      expect(tester.getSize(search).width, compactWidth);
      await tester.tap(find.byTooltip('View'));
      await settle();
      await tester.tap(find.widgetWithText(PopupMenuItem<bool>, 'Grid View'));
      await settle();
      expect(find.byType(LunaGridBlock), findsOneWidget);
      Finder tab(IconData icon) => find.byWidgetPredicate(
        (widget) => widget is GButton && widget.icon == icon,
      );
      await tester.tap(tab(Icons.insert_invitation_rounded));
      await settle();
      expect(find.text('Coming soon', findRichText: true), findsOneWidget);
      await tester.tap(tab(Icons.event_busy_rounded));
      await settle();
      expect(find.text('Missing title', findRichText: true), findsOneWidget);
      await tester.tap(tab(Icons.more_horiz_rounded));
      await settle();
      await tester.tap(find.text('Queue', findRichText: true));
      await settle();
      expect(requests, contains('queue'));
      router.pop();
      await settle();
      await tester.tap(find.byTooltip('Add book'));
      await settle();
      await tester.enterText(find.byType(TextField), 'New');
      await tester.pump(const Duration(milliseconds: 550));
      await settle();
      Future<void> openResult() async {
        await tester.tap(find.text('New title', findRichText: true));
        await settle();
      }

      await openResult();
      expect(find.text('/ebooks', findRichText: true), findsOneWidget);
      await tester.tap(find.widgetWithText(LunaButton, 'Add book'));
      await settle();
      expect(posts, 1);
      expect(find.textContaining('You can return to search'), findsOneWidget);
      await tester.tap(find.widgetWithText(LunaButton, 'Go Back'));
      await settle();
      await openResult();
      expect(posts, 1);
      expect(find.textContaining('You can return to search'), findsOneWidget);
      release.complete();
      await settle();
      expect(find.text('Book added'), findsOneWidget);
      await tester.tap(find.widgetWithText(LunaButton, 'Book details'));
      await settle();
      expect(requests, contains('book/19'));
      await tester.tap(find.byTooltip('Edit Book'));
      await settle();
      await tester.tap(find.byType(LunaSwitch).first);
      await settle();
      await tester.tap(find.text('Edition', findRichText: true));
      await settle();
      await tester.tap(find.text('Second edition · New press'));
      await settle();
      await tester.tap(find.text('Author settings', findRichText: true));
      await settle();
      expect(find.text('Book metadata', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Quality Profile', findRichText: true));
      await settle();
      expect(find.text('Audio only'), findsNothing);
      await tester.tap(find.text('EPUB only'));
      await settle();
      await tester.tap(find.widgetWithText(LunaButton, 'Update'));
      await settle();
      expect(authorUpdates, 1);
      expect(quality, 2);
      expect(bookUpdates, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(LunaButton, 'Update'));
      await settle();
      expect(bookUpdates, 1);
      expect(monitored, false);
      expect(selectedEdition, 102);
      expect(find.byTooltip('Unmonitored'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit Book'));
      await settle();
      expect(
        find.text('Second edition · New press', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byType(LunaSwitch).first);
      router.pop();
      await settle();
      expect(bookUpdates, 1);
      await tester.tap(tab(Icons.insert_drive_file_outlined));
      await settle();
      expect(find.text('Example.epub', findRichText: true), findsOneWidget);
      await tester.tap(tab(Icons.history_rounded));
      await settle();
      expect(requests, contains('history'));
      await tester.tap(find.widgetWithText(LunaButton, 'Interactive'));
      await settle();
      final releaseTitle = find
          .text('Example EPUB', findRichText: true)
          .hitTestable();
      expect(releaseTitle, findsOneWidget);
      await tester.enterText(find.byType(TextField), 'epub');
      await settle();
      expect(find.text('Wrong format', findRichText: true), findsNothing);
      await tester.tap(releaseTitle);
      await settle();
      expect(find.text('SEEDERS', findRichText: true), findsWidgets);
      await tester.tap(find.widgetWithText(LunaButton, 'Download'));
      await settle();
      expect(requests.where((p) => p == 'release'), hasLength(2));
      expect(find.text('sonarr.DownloadingRelease'.tr()), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await settle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'queue removal and manual import preview require explicit selections',
    (tester) async {
      final requests = <RequestOptions>[];
      bool removed = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://books.example/api/v1/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, handler) {
            requests.add(req);
            final Object data = switch (req.path) {
              'book/paged' => {'records': [], 'totalCount': 0},
              'queue' => {
                'records': [
                  if (!removed)
                    {
                      'id': 4,
                      'title': 'Queue item',
                      'status': 'completed',
                      'downloadId': 'job-4',
                      'mediaType': 'audiobook',
                    },
                ],
                'totalRecords': removed ? 0 : 1,
              },
              'manualimport' => [
                {
                  'id': 7,
                  'path': '/test/file.m4b',
                  'book': {'id': 14, 'title': 'Matched edition'},
                  'author': {'id': 3},
                  'editionId': 16,
                  'quality': {
                    'quality': {'id': 2},
                  },
                },
              ],
              'command' || 'queue/4' => {},
              'calendar' => [],
              'wanted/missing' ||
              'history' => {'records': [], 'totalRecords': 0},
              _ => throw StateError(req.path),
            };
            if (req.path == 'queue/4') removed = true;
            handler.resolve(
              Response(requestOptions: req, statusCode: 200, data: data),
            );
          },
        ),
      );
      final state = ChaptarrState()
        ..enabled = true
        ..api = ChaptarrAPI.withClient(dio);
      final router = GoRouter(
        navigatorKey: LunaRouter.navigator,
        initialLocation: '/chaptarr/queue',
        routes: [ChaptarrRoutes.HOME.routes],
      );
      LunaRouter.router = router;
      addTearDown(router.dispose);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp.router(
            theme: ThemeData.dark(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );
      Future<void> tap(String label) async {
        await tester.tap(
          find.text(label, findRichText: true).hitTestable().last,
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpAndSettle();
      await tap('Queue item');
      await tap('Remove from queue');
      await tap('Cancel');
      expect(removed, isFalse);
      await tap('Queue item');
      await tap('Manual Import');
      final preview = requests.lastWhere((r) => r.path == 'manualimport');
      expect(preview.queryParameters['mediaType'], 'audiobook');
      expect(preview.queryParameters['downloadId'], 'job-4');
      expect(find.widgetWithText(LunaButton, 'Import'), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tap('Import');
      await tap('Copy or hardlink');
      await tap('Import');
      final command = requests
          .singleWhere((r) => r.method == 'POST' && r.path == 'command')
          .data;
      expect(command['name'], 'ManualImport');
      expect(command['importMode'], 'copy');
      expect(command['replaceExistingFiles'], false);
      expect(command['files'].single['editionId'], 16);
      expect(command['files'].single['downloadId'], 'job-4');
      await tap('Queue item');
      await tap('Remove from queue');
      await tap('Blocklist this release');
      await tap('Remove from queue');
      expect(requests.lastWhere((r) => r.method == 'DELETE').queryParameters, {
        'removeFromClient': false,
        'blocklist': true,
        'skipRedownload': false,
        'changeCategory': false,
      });
      expect(find.text('Queue item', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'lost import response reconciles the audiobook without posting again',
    (tester) async {
      final client = Dio(BaseOptions(baseUrl: 'https://books.example/api/v1/'));
      final book = ChaptarrBook.fromJson({
        'title': 'Example',
        'foreignBookId': 'gr:7',
        'author': {'foreignAuthorId': 'gr:2'},
      });
      final paths = <String>[];
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            paths.add(request.path);
            if (request.path == 'book/import') {
              expect(request.data['mediaType'], 'audiobook');
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
              return;
            }
            final data = request.path == 'rootfolder'
                ? [
                    {
                      'path': '/audio',
                      'folderType': 1,
                      'audiobookQualityProfileId': 2,
                      'audiobookMetadataProfileId': 3,
                    },
                  ]
                : [
                    {
                      'foreignBookId': 'gr:7',
                      'localAudiobookBooks': [
                        {'id': 25, 'title': 'Example'},
                      ],
                    },
                  ];
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      final api = ChaptarrAPI.withClient(client);
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: LunaRouter.navigator,
          theme: ThemeData.dark(useMaterial3: false),
          home: ChaptarrAddBook(
            api: api,
            book: book,
            format: ChaptarrFormat.audiobook,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(LunaButton, 'Add book'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(LunaButton, 'Check library'));
      await tester.pumpAndSettle();
      expect(find.text('Book added'), findsOneWidget);
      expect(paths, ['rootfolder', 'book/import', 'book/lookup']);
    },
  );
}

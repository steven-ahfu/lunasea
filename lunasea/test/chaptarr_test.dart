import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/api/chaptarr/chaptarr.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/modules.dart';

void main() {
  test(
    'clearing author tags cannot restore combined tags or change the other format',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://books.example/api/v1/'));
      addTearDown(dio.close);
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, handler) {
            requests.add(req);
            handler.resolve(
              Response(
                requestOptions: req,
                statusCode: 200,
                data: {
                  'id': 4,
                  'ebookTags': [5],
                  'audiobookTags': [8],
                  'tags': [5, 8],
                },
              ),
            );
          },
        ),
      );
      await ChaptarrAPI.withClient(dio).updateAuthor(
        4,
        {'ebookTags': <int>[]},
        format: ChaptarrFormat.ebook,
        moveFiles: false,
      );
      final put = requests.last;
      expect(put.method, 'PUT');
      expect(put.path, 'author/4');
      expect(put.queryParameters, {'mediaType': 'ebook', 'moveFiles': false});
      expect(put.data, {
        'id': 4,
        'ebookTags': [],
        'audiobookTags': [8],
      });
    },
  );
  test('older profile backups default to a disabled Chaptarr connection', () {
    final original = LunaProfile(sonarrHost: 'https://sonarr.example');
    final backup = original.toJson()
      ..removeWhere((k, _) => k.startsWith('chaptarr'));
    final restored = LunaProfile.fromJson(backup);
    expect(restored.sonarrHost, original.sonarrHost);
    expect(restored.chaptarrEnabled, isFalse);
    expect(restored.chaptarrHeaders, isEmpty);
    restored.chaptarrEnabled = true;
    restored.chaptarrHeaders['X-Test'] = 'value';
    expect(LunaProfile.clone(restored).chaptarrHeaders, {'X-Test': 'value'});
    expect(LunaModule.fromKey('chaptarr'), LunaModule.CHAPTARR);
  });

  test('lookup preserves distinct local editions of each format', () {
    final book = ChaptarrBook.fromJson({
      'title': 'Example',
      'localEbookBooks': [
        {'id': 1, 'title': 'Text edition'},
      ],
      'localAudiobookBooks': [
        {'id': 2, 'title': 'First recording', 'narrator': 'A'},
        {'id': 3, 'title': 'New recording', 'narrator': 'B'},
      ],
    });
    expect(book.localEditions(ChaptarrFormat.ebook).single.id, 1);
    expect(book.localEditions(ChaptarrFormat.audiobook).map((e) => e.id), [
      2,
      3,
    ]);
  });

  test(
    'roots accept mixed and matching folders with valid per-format profiles',
    () {
      final mixed = {
        'folderType': 0,
        'path': '/library',
        'audiobook': {'qualityProfileId': 12, 'metadataProfileId': 7},
        'ebookQualityProfileId': 9,
        'ebookMetadataProfileId': 14,
      };
      expect(
        ChaptarrRoot.forFormat(mixed, ChaptarrFormat.ebook)?.qualityProfileId,
        9,
      );
      expect(
        ChaptarrRoot.forFormat(
          mixed,
          ChaptarrFormat.audiobook,
        )?.metadataProfileId,
        7,
      );
      expect(
        ChaptarrRoot.forFormat({
          ...mixed,
          'folderType': 2,
        }, ChaptarrFormat.audiobook),
        isNull,
      );
      expect(
        ChaptarrRoot.forFormat({
          ...mixed,
          'ebookQualityProfileId': 0,
        }, ChaptarrFormat.ebook),
        isNull,
      );
    },
  );

  test(
    'paged reads and writes keep the server URL prefix, media type and local book ID',
    () async {
      const base = 'https://books.example/services/chaptarr/api/v1/';
      final dio = Dio(BaseOptions(baseUrl: base));
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, handler) {
            requests.add(req);
            final body = switch (req.path) {
              'book/paged' => {'records': [], 'totalCount': 68},
              'queue' || 'history' => {'records': [], 'totalRecords': 0},
              'book/import' => {'id': 90},
              'book/lookup' => [
                {
                  'title': 'Test',
                  'foreignBookId': 'gr:42',
                  'author': {'foreignAuthorId': 'gr:1'},
                },
              ],
              _ => <String, dynamic>{},
            };
            handler.resolve(
              Response(requestOptions: req, statusCode: 200, data: body),
            );
          },
        ),
      );
      final api = ChaptarrAPI.withClient(dio);
      addTearDown(api.close);
      expect((await api.library(ChaptarrFormat.audiobook, 2)).total, 68);
      expect(requests.last.uri.path, '/services/chaptarr/api/v1/book/paged');
      expect(requests.last.queryParameters, containsPair('offset', 50));
      expect(
        requests.last.queryParameters,
        containsPair('mediaType', 'audiobook'),
      );
      final book = (await api.lookup('  Example  ')).single;
      expect(requests.last.queryParameters['term'], 'Example');
      expect(
        await api.add(
          book,
          ChaptarrFormat.ebook,
          const ChaptarrRoot('/ebooks', 9, 11),
        ),
        90,
      );
      expect(requests.last.data, containsPair('foreignAuthorId', 'gr:1'));
      expect(requests.last.data, containsPair('mediaType', 'ebook'));
      expect(
        requests.last.data['authorMonitoring']['searchForMissing'],
        isFalse,
      );
      await api.setMonitored(90, false);
      expect(requests.last.method, 'PUT');
      expect(requests.last.data, {
        'bookIds': [90],
        'monitored': false,
      });
      await api.searchReleases(90);
      expect(requests.last.data, {
        'name': 'BookSearch',
        'bookIds': [90],
      });
      await api.activity(history: true, page: 3);
      expect(requests.last.queryParameters['page'], 3);
    },
  );
}

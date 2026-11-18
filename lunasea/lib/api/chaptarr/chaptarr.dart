import 'package:dio/dio.dart';
import 'package:lunasea/api/chaptarr/api.dart';
import 'package:lunasea/api/chaptarr/models.dart';
import 'package:lunasea/database/models/profile.dart';

export 'package:lunasea/api/chaptarr/models.dart';

class ChaptarrAPI {
  static const pageSize = 50;
  final Dio _client;
  final ChaptarrService _service;

  ChaptarrAPI.withClient(this._client) : _service = ChaptarrService(_client);

  factory ChaptarrAPI.from(LunaProfile profile) {
    final host = profile.chaptarrHost.trim().replaceFirst(RegExp(r'/+$'), '');
    return ChaptarrAPI.withClient(
      Dio(
        BaseOptions(
          baseUrl: '$host/api/v1/',
          headers: {
            ...profile.chaptarrHeaders,
            'X-Api-Key': profile.chaptarrKey.trim(),
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 3),
          followRedirects: false,
        ),
      ),
    );
  }

  // Local Chaptarr media route, including any reverse-proxy path prefix.
  String? coverUrl(int? id) => id == null || id <= 0
      ? null
      : Uri.parse(
          _client.options.baseUrl,
        ).resolve('../../MediaCover/Books/$id/cover.jpg').toString();

  Map<String, String> get coverHeaders =>
      Map<String, String>.from(_client.options.headers)
        ..removeWhere((key, _) => key.toLowerCase() == 'content-type');

  void close() => _client.close(force: true);

  Future<void> testConnection() async {
    final status = await _service.status();
    if (status.appName.toLowerCase() != 'chaptarr') {
      throw const FormatException('Expected a Chaptarr server');
    }
  }

  Future<ChaptarrPage<ChaptarrBook>> library(
    ChaptarrFormat format,
    int page,
  ) async {
    return _service.books({
      'offset': (page - 1) * pageSize,
      'pageSize': pageSize,
      'includeUnmonitored': true,
      'mediaType': format.name,
      'include': 'author',
    });
  }

  Future<ChaptarrBook> book(int id) => _service.book(id);

  Future<List<ChaptarrBook>> lookup(String term) =>
      _service.lookup(term.trim());

  Future<List<ChaptarrRoot>> roots(ChaptarrFormat format) async =>
      (await _service.roots())
          .map((root) => root.settings[format])
          .whereType<ChaptarrRoot>()
          .toList();

  Future<int> add(
    ChaptarrBook book,
    ChaptarrFormat format,
    ChaptarrRoot root,
  ) async {
    final result = await _service.addBook({
      'foreignBookId': book.foreignBookId,
      'foreignAuthorId': book.foreignAuthorId,
      'foreignEditionId': '0',
      'mediaType': format.name,
      'rootFolder': root.path,
      'qualityProfileId': root.qualityProfileId,
      'metadataProfileId': root.metadataProfileId,
      'authorMonitoring': {
        'monitor': 'specificBook',
        'searchForMissing': false,
      },
    });
    return result.id;
  }

  Future<void> setMonitored(int id, bool monitored) => _service.monitor({
    'bookIds': [id],
    'monitored': monitored,
  });

  Future<void> searchReleases(int id) => _service.command({
    'name': 'BookSearch',
    'bookIds': [id],
  });

  Future<ChaptarrPage<ChaptarrEvent>> activity({
    required bool history,
    required int page,
  }) async {
    final query = {'page': page, 'pageSize': pageSize, 'includeBook': true};
    if (history) {
      return _service.history({
        ...query,
        'sortKey': 'date',
        'sortDirection': 'descending',
      });
    }
    return _service.queue(query);
  }
}

import 'package:dio/dio.dart';
import 'package:lunasea/api/chaptarr/api.dart';
import 'package:lunasea/api/chaptarr/models.dart';
import 'package:lunasea/api/chaptarr/releases.dart';
export 'package:lunasea/api/chaptarr/releases.dart';
import 'package:lunasea/database/models/profile.dart';

export 'package:lunasea/api/chaptarr/models.dart';

class ChaptarrAPI {
  static const pageSize = 50;
  final Dio _client;
  final ChaptarrService _service;
  final _imports = <(String, ChaptarrFormat), Future<int>>{};

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

  String? bookCover(ChaptarrBook book) =>
      artworkUrl(book.cover) ?? coverUrl(book.id);

  String? artworkUrl(String? path) {
    if (path != null &&
        (path.startsWith('/MediaCover/') ||
            path.startsWith('/MediaCoverProxy/'))) {
      return Uri.parse(
        _client.options.baseUrl,
      ).resolve('../..$path').toString();
    }
    final uri = Uri.tryParse(path ?? '');
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }

  Map<String, String> artworkHeaders(String? url) =>
      url != null &&
          Uri.parse(url).origin == Uri.parse(_client.options.baseUrl).origin
      ? coverHeaders
      : const {};

  Future<List<ChaptarrBook>> searchLibrary(
    String term,
    ChaptarrFormat format,
  ) async {
    final matches = await _service.librarySearch(term, pageSize);
    final ids = matches.books
        .expand((book) => book.localEditions(format))
        .map((edition) => edition.id)
        .toSet();
    if (ids.isEmpty) return [];
    final books = await _service.catalogue({
      'bookIds': ids.toList(),
      'include': 'author',
    });
    return books
        .where((book) => book.format == format && ids.contains(book.id))
        .toList();
  }

  Future<List<ChaptarrBook>> upcoming(DateTime today) {
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(today.year, today.month, today.day + 30);
    return _service.calendar({
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'includeAuthor': true,
    });
  }

  Future<ChaptarrPage<ChaptarrBook>> missing(ChaptarrFormat format, int page) =>
      _service.missing({
        'mediaType': format.name,
        'page': page,
        'pageSize': pageSize,
        'sortKey': 'releaseDate',
        'sortDirection': 'descending',
        'includeAuthor': true,
      });

  void close() => _client.close(force: true);

  Future<void> testConnection() async {
    final status = await _service.status();
    if (status.appName.toLowerCase() != 'chaptarr') {
      throw const FormatException('Expected a Chaptarr server');
    }
  }

  Future<ChaptarrPage<ChaptarrBook>> library(
    ChaptarrFormat format,
    int page, {
    bool byAuthor = false,
    bool ascending = true,
    bool? monitored,
    bool? downloaded,
  }) async {
    return _service.books({
      'offset': (page - 1) * pageSize,
      'sortKey': byAuthor ? 'authorTitle' : 'cleanTitle',
      'sortDirection': ascending ? 'ASC' : 'DESC',
      'pageSize': pageSize,
      'includeUnmonitored': true,
      'monitored': ?monitored,
      'downloaded': ?downloaded,
      'mediaType': format.name,
      'include': 'author',
    });
  }

  Future<ChaptarrBook> book(int id) => _service.book(id);

  Future<List<ChaptarrBookFile>> files(int id) => _service.files(id);

  Future<List<ChaptarrRelease>> releases(int id) async =>
      (await _service.releases(id)).releases;

  Future<void> grab(int bookId, ChaptarrRelease release) => _service.grab({
    'bookId': bookId,
    'guid': release.guid,
    'indexerId': release.indexerId,
  });

  Future<List<ChaptarrBook>> lookup(String term) =>
      _service.lookup(term.trim());

  Future<List<ChaptarrRoot>> roots(ChaptarrFormat format) async =>
      (await _service.roots())
          .map((root) => root.settings[format])
          .whereType<ChaptarrRoot>()
          .toList();

  Future<int> add(ChaptarrBook book, ChaptarrFormat format, ChaptarrRoot root) {
    final key = (book.foreignBookId, format);
    return _imports.putIfAbsent(
      key,
      () => _import(book, format, root).whenComplete(() {
        _imports.remove(key);
      }),
    );
  }

  Future<int>? pendingImport(ChaptarrBook book, ChaptarrFormat format) =>
      _imports[(book.foreignBookId, format)];

  Future<int> _import(
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
    int? bookId,
  }) async {
    final query = {
      'page': page,
      'pageSize': pageSize,
      'includeBook': true,
      'bookId': ?bookId,
    };
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

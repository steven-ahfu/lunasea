part of 'chaptarr.dart';

typedef ChaptarrResource = Map<String, dynamic>;

Map<int, String> chaptarrProfileNames(
  List<ChaptarrResource> rows,
  ChaptarrFormat format,
) => {
  for (final row in rows)
    if ([
      format.name,
      format.folderType,
      'both',
      0,
      null,
    ].contains(row['profileType']))
      row['id'] as int: row['name'] as String,
};

extension ChaptarrManagement on ChaptarrAPI {
  String get webUrl =>
      Uri.parse(_client.options.baseUrl).resolve('../../').toString();
  Future<void> libraryCommand(String name, {ChaptarrFormat? format}) =>
      _service.command({'name': name, 'mediaType': ?format?.name});
  Future<void> quickImport(String path, String mode) => _service.command({
    'name': 'DownloadedBooksScan',
    'path': path,
    'importMode': mode,
    'requireDefaultRootFolderForMissingAuthors': true,
  });
  Future<ChaptarrResource> matchImport(
    ChaptarrResource row, {
    int? authorId,
    int? bookId,
    int? editionId,
    ChaptarrResource? quality,
  }) async {
    final result = await _client.post<List<dynamic>>(
      'manualimport',
      data: [
        {
          for (final k in [
            'id',
            'path',
            'releaseGroup',
            'indexerFlags',
            'downloadId',
            'additionalFile',
            'disableReleaseSwitching',
            'warnings',
            'suggestedForeignAuthorId',
            'suggestedAuthorName',
            'suggestedForeignBookId',
            'suggestedBookTitle',
            'suggestedForeignEditionId',
            'suggestedEditionTitle',
          ])
            if (row.containsKey(k)) k: row[k],
          'quality': quality ?? row['quality'],
          'authorId': authorId ?? row['author']?['id'],
          'bookId': bookId ?? row['book']?['id'],
          'editionId': editionId ?? row['editionId'],
          'replaceExistingFiles': false,
        },
      ],
    );
    return result.data!.cast<ChaptarrResource>().firstWhere(
      (e) => e['path'] == row['path'],
    );
  }

  Future<ChaptarrResource> _resource(String path) async =>
      (await _client.get<ChaptarrResource>(path)).data!;

  Future<List<ChaptarrResource>> _rows(
    String path, [
    ChaptarrResource? query,
  ]) async => ((await _client.get<List<dynamic>>(
    path,
    queryParameters: query,
  )).data!).cast<ChaptarrResource>();

  Future<ChaptarrResource> bookSettings(int id) => _resource('book/$id');
  Future<List<ChaptarrResource>> editions(int id) =>
      _rows('edition', {'bookId': id});
  Future<void> updateBook(
    int id, {
    bool? monitored,
    bool? anyEditionOk,
    int? editionId,
  }) async {
    // PUT replaces a resource. Merge only the user's edits into a fresh copy.
    final book = await bookSettings(id);
    if (monitored != null) {
      book['monitored'] = monitored;
      final format = ChaptarrFormat.parse(book['mediaType']);
      if (format != null) book['${format.name}Monitored'] = monitored;
    }
    if (anyEditionOk != null) book['anyEditionOk'] = anyEditionOk;
    if (editionId != null) {
      final choices = await editions(id);
      if (!choices.any((e) => e['id'] == editionId)) {
        throw StateError('The selected edition is no longer available.');
      }
      book['editions'] = [
        for (final edition in choices)
          {...edition, 'monitored': edition['id'] == editionId},
      ];
    }
    await _client.put<void>('book/$id', data: book);
  }

  Future<ChaptarrResource> authorSettings(int id) => _resource('author/$id');
  Future<List<ChaptarrResource>> qualityProfiles() => _rows('qualityprofile');
  Future<List<ChaptarrResource>> metadataProfiles() => _rows('metadataprofile');
  Future<List<ChaptarrResource>> rootFolders() => _rows('rootfolder');
  Future<List<ChaptarrResource>> tags() => _rows('tag');

  Future<void> updateAuthor(
    int id,
    ChaptarrResource changes, {
    required ChaptarrFormat format,
    required bool moveFiles,
  }) async {
    final author = await authorSettings(id);
    final policy = '${format.name}MonitorNewItems';
    if (changes.containsKey(policy)) {
      if (author['syncMonitoredAcrossFormats'] == true) {
        author['monitorNewItems'] = changes[policy];
      } else {
        author.remove('monitorNewItems');
      }
    }
    // Chaptarr otherwise fills an explicitly empty format tag list from
    // the legacy combined tags, undoing removals on a dual-format author.
    if (author['${format.name}Tags'] != null ||
        changes.containsKey('${format.name}Tags')) {
      author.remove('tags');
    }
    await _client.put<void>(
      'author/$id',
      data: {...author, ...changes},
      queryParameters: {'mediaType': format.name, 'moveFiles': moveFiles},
    );
  }

  Future<void> refreshBook(int id) async {
    final response = await _client.post<Map>('command', data: {'name': 'RefreshBook', 'bookId': id});
    await waitForRefresh(_client, response.data!);
  }
  Future<void> removeBook(
    int id, {
    required bool deleteFiles,
    required bool exclude,
  }) async {
    await _client.delete<void>(
      'book/$id',
      queryParameters: {
        'deleteFiles': deleteFiles,
        'addImportListExclusion': exclude,
        'applyToBothFormats': false,
      },
    );
  }

  Future<List<ChaptarrResource>> renamePreview(ChaptarrBook book) =>
      _rows('rename', {
        'bookId': book.id,
        'authorId': book.authorId,
        'mediaType': ?book.format?.name,
        'moveToCanonicalAuthorFolder': false,
      });

  Future<void> renameFiles(int authorId, List<int> ids) => _service.command({
    'name': 'RenameFiles',
    'authorId': authorId,
    'files': ids,
    'moveToCanonicalAuthorFolder': false,
  });
  Future<void> removeFile(int id) async => _client.delete<void>('bookfile/$id');

  Future<ChaptarrResource> systemInfo() => _resource('system/status');
  Future<List<ChaptarrResource>> health() => _rows('health');
  Future<List<ChaptarrResource>> disks() => _rows('diskspace');
  Future<void> saveTag(String label, {int? id}) async {
    if (id == null) {
      await _client.post<void>('tag', data: {'label': label});
    } else {
      await _client.put<void>('tag/$id', data: {'id': id, 'label': label});
    }
  }

  Future<void> removeTag(int id) async => _client.delete<void>('tag/$id');
  Future<void> markFailed(int id) async =>
      _client.post<void>('history/failed/$id');
  Future<void> grabQueued(int id) async => _client.post<void>('queue/grab/$id');
  Future<void> removeQueued(
    int id, {
    required bool removeFromClient,
    required bool blocklist,
    required bool skipRedownload,
  }) async => _client.delete<void>(
    'queue/$id',
    queryParameters: {
      'removeFromClient': removeFromClient,
      'blocklist': blocklist,
      'skipRedownload': skipRedownload,
      'changeCategory': false,
    },
  );

  Future<ChaptarrResource> browse(String path) async =>
      (await _client.get<ChaptarrResource>(
        'filesystem',
        queryParameters: {
          'path': path,
          'allowFoldersWithoutTrailingSlashes': true,
        },
      )).data!;
  Future<List<ChaptarrResource>> importPreview({
    String? folder,
    String? downloadId,
    required ChaptarrFormat format,
  }) => _rows('manualimport', {
    'folder': ?folder,
    'downloadId': ?downloadId,
    'mediaType': format.name,
    'filterExistingFiles': true,
    'replaceExistingFiles': false,
  });

  Future<void> importFiles(
    List<ChaptarrResource> files,
    List<ChaptarrResource> preview,
    String mode,
  ) => _service.command({
    'name': 'ManualImport',
    'files': files,
    'previewFiles': preview,
    'importMode': mode,
    'replaceExistingFiles': false,
    'confirmedReplacementFiles': [],
  });
}

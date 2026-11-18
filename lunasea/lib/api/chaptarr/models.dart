enum ChaptarrFormat {
  ebook(2),
  audiobook(1);

  final int folderType;
  const ChaptarrFormat(this.folderType);

  static ChaptarrFormat? parse(Object? value) {
    for (final format in values) {
      if (format.name == value) return format;
    }
    return null;
  }
}

class ChaptarrEdition {
  final int id;
  final String title;
  final String narrator;
  final bool monitored;
  final bool hasFiles;

  const ChaptarrEdition(
    this.id,
    this.title,
    this.narrator,
    this.monitored,
    this.hasFiles,
  );
  factory ChaptarrEdition.fromJson(Map row) => ChaptarrEdition(
    row['id'] as int,
    row['title'] as String? ?? '',
    row['narrator'] as String? ?? '',
    row['monitored'] == true,
    row['hasFiles'] == true,
  );
}

class ChaptarrBook {
  final int? id;
  final String title;
  final String author;
  final String overview;
  final String foreignBookId;
  final String foreignAuthorId;
  final ChaptarrFormat? format;
  final bool monitored;
  final bool hasFiles;
  final String narrator;
  final Map<ChaptarrFormat, List<ChaptarrEdition>> _editions;

  ChaptarrBook.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int?,
      title = json['title'] as String? ?? '',
      author =
          json['author']?['authorName'] as String? ??
          json['authorTitle'] as String? ??
          '',
      overview = json['overview'] as String? ?? '',
      foreignBookId = json['foreignBookId'] as String? ?? '',
      foreignAuthorId = json['author']?['foreignAuthorId'] as String? ?? '',
      format = ChaptarrFormat.parse(json['mediaType']),
      monitored = json['monitored'] == true,
      hasFiles = json['hasFiles'] == true,
      narrator =
          json['narrator'] as String? ??
          (json['narratorNames'] as List?)?.whereType<String>().join(', ') ??
          '',
      _editions = {
        for (final entry in {
          ChaptarrFormat.ebook: json['localEbookBooks'],
          ChaptarrFormat.audiobook: json['localAudiobookBooks'],
        }.entries)
          entry.key: [
            for (final row
                in (entry.value as List? ?? const []).whereType<Map>())
              if (row['id'] is int && row['id'] > 0)
                ChaptarrEdition.fromJson(row),
          ],
      };

  List<ChaptarrEdition> localEditions(ChaptarrFormat selected) {
    final editions = _editions[selected]!;
    if (editions.isNotEmpty || format != selected || (id ?? 0) <= 0)
      return editions;
    return [ChaptarrEdition(id!, title, narrator, monitored, hasFiles)];
  }
}

class ChaptarrRoot {
  final String path;
  final int qualityProfileId;
  final int metadataProfileId;

  const ChaptarrRoot(this.path, this.qualityProfileId, this.metadataProfileId);

  static ChaptarrRoot? forFormat(
    Map<String, dynamic> json,
    ChaptarrFormat format,
  ) {
    final type = json['folderType'];
    if (type != 0 && type != format.folderType) return null;
    final settings = json[format.name];
    final quality =
        settings?['qualityProfileId'] ?? json['${format.name}QualityProfileId'];
    final metadata =
        settings?['metadataProfileId'] ??
        json['${format.name}MetadataProfileId'];
    final path = json['path'];
    if (path is! String ||
        path.isEmpty ||
        quality is! int ||
        quality <= 0 ||
        metadata is! int ||
        metadata <= 0)
      return null;
    return ChaptarrRoot(path, quality, metadata);
  }
}

class ChaptarrEvent {
  final String title;
  final String status;
  final String subtitle;
  final int? bookId;

  ChaptarrEvent.queue(Map<String, dynamic> json)
    : title = json['title'] ?? json['book']?['title'] ?? '',
      status = json['status'] ?? '',
      subtitle = [
        json['downloadClient'],
        json['timeleft'],
        json['errorMessage'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      bookId = json['bookId'];

  ChaptarrEvent.history(Map<String, dynamic> json)
    : title = json['sourceTitle'] ?? json['book']?['title'] ?? '',
      status = json['eventType']?.toString() ?? '',
      subtitle = json['date'] as String? ?? '',
      bookId = json['bookId'];
}

class ChaptarrPage<T> {
  final List<T> records;
  final int total;
  ChaptarrPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) : records = (json['records'] as List)
          .cast<Map<String, dynamic>>()
          .map(parse)
          .toList(),
      total = (json['totalCount'] ?? json['totalRecords']) as int;
}

class ChaptarrStatus {
  final String appName;
  ChaptarrStatus.fromJson(Map<String, dynamic> json)
    : appName = json['appName'] as String;
}

class ChaptarrCreatedBook {
  final int id;
  ChaptarrCreatedBook.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int;
}

class ChaptarrRootFolder {
  final Map<ChaptarrFormat, ChaptarrRoot?> settings;
  ChaptarrRootFolder.fromJson(Map<String, dynamic> json)
    : settings = {
        for (final format in ChaptarrFormat.values)
          format: ChaptarrRoot.forFormat(json, format),
      };
}

class ChaptarrLibraryPage extends ChaptarrPage<ChaptarrBook> {
  ChaptarrLibraryPage.fromJson(Map<String, dynamic> json)
    : super.fromJson(json, ChaptarrBook.fromJson);
}

class ChaptarrQueuePage extends ChaptarrPage<ChaptarrEvent> {
  ChaptarrQueuePage.fromJson(Map<String, dynamic> json)
    : super.fromJson(json, ChaptarrEvent.queue);
}

class ChaptarrHistoryPage extends ChaptarrPage<ChaptarrEvent> {
  ChaptarrHistoryPage.fromJson(Map<String, dynamic> json)
    : super.fromJson(json, ChaptarrEvent.history);
}

class ChaptarrRelease {
  final String guid, title, indexer, protocol, quality, infoUrl;
  final int indexerId, size, weight, score;
  final double ageHours;
  final int? seeders, leechers;
  final bool rejected, canGrab;
  final List<String> reasons, formats;

  ChaptarrRelease.fromJson(Map<String, dynamic> json, {bool hidden = false})
    : guid = json['guid'] as String? ?? '',
      title = json['title'] as String? ?? '',
      indexer = json['indexer'] as String? ?? '',
      protocol = json['protocol'] as String? ?? '',
      quality = json['quality']?['quality']?['name'] as String? ?? '',
      infoUrl = json['infoUrl'] as String? ?? '',
      indexerId = json['indexerId'] as int? ?? 0,
      size = json['size'] as int? ?? 0,
      weight = json['releaseWeight'] as int? ?? 0,
      score = json['customFormatScore'] as int? ?? 0,
      ageHours =
          (json['ageHours'] as num?)?.toDouble() ??
          (json['age'] as num? ?? 0) * 24.0,
      seeders = json['seeders'] as int?,
      leechers = json['leechers'] as int?,
      rejected =
          hidden ||
          json['rejected'] == true ||
          json['temporarilyRejected'] == true,
      canGrab =
          json['downloadAllowed'] != false &&
          json['hasHardFilters'] != true &&
          (json['guid'] as String? ?? '').isNotEmpty &&
          (json['indexerId'] as int? ?? 0) > 0,
      reasons = (json['rejections'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      formats = (json['customFormats'] as List? ?? const [])
          .whereType<Map>()
          .map((f) => f['name'])
          .whereType<String>()
          .toList();
}

class ChaptarrReleaseResults {
  final List<ChaptarrRelease> releases;
  ChaptarrReleaseResults.fromJson(Map<String, dynamic> json)
    : releases = [
        for (final row
            in (json['releases'] as List).cast<Map<String, dynamic>>())
          ChaptarrRelease.fromJson(row),
        for (final row
            in (json['hiddenReleases'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          ChaptarrRelease.fromJson(row, hidden: true),
      ];
}

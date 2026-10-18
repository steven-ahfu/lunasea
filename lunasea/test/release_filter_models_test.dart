import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/api/radarr/models.dart';
import 'package:lunasea/api/sonarr/models.dart';
import 'package:lunasea/modules/radarr/core/extensions/radarr_release.dart';
import 'package:lunasea/modules/radarr/core/types/sorting_releases.dart';
import 'package:lunasea/modules/sonarr/core/extensions/sonarr_release.dart';
import 'package:lunasea/modules/sonarr/core/types/sorting_releases.dart';
import 'package:lunasea/types/release_filters.dart';

void main() {
  Map<String, dynamic> modernRelease() => {
    'title': 'Movie DUAL AUDIO',
    'indexerId': 10,
    'indexer': 'Tracker',
    'quality': {
      'quality': {'id': 7, 'name': 'WEB-DL-1080p', 'resolution': 1080},
    },
    'languages': [
      {'id': 1, 'name': 'English'},
      {'id': 2, 'name': 'French'},
    ],
    'customFormats': [
      {'id': 3, 'name': 'HDR'},
      {'id': 4, 'name': 'Preferred group'},
    ],
  };

  LunaReleaseFilters allFilters() => LunaReleaseFilters(
    selections: {
      LunaReleaseFilter.indexer: {
        LunaReleaseFilterOption.named('Tracker', id: 10),
      },
      LunaReleaseFilter.quality: {
        LunaReleaseFilterOption.named('WEB-DL-1080p', id: 7),
      },
      LunaReleaseFilter.resolution: {LunaReleaseFilterOption.resolution(1080)},
      LunaReleaseFilter.dualAudio: {LunaReleaseFilterOption.dualAudio},
      LunaReleaseFilter.language: {
        LunaReleaseFilterOption.named('French', id: 2),
      },
      LunaReleaseFilter.customFormat: {
        LunaReleaseFilterOption.named('Preferred group', id: 4),
      },
    },
  );

  test('Radarr JSON populates all six filters', () {
    final release = RadarrRelease.fromJson(modernRelease());
    expect(allFilters().matches(release.lunaFilterData), isTrue);
  });

  test('current Sonarr JSON populates all six filters and round-trips', () {
    final release = SonarrRelease.fromJson(modernRelease());
    expect(allFilters().matches(release.lunaFilterData), isTrue);
    final restored = SonarrRelease.fromJson(release.toJson());
    expect(allFilters().matches(restored.lunaFilterData), isTrue);
    expect(restored.languages!.length, 2);
    expect(restored.customFormats!.length, 2);
  });

  test('older Sonarr singular language remains filterable', () {
    final release = SonarrRelease.fromJson({
      'language': {'id': 1, 'name': 'English'},
    });
    final filters = LunaReleaseFilters().withSelection(
      LunaReleaseFilter.language,
      {LunaReleaseFilterOption.named('English', id: 1)},
    );
    expect(filters.matches(release.lunaFilterData), isTrue);
    expect(release.toJson()['language']['name'], 'English');
    expect(release.customFormats, isNull);
  });

  test(
    'empty custom formats differ from omitted metadata in both services',
    () {
      for (final data in [
        RadarrRelease.fromJson({'customFormats': []}).lunaFilterData,
        SonarrRelease.fromJson({'customFormats': []}).lunaFilterData,
      ]) {
        expect(data.optionsFor(LunaReleaseFilter.customFormat), [
          LunaReleaseFilterOption.none,
        ]);
      }
      expect(
        SonarrRelease.fromJson(
          {},
        ).lunaFilterData.optionsFor(LunaReleaseFilter.customFormat),
        [LunaReleaseFilterOption.unknown],
      );
    },
  );

  test('file size and seeders remain ascending and descending sort options', () {
    final radarr = [
      RadarrRelease(size: 100, seeders: 3),
      RadarrRelease(size: 20, seeders: 50),
    ];
    final sonarr = [
      SonarrRelease(size: 100, seeders: 3),
      SonarrRelease(size: 20, seeders: 50),
    ];
    // Seed sorting groups by protocol, so provide torrents for these fixtures.
    for (final release in radarr) {
      release.protocol = RadarrRelease.fromJson({
        'protocol': 'torrent',
      }).protocol;
    }
    for (final release in sonarr) {
      release.protocol = SonarrRelease.fromJson({
        'protocol': 'torrent',
      }).protocol;
    }
    for (final ascending in [true, false]) {
      expect(
        RadarrReleasesSorting.SIZE
            .sort([...radarr], ascending)
            .map((release) => release.size),
        ascending ? [20, 100] : [100, 20],
      );
      expect(
        SonarrReleasesSorting.SIZE
            .sort([...sonarr], ascending)
            .map((release) => release.size),
        ascending ? [20, 100] : [100, 20],
      );
      expect(
        RadarrReleasesSorting.SEEDERS
            .sort([...radarr], ascending)
            .map((release) => release.seeders),
        ascending ? [3, 50] : [50, 3],
      );
      expect(
        SonarrReleasesSorting.SEEDERS
            .sort([...sonarr], ascending)
            .map((release) => release.seeders),
        ascending ? [3, 50] : [50, 3],
      );
    }
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules/sonarr.dart';

void main() {
  test('adding with None clears every season including specials', () async {
    final client = Dio();
    final series = SonarrSeries(seasons: [
      for (final number in [0, 1, 2])
        SonarrSeriesSeason(seasonNumber: number, monitored: true),
    ]);
    client.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.resolve(Response(requestOptions: request, data: request.data));
    }));
    for (final mode in [SonarrSeriesMonitorType.NONE, SonarrSeriesMonitorType.ALL]) {
      final added = await SonarrControllerSeries(client).create(
        series: series,
        seriesType: SonarrSeriesType.STANDARD,
        seasonFolder: true,
        qualityProfile: SonarrQualityProfile(),
        rootFolder: SonarrRootFolder(),
        monitorType: mode,
      );
      final monitored = mode == SonarrSeriesMonitorType.ALL;
      expect(added.monitored, monitored);
      expect(added.seasons!.map((s) => s.monitored), [monitored, monitored, monitored]);
    }
  });

  test('poster lookup skips empty entries and resolves the season cover', () {
    final season = SonarrSeriesSeason(images: [SonarrImage(coverType: 'poster')]);
    expect(season.posterUri('https://example.test/sonarr'), isNull);
    season.images!.add(SonarrImage(coverType: 'poster', url: 'MediaCover/1.jpg'));
    expect(season.posterUri('https://example.test/sonarr').toString(),
        'https://example.test/sonarr/MediaCover/1.jpg');
  });

  test('unmonitored season retains its full episode denominator', () {
    final season = SonarrSeriesSeason(
      monitored: false,
      statistics: SonarrSeriesSeasonStatistics(
        episodeCount: 0,
        totalEpisodeCount: 12,
        episodeFileCount: 3,
      ),
    );
    expect(season.lunaEpisodesAvailable, '3/12');
    expect(season.lunaPercentageComplete, 25);
    season.statistics!.totalEpisodeCount = null;
    season.statistics!.episodeCount = 6;
    expect(season.lunaEpisodesAvailable, '3/6');
  });
}

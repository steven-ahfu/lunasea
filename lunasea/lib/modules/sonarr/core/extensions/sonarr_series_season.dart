import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';

extension SonarrSeriesSeasonExtension on SonarrSeriesSeason {
  Uri? posterUri(String host) {
    final base = Uri.tryParse(host.endsWith('/') ? host : '$host/');
    final urls = (images ?? <SonarrImage>[])
        .where((image) => image.coverType == 'poster')
        .expand((image) => [image.remoteUrl, image.url]);
    for (final value in urls) {
      if (value == null || value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri == null) continue;
      final resolved = base?.resolveUri(uri) ?? uri;
      if (resolved.host.isNotEmpty &&
          (resolved.scheme == 'http' || resolved.scheme == 'https')) {
        return resolved;
      }
    }
    return null;
  }

  String get lunaTitle {
    if (this.seasonNumber == 0) return 'sonarr.Specials'.tr();
    return 'sonarr.SeasonNumber'.tr(args: [
      this.seasonNumber?.toString() ?? 'lunasea.Unknown'.tr(),
    ]);
  }

  int get lunaTotalEpisodeCount =>
      statistics?.totalEpisodeCount ?? statistics?.episodeCount ?? 0;

  int get lunaPercentageComplete {
    int _total = lunaTotalEpisodeCount;
    int _available = this.statistics?.episodeFileCount ?? 0;
    return _total == 0 ? 0 : ((_available / _total) * 100).round();
  }

  String get lunaEpisodesAvailable {
    return '${this.statistics?.episodeFileCount ?? 0}/$lunaTotalEpisodeCount';
  }
}

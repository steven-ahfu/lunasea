import 'package:flutter/material.dart';

import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';
import 'package:lunasea/modules/dashboard/core/api/data/chaptarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/lidarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/radarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/sonarr.dart';

class ContentBlock extends StatelessWidget {
  final CalendarData data;
  const ContentBlock(this.data, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headers = getHeaders();
    final book = data is CalendarChaptarrData
        ? data as CalendarChaptarrData
        : null;
    return LunaBlock(
      title: data.title,
      body: data.body,
      posterHeaders: book?.headers(context, data.posterUrl(context)) ?? headers,
      backgroundHeaders:
          book?.headers(context, data.backgroundUrl(context)) ?? headers,
      posterUrl: data.posterUrl(context),
      posterPlaceholderIcon: book == null
          ? LunaIcons.VIDEO_CAM
          : Icons.menu_book_rounded,
      backgroundUrl: data.backgroundUrl(context),
      trailing: data.trailing(context),
      onTap: () async => data.enterContent(context),
    );
  }

  Map getHeaders() {
    switch (data.runtimeType) {
      case CalendarLidarrData:
        return LunaProfile.current.lidarrHeaders;
      case CalendarRadarrData:
        return LunaProfile.current.radarrHeaders;
      case CalendarSonarrData:
        return LunaProfile.current.sonarrHeaders;
      default:
        return const {};
    }
  }
}

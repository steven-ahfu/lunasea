import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';
import 'package:lunasea/router/routes/chaptarr.dart';

class CalendarChaptarrData extends CalendarData {
  final ChaptarrBook book;
  CalendarChaptarrData(this.book) : super(book.id!, book.title);

  @override
  List<TextSpan> get body => [
    TextSpan(text: book.author),
    TextSpan(text: book.format?.label),
    TextSpan(
      text: (book.hasFiles ? 'chaptarr.Downloaded' : 'radarr.Missing').tr(),
    ),
  ];
  @override
  Future<void> enterContent(BuildContext context) async =>
      ChaptarrRoutes.DETAILS.go(params: {'id': '$id'});
  @override
  Future<void> trailingOnPress(BuildContext context) async {
    final api = context.read<ChaptarrState>().api;
    if (api == null) return;
    try {
      await api.searchReleases(id);
      if (context.mounted)
        showLunaSuccessSnackBar(
          title: 'chaptarr.SearchQueued'.tr(),
          message: title,
        );
    } catch (e) {
      if (context.mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    }
  }

  @override
  Future<void> trailingOnLongPress(BuildContext context) async =>
      ChaptarrRoutes.RELEASES.go(params: {'id': '$id'});
  @override
  Widget trailing(BuildContext context) => LunaIconButton(
    icon: Icons.search_rounded,
    onPressed: () => trailingOnPress(context),
    onLongPress: () => trailingOnLongPress(context),
  );
  @override
  String? posterUrl(BuildContext context) =>
      context.read<ChaptarrState>().api?.bookCover(book);
  @override
  String? backgroundUrl(BuildContext context) =>
      context.read<ChaptarrState>().api?.artworkUrl(book.fanart) ??
      posterUrl(context);
  Map<String, String> headers(BuildContext context, String? url) =>
      context.read<ChaptarrState>().api?.artworkHeaders(url) ?? {};
}

import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/home.dart';
import 'package:lunasea/modules/chaptarr/routes/details.dart';
import 'package:lunasea/modules/chaptarr/routes/lookup.dart';
import 'package:lunasea/modules/chaptarr/routes/add_book.dart';
import 'package:lunasea/modules/chaptarr/routes/paged.dart';
import 'package:lunasea/modules/chaptarr/routes/releases.dart';
import 'package:lunasea/router/routes.dart';

enum ChaptarrRoutes with LunaRoutesMixin {
  HOME('/chaptarr'),
  DETAILS('book/:id'),
  RELEASES('releases'),
  LOOKUP('lookup'),
  ADD('add'),
  QUEUE('queue'),
  HISTORY('history');

  const ChaptarrRoutes(this.path);
  @override
  final String path;
  @override
  LunaModule get module => LunaModule.CHAPTARR;
  @override
  bool isModuleEnabled(BuildContext context) =>
      context.read<ChaptarrState>().enabled;

  @override
  GoRoute get routes => route(
    builder: (context, state) {
      final api = context.watch<ChaptarrState>().api;
      if (this == HOME) return ChaptarrHome(key: ObjectKey(api), api: api);
      if (api == null) return ChaptarrHome(api: null);
      if (this == QUEUE || this == HISTORY) {
        return ChaptarrActivity(
          key: ValueKey((api, this)),
          api: api,
          history: this == HISTORY,
        );
      }
      final format =
          ChaptarrFormat.parse(state.uri.queryParameters['format']) ??
          ChaptarrFormat.ebook;
      if (this == ADD && state.extra is ChaptarrBook) {
        return ChaptarrAddBook(
          key: ValueKey((api, state.extra, format)),
          api: api,
          book: state.extra as ChaptarrBook,
          format: format,
        );
      }
      if (this == LOOKUP || this == ADD)
        return ChaptarrLookup(
          key: ObjectKey(api),
          api: api,
          initialFormat: format,
        );
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null || id <= 0) return ChaptarrHome(api: api);
      if (this == RELEASES)
        return ChaptarrReleases(key: ValueKey((api, id)), api: api, id: id);
      return ChaptarrDetails(key: ValueKey((api, id)), api: api, id: id);
    },
  );

  @override
  List<GoRoute> get subroutes => this == HOME
      ? [
          DETAILS.routes,
          LOOKUP.routes,
          ADD.routes,
          QUEUE.routes,
          HISTORY.routes,
        ]
      : this == DETAILS
      ? [RELEASES.routes]
      : [];
}

import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/home.dart';
import 'package:lunasea/modules/chaptarr/routes/details.dart';
import 'package:lunasea/modules/chaptarr/routes/lookup.dart';
import 'package:lunasea/router/routes.dart';

enum ChaptarrRoutes with LunaRoutesMixin {
  HOME('/chaptarr'),
  DETAILS('book/:id'),
  LOOKUP('lookup');

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
      if (this == LOOKUP)
        return ChaptarrLookup(
          key: ObjectKey(api),
          api: api,
          initialFormat:
              ChaptarrFormat.parse(state.uri.queryParameters['format']) ??
              ChaptarrFormat.ebook,
        );
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null || id <= 0) return ChaptarrHome(api: api);
      return ChaptarrDetails(key: ValueKey((api, id)), api: api, id: id);
    },
  );

  @override
  List<GoRoute> get subroutes =>
      this == HOME ? [DETAILS.routes, LOOKUP.routes] : [];
}

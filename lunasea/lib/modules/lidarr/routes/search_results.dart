import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/lidarr.dart';
import 'package:lunasea/types/release_filters.dart';
import 'package:lunasea/widgets/sheets/download_client/button.dart';

class ArtistAlbumReleasesRoute extends StatefulWidget {
  final int albumId;

  const ArtistAlbumReleasesRoute({Key? key, required this.albumId})
    : super(key: key);

  @override
  State<ArtistAlbumReleasesRoute> createState() => _State();
}

class _State extends State<ArtistAlbumReleasesRoute>
    with LunaScrollControllerMixin, LunaLoadCallbackMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Future<List<LidarrReleaseData>>? _future;
  LunaReleaseFilters _filters = LunaReleaseFilters();

  @override
  Future<void> loadCallback() async {
    final _api = LidarrAPI.from(LunaProfile.current);
    setState(() {
      _future = _api.getReleases(widget.albumId);
    });
    //Clear the search filter using a microtask
    Future.microtask(
      () => context.read<LidarrState>().searchReleasesFilter = '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LidarrReleaseData>>(
      future: _future,
      builder: (context, snapshot) => LunaScaffold(
        scaffoldKey: _scaffoldKey,
        body: _body(snapshot),
        appBar: _appBar(
          snapshot.connectionState == ConnectionState.done
              ? snapshot.data
              : null,
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(List<LidarrReleaseData>? releases) {
    return LunaAppBar(
      title: 'Releases',
      scrollControllers: [scrollController],
      bottom: LidarrReleasesSearchBar(
        scrollController: scrollController,
        releases: releases,
        filters: _filters,
        onFiltersChanged: (filters) => setState(() => _filters = filters),
      ),
      actions: const [DownloadClientButton()],
    );
  }

  Widget _body(AsyncSnapshot<List<LidarrReleaseData>> snapshot) {
    return LunaRefreshIndicator(
      context: context,
      key: _refreshKey,
      onRefresh: loadCallback,
      child: switch (snapshot.connectionState) {
        ConnectionState.done when snapshot.hasData => _list(
          snapshot.requireData,
        ),
        ConnectionState.done => LunaMessage.error(
          onTap: () => _refreshKey.currentState?.show(),
        ),
        _ => const LunaLoader(),
      },
    );
  }

  Widget _list(List<LidarrReleaseData> releases) {
    if (releases.isEmpty)
      return LunaMessage(
        text: 'No Releases Found',
        buttonText: 'Refresh',
        onTap: _refreshKey.currentState?.show,
      );
    return Consumer<LidarrState>(
      builder: (context, state, _) {
        final filtered = _filterAndSort(releases, state);
        if (filtered.isEmpty)
          return LunaListView(
            controller: scrollController,
            children: [
              LunaMessage.inList(text: 'lunasea.ReleaseFilterNoMatches'.tr()),
            ],
          );
        return LunaListViewBuilder(
          controller: scrollController,
          itemCount: filtered.length,
          itemBuilder: (context, index) => LidarrReleasesTile(
            key: ObjectKey(filtered[index]),
            release: filtered[index],
          ),
        );
      },
    );
  }

  List<LidarrReleaseData> _filterAndSort(
    List<LidarrReleaseData> releases,
    LidarrState state,
  ) {
    final query = state.searchReleasesFilter.toLowerCase();
    final filtered = releases.where((release) {
      if (state.hideRejectedReleases && !release.approved) return false;
      if (query.isNotEmpty && !release.title.toLowerCase().contains(query))
        return false;
      return _filters.matches(release.lunaFilterData);
    }).toList();
    return state.sortReleasesType.sort(filtered, state.sortReleasesAscending);
  }
}

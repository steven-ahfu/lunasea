import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/release_tile.dart';
import 'package:lunasea/extensions/scroll_controller.dart';
import 'package:lunasea/types/release_filters.dart';
import 'package:lunasea/widgets/sheets/download_client/button.dart';
import 'package:lunasea/widgets/ui/catalogue_toolbar.dart';
import 'package:lunasea/widgets/ui/release_filters_button.dart';

enum _Approval { all, approved, rejected }

enum _Sort {
  weight('radarr.Weight'),
  age('radarr.Age'),
  size('radarr.Size'),
  seeders('radarr.Seeders'),
  title('chaptarr.Title');

  final String label;
  const _Sort(this.label);
  int compare(ChaptarrRelease a, ChaptarrRelease b) => switch (this) {
    _Sort.weight => a.weight.compareTo(b.weight),
    _Sort.age => a.ageHours.compareTo(b.ageHours),
    _Sort.size => a.size.compareTo(b.size),
    _Sort.seeders => (a.seeders ?? -1).compareTo(b.seeders ?? -1),
    _Sort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  };
}

extension _ReleaseFilters on ChaptarrRelease {
  LunaReleaseFilterData get filterData => LunaReleaseFilterData(
    title: title,
    audioQuality: quality,
    values: {
      LunaReleaseFilter.indexer: [
        LunaReleaseFilterOption.named(indexer, id: indexerId),
      ],
      LunaReleaseFilter.quality: [LunaReleaseFilterOption.named(quality)],
      LunaReleaseFilter.customFormat: formats.isEmpty
          ? [LunaReleaseFilterOption.none]
          : formats.map((f) => LunaReleaseFilterOption.named(f)).toList(),
    },
  );
}

class ChaptarrReleases extends StatefulWidget {
  final ChaptarrAPI api;
  final int id;
  const ChaptarrReleases({super.key, required this.api, required this.id});
  @override
  State<ChaptarrReleases> createState() => _State();
}

class _State extends State<ChaptarrReleases> with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  final query = TextEditingController();
  _Approval approval = _Approval.all;
  _Sort sort = _Sort.weight;
  bool ascending = true;
  LunaReleaseFilters filters = LunaReleaseFilters();
  late Future<List<ChaptarrRelease>> request = widget.api.releases(widget.id);

  Future<void> refresh() async {
    setState(() {
      request = widget.api.releases(widget.id);
    });
    try {
      await request;
    } catch (_) {
      /* The result view renders the retry action. */
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ChaptarrRelease>>(
    future: request,
    builder: (context, snapshot) {
      final releases = snapshot.data ?? const [];
      return LunaScaffold(
        scaffoldKey: scaffold,
        appBar: LunaAppBar(
          title: 'radarr.Releases'.tr(),
          scrollControllers: [scrollController],
          actions: const [DownloadClientButton()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(
              LunaTextInputBar.defaultAppBarHeight,
            ),
            child: Row(
              children: [
                Expanded(
                  child: LunaTextInputBar(
                    controller: query,
                    scrollController: scrollController,
                    onChanged: (_) => setState(() {}),
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  ),
                ),
                LunaReleaseFiltersButton<_Approval>(
                  controller: scrollController,
                  tooltip: 'lunasea.ReleaseFilterTitle'.tr(),
                  approvalOptions: {
                    _Approval.all: 'radarr.All'.tr(),
                    _Approval.approved: 'radarr.Approved'.tr(),
                    _Approval.rejected: 'radarr.Rejected'.tr(),
                  },
                  approval: approval,
                  allApproval: _Approval.all,
                  onApprovalChanged: (v) => setState(() => approval = v),
                  filters: filters,
                  onFiltersChanged: (v) => setState(() => filters = v),
                  availableFilters: const [
                    LunaReleaseFilter.indexer,
                    LunaReleaseFilter.quality,
                    LunaReleaseFilter.audioFormat,
                    LunaReleaseFilter.customFormat,
                  ],
                  releases: snapshot.hasData
                      ? Future.value(releases.map((r) => r.filterData).toList())
                      : null,
                ),
                LunaCatalogueMenu<_Sort>(
                  tooltip: 'sonarr.SortReleases'.tr(),
                  icon: LunaIcons.SORT,
                  margin: const EdgeInsets.fromLTRB(0, 0, 12, 14),
                  selected: sort,
                  ascending: ascending,
                  options: {for (final v in _Sort.values) v: v.label.tr()},
                  onSelected: (value) {
                    setState(() {
                      ascending = sort == value ? !ascending : true;
                      sort = value;
                    });
                    scrollController.animateToStart();
                  },
                ),
              ],
            ),
          ),
        ),
        body: results(snapshot),
      );
    },
  );

  Widget results(AsyncSnapshot<List<ChaptarrRelease>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done)
      return const LunaLoader();
    if (snapshot.hasError) return LunaMessage.error(onTap: refresh);
    final releases = snapshot.requireData;
    if (releases.isEmpty)
      return LunaMessage(
        text: 'sonarr.NoReleasesFound'.tr(),
        buttonText: 'lunasea.Refresh'.tr(),
        onTap: refresh,
      );
    final term = query.text.trim().toLowerCase();
    final rows =
        releases
            .where(
              (r) =>
                  r.title.toLowerCase().contains(term) &&
                  filters.matches(r.filterData) &&
                  (approval == _Approval.all ||
                      (approval == _Approval.rejected) == r.rejected),
            )
            .toList()
          ..sort((a, b) {
            final diff = sort.compare(a, b);
            return diff == 0
                ? a.title.compareTo(b.title)
                : ascending
                ? diff
                : -diff;
          });
    if (rows.isEmpty)
      return LunaMessage(text: 'lunasea.ReleaseFilterNoMatches'.tr());
    return LunaRefreshIndicator(
      context: context,
      onRefresh: refresh,
      child: LunaListViewBuilder(
        controller: scrollController,
        itemCount: rows.length,
        itemBuilder: (_, i) => ChaptarrReleaseTile(
          key: ValueKey((rows[i].indexerId, rows[i].guid)),
          release: rows[i],
          onGrab: () => widget.api.grab(widget.id, rows[i]),
        ),
      ),
    );
  }
}

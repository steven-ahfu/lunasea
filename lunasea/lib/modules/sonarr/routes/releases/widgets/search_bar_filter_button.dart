import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/widgets/ui/release_filters_button.dart';

class SonarrReleasesAppBarFilterButton extends StatefulWidget {
  final ScrollController controller;

  const SonarrReleasesAppBarFilterButton({Key? key, required this.controller})
    : super(key: key);

  @override
  State<SonarrReleasesAppBarFilterButton> createState() => _State();
}

class _State extends State<SonarrReleasesAppBarFilterButton> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SonarrReleasesState>(
      builder: (context, state, _) =>
          LunaReleaseFiltersButton<SonarrReleasesFilter>(
            controller: widget.controller,
            tooltip: 'sonarr.FilterReleases'.tr(),
            approvalOptions: {
              for (final filter in SonarrReleasesFilter.values)
                filter: filter.readable,
            },
            approval: state.filterType,
            allApproval: SonarrReleasesFilter.ALL,
            onApprovalChanged: (value) => state.filterType = value,
            filters: state.filters,
            onFiltersChanged: (value) => state.filters = value,
            releases: state.releases?.then(
              (releases) =>
                  releases.map((release) => release.lunaFilterData).toList(),
            ),
          ),
    );
  }
}

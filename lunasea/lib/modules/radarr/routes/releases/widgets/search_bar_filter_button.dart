import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/widgets/ui/release_filters_button.dart';

class RadarrReleasesAppBarFilterButton extends StatefulWidget {
  final ScrollController controller;

  const RadarrReleasesAppBarFilterButton({Key? key, required this.controller})
    : super(key: key);

  @override
  State<RadarrReleasesAppBarFilterButton> createState() => _State();
}

class _State extends State<RadarrReleasesAppBarFilterButton> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RadarrReleasesState>(
      builder: (context, state, _) =>
          LunaReleaseFiltersButton<RadarrReleasesFilter>(
            controller: widget.controller,
            tooltip: 'lunasea.ReleaseFilterTitle'.tr(),
            approvalOptions: {
              for (final filter in RadarrReleasesFilter.values)
                filter: filter.readable,
            },
            approval: state.filterType,
            allApproval: RadarrReleasesFilter.ALL,
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

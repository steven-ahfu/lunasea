import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/lidarr.dart';
import 'package:lunasea/types/release_filters.dart';
import 'package:lunasea/widgets/ui/release_filters_button.dart';

class LidarrReleasesSearchBar extends StatefulWidget
    implements PreferredSizeWidget {
  final ScrollController scrollController;
  final List<LidarrReleaseData>? releases;
  final LunaReleaseFilters filters;
  final ValueChanged<LunaReleaseFilters> onFiltersChanged;

  const LidarrReleasesSearchBar({
    Key? key,
    required this.scrollController,
    required this.releases,
    required this.filters,
    required this.onFiltersChanged,
  }) : super(key: key);

  @override
  Size get preferredSize =>
      const Size.fromHeight(LunaTextInputBar.defaultAppBarHeight);

  @override
  State<LidarrReleasesSearchBar> createState() => _State();
}

class _State extends State<LidarrReleasesSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectAudioFormat() async {
    const audio = LunaReleaseFilter.audioFormat;
    final releases = widget.releases;
    if (releases == null) return;
    final options = widget.filters.optionsFor(
      audio,
      releases.map((r) => r.lunaFilterData),
    );
    final selected = await showDialog<Set<LunaReleaseFilterOption>>(
      context: context,
      builder: (_) => LunaReleaseFilterDialog(
        title: 'lunasea.ReleaseFilter_audioFormat'.tr(),
        options: options,
        selected: widget.filters.selectedFor(audio),
      ),
    );
    if (!mounted || selected == null) return;
    widget.onFiltersChanged(widget.filters.withSelection(audio, selected));
    if (widget.scrollController.hasClients) widget.scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.filters
        .selectedFor(LunaReleaseFilter.audioFormat)
        .isNotEmpty;
    final releases = widget.releases;
    final canSelect = releases != null && (releases.isNotEmpty || hasSelection);
    return SizedBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Consumer<LidarrState>(
              builder: (context, state, _) => LunaTextInputBar(
                controller: _controller,
                scrollController: widget.scrollController,
                autofocus: false,
                onChanged: (value) =>
                    context.read<LidarrState>().searchReleasesFilter = value,
                margin: LunaTextInputBar.appBarMargin,
              ),
            ),
          ),
          LidarrReleasesHideButton(controller: widget.scrollController),
          LunaCard(
            context: context,
            height: LunaTextInputBar.defaultHeight,
            width: LunaTextInputBar.defaultHeight,
            margin: const EdgeInsets.fromLTRB(0, 0, 12, 14),
            color: Theme.of(context).canvasColor,
            child: IconButton(
              tooltip: 'lunasea.ReleaseFilter_audioFormat'.tr(),
              icon: const Icon(Icons.filter_list_rounded),
              color: hasSelection ? LunaColours.accent : null,
              onPressed: canSelect ? _selectAudioFormat : null,
            ),
          ),
          LidarrReleasesSortButton(controller: widget.scrollController),
        ],
      ),
      height: LunaTextInputBar.defaultAppBarHeight,
    );
  }
}

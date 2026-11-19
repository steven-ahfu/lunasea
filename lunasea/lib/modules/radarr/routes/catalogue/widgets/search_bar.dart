import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/widgets/ui/catalogue_toolbar.dart';
import 'package:lunasea/modules/radarr.dart';

class RadarrCatalogueSearchBar extends StatefulWidget
    implements PreferredSizeWidget {
  final ScrollController scrollController;

  const RadarrCatalogueSearchBar({super.key, required this.scrollController});

  @override
  Size get preferredSize =>
      const Size.fromHeight(LunaTextInputBar.defaultAppBarHeight);

  @override
  State<RadarrCatalogueSearchBar> createState() => _State();
}

class _State extends State<RadarrCatalogueSearchBar> {
  final TextEditingController _controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    _controller.text = context.read<RadarrState>().moviesSearchQuery;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LunaCatalogueToolbar(
    controller: _controller,
    scroll: widget.scrollController,
    onChanged: (value) => context.read<RadarrState>().moviesSearchQuery = value,
    actions: [
      RadarrCatalogueSearchBarFilterButton(controller: widget.scrollController),
      RadarrCatalogueSearchBarSortButton(controller: widget.scrollController),
      RadarrCatalogueSearchBarViewButton(controller: widget.scrollController),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

/// Catalogue search expands into the action area while the keyboard is active.
class LunaCatalogueToolbar extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController scroll;
  final ValueChanged<String> onChanged;
  final List<Widget> actions;
  const LunaCatalogueToolbar({
    super.key,
    required this.controller,
    required this.scroll,
    required this.onChanged,
    required this.actions,
  });

  @override
  State<LunaCatalogueToolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<LunaCatalogueToolbar> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: focus,
    builder: (context, _) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LunaTextInputBar(
            controller: widget.controller,
            scrollController: widget.scroll,
            focusNode: focus,
            onChanged: widget.onChanged,
            margin: EdgeInsets.zero,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(
            milliseconds: LunaUI.ANIMATION_SPEED_SCROLLING,
          ),
          curve: Curves.easeInOutQuart,
          width: focus.hasPrimaryFocus
              ? 0
              : widget.actions.length *
                    (LunaTextInputBar.defaultHeight +
                        LunaUI.DEFAULT_MARGIN_SIZE),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerRight,
              minWidth:
                  widget.actions.length *
                  (LunaTextInputBar.defaultHeight + LunaUI.DEFAULT_MARGIN_SIZE),
              maxWidth:
                  widget.actions.length *
                  (LunaTextInputBar.defaultHeight + LunaUI.DEFAULT_MARGIN_SIZE),
              child: ExcludeFocus(
                excluding: focus.hasPrimaryFocus,
                child: Row(children: widget.actions),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class LunaCatalogueMenu<T> extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final T selected;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;
  final bool? ascending;
  final EdgeInsets margin;
  const LunaCatalogueMenu({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.ascending,
    this.margin = const EdgeInsets.only(left: LunaUI.DEFAULT_MARGIN_SIZE),
  });
  @override
  Widget build(BuildContext context) => LunaCard(
    context: context,
    margin: margin,
    color: Theme.of(context).canvasColor,
    height: LunaTextInputBar.defaultHeight,
    width: LunaTextInputBar.defaultHeight,
    child: LunaPopupMenuButton<T>(
      tooltip: tooltip,
      icon: icon,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem<T>(
            value: entry.key,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: LunaUI.FONT_SIZE_H3,
                    color: selected == entry.key
                        ? LunaColours.accent
                        : Colors.white,
                  ),
                ),
                if (ascending != null && selected == entry.key)
                  Icon(
                    ascending!
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: LunaUI.FONT_SIZE_H2,
                    color: LunaColours.accent,
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

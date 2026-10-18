import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lunasea/system/logger.dart';
import 'package:lunasea/types/release_filters.dart';
import 'package:lunasea/widgets/ui.dart';

enum _ReleaseFilterAction { clear }

class LunaReleaseFiltersButton<T extends Object> extends StatelessWidget {
  final ScrollController controller;
  final String tooltip;
  final Map<T, String> approvalOptions;
  final T approval;
  final T allApproval;
  final ValueChanged<T> onApprovalChanged;
  final LunaReleaseFilters filters;
  final ValueChanged<LunaReleaseFilters> onFiltersChanged;
  final Future<List<LunaReleaseFilterData>>? releases;

  const LunaReleaseFiltersButton({
    super.key,
    required this.controller,
    required this.tooltip,
    required this.approvalOptions,
    required this.approval,
    required this.allApproval,
    required this.onApprovalChanged,
    required this.filters,
    required this.onFiltersChanged,
    required this.releases,
  });

  String _label(LunaReleaseFilter filter) =>
      'lunasea.ReleaseFilter_${filter.name}'.tr();

  String _summary(LunaReleaseFilter filter) {
    final selected = filters.selectedFor(filter);
    if (selected.isEmpty) return 'lunasea.ReleaseFilterAny'.tr();
    if (filter == LunaReleaseFilter.dualAudio) {
      return 'lunasea.ReleaseFilterDualAudioOnly'.tr();
    }
    if (selected.length == 1) return _optionLabel(selected.single);
    return 'lunasea.ReleaseFilterSelected'.tr(args: ['${selected.length}']);
  }

  Future<void> _onSelected(BuildContext context, Object result) async {
    if (result == _ReleaseFilterAction.clear) {
      onFiltersChanged(LunaReleaseFilters());
      onApprovalChanged(allApproval);
    } else if (result is LunaReleaseFilter) {
      List<LunaReleaseFilterData> data;
      try {
        data = await releases ?? [];
      } catch (error, stack) {
        LunaLogger().error(
          'Unable to load release filter options',
          error,
          stack,
        );
        if (!context.mounted) return;
        await LunaDialog.dialog(
          context: context,
          title: tooltip,
          contentPadding: LunaDialog.textDialogContentPadding(),
          content: [
            LunaDialog.textContent(text: 'lunasea.AnErrorHasOccurred'.tr()),
          ],
        );
        return;
      }
      if (!context.mounted) return;
      final selected = await showDialog<Set<LunaReleaseFilterOption>>(
        context: context,
        builder: (_) => _ReleaseFilterDialog(
          title: _label(result),
          options: filters.optionsFor(result, data),
          selected: filters.selectedFor(result),
        ),
      );
      if (selected == null || !context.mounted) return;
      onFiltersChanged(filters.withSelection(result, selected));
    } else {
      onApprovalChanged(result as T);
    }
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(
          milliseconds: LunaUI.ANIMATION_SPEED_SCROLLING,
        ),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = filters.activeCount + (approval == allApproval ? 0 : 1);
    return LunaCard(
      context: context,
      child: LunaPopupMenuButton<Object>(
        tooltip: tooltip,
        child: SizedBox(
          width: LunaTextInputBar.defaultHeight,
          height: LunaTextInputBar.defaultHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.filter_list_rounded),
              if (activeCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: LunaColours.accent,
                      fontSize: LunaUI.FONT_SIZE_H5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        onSelected: (result) => _onSelected(context, result),
        itemBuilder: (_) => [
          for (final entry in approvalOptions.entries)
            PopupMenuItem<Object>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: LunaUI.FONT_SIZE_H3,
                  color: approval == entry.key
                      ? LunaColours.accent
                      : Colors.white,
                ),
              ),
            ),
          const PopupMenuDivider(),
          for (final filter in LunaReleaseFilter.values)
            PopupMenuItem<Object>(
              value: filter,
              enabled: releases != null,
              child: Text(
                '${_label(filter)}: ${_summary(filter)}',
                style: TextStyle(
                  fontSize: LunaUI.FONT_SIZE_H3,
                  color: filters.selectedFor(filter).isEmpty
                      ? Colors.white
                      : LunaColours.accent,
                ),
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<Object>(
            value: _ReleaseFilterAction.clear,
            child: Text(
              'lunasea.ReleaseFilterClearAll'.tr(),
              style: const TextStyle(fontSize: LunaUI.FONT_SIZE_H3),
            ),
          ),
        ],
      ),
      height: LunaTextInputBar.defaultHeight,
      width: LunaTextInputBar.defaultHeight,
      margin: const EdgeInsets.fromLTRB(0.0, 0.0, 12.0, 14.0),
      color: Theme.of(context).canvasColor,
    );
  }
}

String _optionLabel(LunaReleaseFilterOption option) {
  if (option == LunaReleaseFilterOption.none) {
    return 'lunasea.ReleaseFilterNoCustomFormats'.tr();
  }
  if (option == LunaReleaseFilterOption.dualAudio) {
    return 'lunasea.ReleaseFilterDualAudioOnly'.tr();
  }
  return option.label.isEmpty ? 'lunasea.Unknown'.tr() : option.label;
}

class _ReleaseFilterDialog extends StatefulWidget {
  final String title;
  final List<LunaReleaseFilterOption> options;
  final Set<LunaReleaseFilterOption> selected;

  const _ReleaseFilterDialog({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  State<_ReleaseFilterDialog> createState() => _ReleaseFilterDialogState();
}

class _ReleaseFilterDialogState extends State<_ReleaseFilterDialog> {
  late final Set<LunaReleaseFilterOption> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.options.where(
      (option) =>
          _optionLabel(option).toLowerCase().contains(_query.toLowerCase()),
    );
    final showSearch = widget.options.length > 8;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return AlertDialog(
      title: LunaDialog.title(text: widget.title),
      shape: LunaUI.shapeBorder,
      contentPadding: LunaDialog.listDialogContentPadding(),
      content: SizedBox(
        width: 360,
        height: min(
          widget.options.length * 64.0 + (showSearch ? 64 : 0),
          availableHeight * 0.45,
        ),
        child: Column(
          children: [
            if (showSearch)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    labelText: 'lunasea.ReleaseFilterSearch'.tr(),
                    labelStyle: const TextStyle(color: LunaColours.grey),
                  ),
                  style: const TextStyle(fontSize: LunaDialog.BODY_SIZE),
                ),
              ),
            Expanded(
              child: options.isEmpty
                  ? Center(child: Text('lunasea.ReleaseFilterNoOptions'.tr()))
                  : ListView(
                      children: [
                        for (final option in options)
                          LunaDialog.checkbox(
                            title: _optionLabel(option),
                            value: _selected.contains(option),
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _selected.add(option);
                              } else {
                                _selected.remove(option);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        LunaDialog.cancel(context),
        LunaDialog.button(
          text: 'lunasea.Clear'.tr(),
          onPressed: () => setState(_selected.clear),
        ),
        LunaDialog.button(
          text: 'lunasea.ReleaseFilterApply'.tr(),
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

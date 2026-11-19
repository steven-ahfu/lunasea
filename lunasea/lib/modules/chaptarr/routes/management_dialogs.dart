import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

Future<T?> chaptarrChoice<T>(
  BuildContext context,
  String title,
  Map<T, String> options, {
  T? current,
}) async {
  T? selected;
  await LunaDialog.dialog(
    context: context,
    title: title,
    contentPadding: LunaDialog.listDialogContentPadding(),
    content: [
      for (final option in options.entries)
        LunaDialog.tile(
          text: option.value,
          icon: option.key == current
              ? Icons.check_rounded
              : Icons.chevron_right_rounded,
          onTap: () {
            selected = option.key;
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
    ],
  );
  return selected;
}

Future<Set<String>?> chaptarrConfirm(
  BuildContext context,
  String title,
  String message, {
  Map<String, String> options = const {},
  Set<String> initial = const {},
  String? action,
}) async {
  final selected = {...initial};
  bool confirmed = false;
  await LunaDialog.dialog(
    context: context,
    title: title,
    contentPadding: LunaDialog.listDialogContentPadding(),
    content: [
      if (message.isNotEmpty) LunaDialog.textContent(text: message),
      for (final option in options.entries)
        StatefulBuilder(
          builder: (_, rebuild) => CheckboxListTile(
            title: Text(option.value),
            value: selected.contains(option.key),
            onChanged: (value) => rebuild(() {
              if (value == true) {
                selected.add(option.key);
              } else {
                selected.remove(option.key);
              }
            }),
          ),
        ),
    ],
    buttons: [
      LunaDialog.button(
        text: action ?? title,
        onPressed: () {
          confirmed = true;
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    ],
  );
  return confirmed ? selected : null;
}

Widget chaptarrSetting(String title, String value, VoidCallback? onTap) =>
    LunaBlock(
      title: title,
      body: [TextSpan(text: value.isEmpty ? LunaUI.TEXT_EMDASH : value)],
      trailing: onTap == null ? null : const LunaIconButton.arrow(),
      onTap: onTap,
    );

String editionLabel(Map<String, dynamic> edition) => [
  edition['title'],
  edition['language'],
  edition['publisher'],
  edition['format'],
  edition['narrator'],
  edition['isbn13'] ?? edition['foreignEditionId'],
].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

enum ChaptarrBookChange { updated, monitoring, removed }

Future<ChaptarrBookChange?> showBookActions(
  BuildContext context,
  ChaptarrAPI api,
  ChaptarrBook book,
) async {
  final id = book.id;
  if (id == null) return null;
  final action = await chaptarrChoice(context, book.title, {
    'edit': 'chaptarr.EditBook'.tr(),
    'monitor':
        (book.monitored ? 'chaptarr.UnmonitorBook' : 'chaptarr.MonitorBook')
            .tr(),
    'refresh': 'chaptarr.RefreshBook'.tr(),
    if (book.authorId != null) 'rename': 'chaptarr.RenameFiles'.tr(),
    'delete': 'chaptarr.DeleteBook'.tr(),
  });
  if (!context.mounted || action == null) return null;
  try {
    switch (action) {
      case 'edit':
        await context.push('/chaptarr/book/$id/edit');
      case 'monitor':
        final monitored = !book.monitored;
        await api.setMonitored(id, monitored);
        book.monitored = monitored;
        return ChaptarrBookChange.monitoring;
      case 'refresh':
        await api.refreshBook(id);
        if (context.mounted)
          showLunaSuccessSnackBar(
            title: 'chaptarr.RefreshBook'.tr(),
            message: book.title,
          );
      case 'rename':
        final rows = await api.renamePreview(book);
        if (!context.mounted) return null;
        final options = {
          for (final row in rows)
            if (row['canOrganize'] != false && row['bookFileId'] is int)
              '${row['bookFileId']}':
                  "${row['existingPath']} → ${row['newPath']}",
        };
        if (options.isEmpty) {
          await LunaDialogs().textPreview(
            context,
            'chaptarr.RenameFiles'.tr(),
            'chaptarr.NoRenames'.tr(),
          );
          return null;
        }
        final ids = await chaptarrConfirm(
          context,
          'chaptarr.RenameFiles'.tr(),
          '',
          options: options,
          initial: options.keys.toSet(),
        );
        if (ids == null || ids.isEmpty) return null;
        await api.renameFiles(book.authorId!, ids.map(int.parse).toList());
      case 'delete':
        final selected = await chaptarrConfirm(
          context,
          'chaptarr.DeleteBook'.tr(),
          book.title,
          options: {
            'files': 'chaptarr.DeleteBookFiles'.tr(),
            'exclude': 'chaptarr.ExcludeBook'.tr(),
          },
        );
        if (selected == null) return null;
        await api.removeBook(
          id,
          deleteFiles: selected.contains('files'),
          exclude: selected.contains('exclude'),
        );
        return ChaptarrBookChange.removed;
    }
    return ChaptarrBookChange.updated;
  } catch (e) {
    if (context.mounted)
      showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    return null;
  }
}

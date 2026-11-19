import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrSystem extends StatefulWidget {
  final ChaptarrAPI api;
  final bool tags;
  const ChaptarrSystem({super.key, required this.api, this.tags = false});
  @override
  State<ChaptarrSystem> createState() => _SystemState();
}

class _SystemState extends State<ChaptarrSystem>
    with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  late Future<List<Widget>> request = load();
  bool busy = false;

  Future<List<Widget>> load() async {
    if (widget.tags) {
      final rows = await widget.api.tags();
      return [
        if (rows.isEmpty) LunaMessage.inList(text: 'radarr.NoTagsFound'.tr()),
        for (final tag in rows)
          LunaBlock(
            title: tag['label'],
            trailing: const LunaIconButton.arrow(),
            onTap: () => manage(tag),
          ),
      ];
    }
    final (info, health, disks, roots) = await (
      widget.api.systemInfo(),
      widget.api.health(),
      widget.api.disks(),
      widget.api.rootFolders(),
    ).wait;
    return [
      LunaHeader(text: 'chaptarr.Server'.tr()),
      LunaBlock(
        title: info['instanceName'] ?? info['appName'],
        body: [
          TextSpan(
            text: [
              info['version'],
              info['branch'],
            ].whereType<String>().join(' · '),
          ),
          TextSpan(
            text: [
              info['osName'],
              info['osVersion'],
            ].whereType<String>().join(' '),
          ),
        ],
      ),
      LunaHeader(text: 'chaptarr.Health'.tr()),
      if (health.isEmpty) LunaBlock(title: 'chaptarr.Healthy'.tr()),
      for (final row in health)
        LunaBlock(
          title: row['message'],
          body: [TextSpan(text: row['type'])],
          onTap: () =>
              LunaDialogs().textPreview(context, row['source'], row['message']),
        ),
      LunaHeader(text: 'radarr.Disks'.tr()),
      for (final row in disks)
        LunaBlock(
          title: row['path'],
          body: [
            TextSpan(
              text: 'chaptarr.FreeSpace'.tr(
                args: [
                  (row['freeSpace'] as int).asBytes(),
                  (row['totalSpace'] as int).asBytes(),
                ],
              ),
            ),
          ],
        ),
      LunaHeader(text: 'radarr.RootFolders'.tr()),
      for (final row in roots)
        LunaBlock(
          title: row['path'],
          body: [TextSpan(text: row['name'])],
        ),
    ];
  }

  Future<void> refresh() async {
    setState(() => request = load());
    try {
      await request;
    } catch (_) {
      /* Retry is offered by FutureBuilder. */
    }
  }

  Future<void> manage([ChaptarrResource? tag]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final choice = tag == null
          ? 'edit'
          : await chaptarrChoice(context, tag['label'], {
              'edit': 'chaptarr.RenameTag'.tr(),
              'delete': 'chaptarr.DeleteTag'.tr(),
            });
      if (!mounted || choice == null) return;
      if (choice == 'edit') {
        final answer = await LunaDialogs().editText(
          context,
          (tag == null ? 'chaptarr.AddTag' : 'chaptarr.RenameTag').tr(),
          prefill: tag?['label'] ?? '',
        );
        if (!answer.item1 || answer.item2.trim().isEmpty) return;
        await widget.api.saveTag(answer.item2.trim(), id: tag?['id']);
      } else {
        if (await chaptarrConfirm(
              context,
              'chaptarr.DeleteTag'.tr(),
              tag!['label'],
            ) ==
            null)
          return;
        await widget.api.removeTag(tag['id']);
      }
      if (mounted) await refresh();
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: scaffold,
    appBar: LunaAppBar(
      title: (widget.tags ? 'radarr.Tags' : 'radarr.SystemStatus').tr(),
      actions: [
        if (widget.tags)
          LunaIconButton.appBar(
            icon: Icons.add_rounded,
            onPressed: busy ? null : () => manage(),
          ),
      ],
      scrollControllers: [scrollController],
    ),
    body: FutureBuilder<List<Widget>>(
      future: request,
      builder: (_, snapshot) {
        if (snapshot.hasError) return LunaMessage.error(onTap: refresh);
        if (!snapshot.hasData) return const LunaLoader();
        return LunaRefreshIndicator(
          context: context,
          onRefresh: refresh,
          child: LunaListView(
            controller: scrollController,
            children: snapshot.requireData,
          ),
        );
      },
    ),
  );
}

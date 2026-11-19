import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/double/time.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/modules/chaptarr.dart';

class ChaptarrReleaseTile extends StatefulWidget {
  final ChaptarrRelease release;
  final Future<void> Function() onGrab;
  const ChaptarrReleaseTile({
    super.key,
    required this.release,
    required this.onGrab,
  });
  @override
  State<ChaptarrReleaseTile> createState() => _State();
}

class _State extends State<ChaptarrReleaseTile> {
  LunaLoadingState loading = LunaLoadingState.INACTIVE;
  Future<void> grab() async {
    if (loading == LunaLoadingState.ACTIVE || !widget.release.canGrab) return;
    setState(() => loading = LunaLoadingState.ACTIVE);
    try {
      await widget.onGrab();
      if (!mounted) return;
      setState(() => loading = LunaLoadingState.INACTIVE);
      showLunaSuccessSnackBar(
        title: 'sonarr.DownloadingRelease'.tr(),
        message: widget.release.title,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = LunaLoadingState.ERROR);
      showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    }
  }

  void warnings() =>
      LunaDialogs().showRejections(context, widget.release.reasons);
  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final torrent = r.protocol.toLowerCase() == 'torrent';
    final protocol = torrent
        ? 'Torrent'
        : r.protocol.toLowerCase() == 'usenet'
        ? 'Usenet'
        : r.protocol;
    final color = !torrent
        ? LunaColours.accent
        : (r.seeders ?? 0) > 10
        ? LunaColours.blue
        : (r.seeders ?? 0) > 0
        ? LunaColours.orange
        : LunaColours.red;
    final showWarning = r.rejected || !r.canGrab;
    final info = Uri.tryParse(r.infoUrl);
    return LunaExpandableListTile(
      title: r.title,
      collapsedSubtitles: [
        TextSpan(
          children: [
            TextSpan(
              text: torrent
                  ? '$protocol (${r.seeders ?? 0}/${r.leechers ?? 0})'
                  : protocol,
              style: TextStyle(
                color: color,
                fontWeight: LunaUI.FONT_WEIGHT_BOLD,
              ),
            ),
            TextSpan(text: ' · ${r.indexer} · ${r.ageHours.asTimeAgo()}'),
          ],
        ),
        TextSpan(text: '${r.quality} · ${r.size.asBytes()}'),
      ],
      collapsedTrailing: LunaIconButton(
        icon: showWarning ? Icons.report_outlined : Icons.download_rounded,
        color: showWarning ? LunaColours.red : Colors.white,
        loadingState: loading,
        onPressed: showWarning ? warnings : grab,
        onLongPress: r.canGrab ? grab : null,
      ),
      expandedHighlightedNodes: [
        LunaHighlightedNode(text: protocol, backgroundColor: color),
        if (r.score != 0)
          LunaHighlightedNode(
            text: '${r.score > 0 ? '+' : ''}${r.score}',
            backgroundColor: LunaColours.purple,
          ),
        for (final name in r.formats)
          LunaHighlightedNode(
            text: name,
            backgroundColor: LunaColours.blueGrey,
          ),
      ],
      expandedTableContent: [
        LunaTableContent(title: 'age', body: r.ageHours.asTimeAgo()),
        LunaTableContent(title: 'indexer', body: r.indexer),
        LunaTableContent(title: 'size', body: r.size.asBytes()),
        LunaTableContent(title: 'quality', body: r.quality),
        if (r.seeders != null)
          LunaTableContent(title: 'seeders', body: '${r.seeders}'),
        if (r.leechers != null)
          LunaTableContent(title: 'leechers', body: '${r.leechers}'),
      ],
      expandedTableButtons: [
        if (r.canGrab)
          LunaButton(
            type: LunaButtonType.TEXT,
            text: 'search.Download'.tr(),
            icon: Icons.download_rounded,
            loadingState: loading,
            onTap: grab,
          ),
        if (info != null && ['https', 'http'].contains(info.scheme))
          LunaButton.text(
            text: 'Indexer',
            icon: Icons.info_outline_rounded,
            color: LunaColours.blue,
            onTap: r.infoUrl.openLink,
          ),
        if (showWarning)
          LunaButton.text(
            text: 'radarr.Rejected'.tr(),
            icon: Icons.report_outlined,
            color: LunaColours.red,
            onTap: warnings,
          ),
      ],
    );
  }
}

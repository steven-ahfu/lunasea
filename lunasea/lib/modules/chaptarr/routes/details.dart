import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';

class ChaptarrDetails extends StatefulWidget {
  final ChaptarrAPI api;
  final int id;
  const ChaptarrDetails({super.key, required this.api, required this.id});
  @override
  State<ChaptarrDetails> createState() => _DetailsState();
}

class _DetailsState extends State<ChaptarrDetails> {
  final scaffold = GlobalKey<ScaffoldState>();
  late Future<ChaptarrBook> request = widget.api.book(widget.id);
  bool busy = false;

  Future<void> act(
    Future<void> Function() action, {
    bool search = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      if (search) {
        showLunaSuccessSnackBar(
          title: 'chaptarr.SearchQueued'.tr(),
          message: '',
        );
      } else {
        setState(() => request = widget.api.book(widget.id));
      }
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
    appBar: LunaAppBar(title: 'chaptarr.BookDetails'.tr()),
    body: FutureBuilder<ChaptarrBook>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return LunaMessage.error(
            onTap: () => setState(() => request = widget.api.book(widget.id)),
          );
        final b = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(b.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              [
                b.author,
                if (b.format != null)
                  (b.format == ChaptarrFormat.ebook
                          ? 'chaptarr.Ebook'
                          : 'chaptarr.Audiobook')
                      .tr(),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
            if (b.narrator.isNotEmpty)
              Text('chaptarr.NarratedBy'.tr(args: [b.narrator])),
            if (b.overview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(b.overview),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('chaptarr.Monitored'.tr()),
              value: b.monitored,
              onChanged: busy
                  ? null
                  : (value) =>
                        act(() => widget.api.setMonitored(widget.id, value)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text('chaptarr.SearchReleases'.tr()),
              onTap: busy
                  ? null
                  : () => act(
                      () => widget.api.searchReleases(widget.id),
                      search: true,
                    ),
            ),
          ],
        );
      },
    ),
  );
}

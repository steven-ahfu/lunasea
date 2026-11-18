import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';

class ChaptarrLookup extends StatefulWidget {
  final ChaptarrAPI api;
  final ChaptarrFormat initialFormat;
  const ChaptarrLookup({
    super.key,
    required this.api,
    required this.initialFormat,
  });
  @override
  State<ChaptarrLookup> createState() => _LookupState();
}

class _LookupState extends State<ChaptarrLookup> {
  final scaffold = GlobalKey<ScaffoldState>();
  final query = TextEditingController();
  late ChaptarrFormat format = widget.initialFormat;
  Future<List<ChaptarrBook>>? request;
  String lastQuery = '';
  bool choosing = false;
  final added = <(String, ChaptarrFormat), int>{};

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void search(String text) {
    lastQuery = text.trim();
    setState(
      () => request = lastQuery.isEmpty ? null : widget.api.lookup(lastQuery),
    );
  }

  Future<void> choose(ChaptarrBook book) async {
    if (choosing) return;
    final selected = format;
    final key = (book.foreignBookId, selected);
    setState(() => choosing = true);
    try {
      int? id = added[key];
      final editions = book.localEditions(selected);
      if (id == null && editions.isNotEmpty) {
        id = editions.length == 1
            ? editions.single.id
            : await showDialog<int>(
                context: context,
                builder: (dialog) => SimpleDialog(
                  title: Text('chaptarr.ChooseEdition'.tr()),
                  children: [
                    for (final edition in editions)
                      ListTile(
                        title: Text(edition.title),
                        subtitle: Text(
                          [
                            if (edition.narrator.isNotEmpty) edition.narrator,
                            if (edition.hasFiles) 'chaptarr.Downloaded'.tr(),
                            (edition.monitored
                                    ? 'chaptarr.Monitored'
                                    : 'chaptarr.Unmonitored')
                                .tr(),
                            '#${edition.id}',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.pop(dialog, edition.id),
                      ),
                  ],
                ),
              );
        if (id == null || !mounted) return;
      }
      if (id != null) {
        await context.push('/chaptarr/book/$id');
        return;
      }
      final roots = await widget.api.roots(selected);
      if (!mounted) return;
      if (roots.isEmpty) {
        showLunaInfoSnackBar(
          title: 'chaptarr.NoRoot'.tr(),
          message: 'chaptarr.ConfigureRoot'.tr(),
        );
        return;
      }
      final root = await showDialog<ChaptarrRoot>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(
            'chaptarr.AddFormat'.tr(args: [book.title, selected.label]),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('chaptarr.SelectRoot'.tr()),
            ),
            for (final root in roots)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, root),
                child: Text(root.path),
              ),
          ],
        ),
      );
      if (root == null || !mounted) return;
      final newId = await widget.api.add(book, selected, root);
      if (!mounted) return;
      setState(() => added[key] = newId);
      showLunaSuccessSnackBar(
        title: 'chaptarr.BookAdded'.tr(),
        message: book.title,
      );
    } catch (e) {
      if (mounted)
        showLunaErrorSnackBar(title: 'chaptarr.ActionFailed'.tr(), error: e);
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: scaffold,
    appBar: LunaAppBar(title: 'chaptarr.FindBook'.tr()),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'chaptarr.SearchTitle'.tr(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'chaptarr.FindBook'.tr(),
                onPressed: () => search(query.text),
              ),
            ),
            onSubmitted: search,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<ChaptarrFormat>(
            segments: [
              for (final type in ChaptarrFormat.values)
                ButtonSegment(value: type, label: Text(type.label)),
            ],
            selected: {format},
            onSelectionChanged: choosing
                ? null
                : (s) => setState(() => format = s.single),
          ),
        ),
        if (choosing) const LinearProgressIndicator(),
        if (request != null)
          Expanded(
            child: FutureBuilder<List<ChaptarrBook>>(
              future: request,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return LunaMessage.error(onTap: () => search(lastQuery));
                final books = snapshot.requireData;
                if (books.isEmpty)
                  return LunaMessage(text: 'chaptarr.NoResults'.tr());
                return ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final inLibrary =
                        added.containsKey((book.foreignBookId, format)) ||
                        book.localEditions(format).isNotEmpty;
                    return LunaBlock(
                      title: book.title,
                      body: [TextSpan(text: book.author)],
                      trailing: Icon(
                        inLibrary ? Icons.check : Icons.add,
                        semanticLabel:
                            (inLibrary
                                    ? 'chaptarr.InLibrary'
                                    : 'chaptarr.AddBook')
                                .tr(),
                      ),
                      onTap:
                          choosing ||
                              (!inLibrary &&
                                  (book.foreignAuthorId.isEmpty ||
                                      book.foreignBookId.isEmpty))
                          ? null
                          : () => choose(book),
                    );
                  },
                );
              },
            ),
          ),
      ],
    ),
  );
}

extension ChaptarrFormatLabel on ChaptarrFormat {
  String get label =>
      (this == ChaptarrFormat.ebook ? 'chaptarr.Ebook' : 'chaptarr.Audiobook')
          .tr();
}

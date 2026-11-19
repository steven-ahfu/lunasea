import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';

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

class _LookupState extends State<ChaptarrLookup>
    with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  final query = TextEditingController();
  late ChaptarrFormat format = widget.initialFormat;
  Timer? debounce;
  Future<List<ChaptarrBook>>? request;
  String lastQuery = '';

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void search(String text, {bool refresh = false}) {
    debounce?.cancel();
    final term = text.trim();
    if (!refresh && term == lastQuery) return;
    lastQuery = term;
    final next = term.isEmpty ? null : widget.api.lookup(term);
    setState(() {
      request = next;
    });
  }

  void changed(String text) {
    debounce?.cancel();
    if (text.trim().isEmpty) {
      search('');
      return;
    }
    debounce = Timer(const Duration(milliseconds: 500), () => search(text));
  }

  Future<void> choose(ChaptarrBook book) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = format;
    final editions = book.localEditions(selected);
    if (editions.isNotEmpty) {
      final id = editions.length == 1
          ? editions.single.id
          : await showDialog<int>(
              context: context,
              builder: (dialog) => SimpleDialog(
                title: Text('chaptarr.ChooseEdition'.tr()),
                children: [
                  for (final edition in editions)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialog, edition.id),
                      child: Text(
                        [
                          edition.title,
                          if (edition.narrator.isNotEmpty) edition.narrator,
                          (edition.hasFiles
                                  ? 'chaptarr.Downloaded'
                                  : edition.monitored
                                  ? 'chaptarr.Monitored'
                                  : 'chaptarr.Unmonitored')
                              .tr(),
                          '#${edition.id}',
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
            );
      if (id == null || !mounted) return;
      await context.push('/chaptarr/book/$id');
    } else {
      await context.push('/chaptarr/add?format=${selected.name}', extra: book);
      if (!mounted) return;
      final pending = widget.api.pendingImport(book, selected);
      if (pending != null) {
        try {
          await pending;
        } catch (_) {
          /* Refresh actual library membership. */
        }
      }
    }
    if (mounted) search(query.text, refresh: true);
  }

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: scaffold,
    appBar: LunaAppBar(
      title: 'chaptarr.AddBook'.tr(),
      actions: [
        ChaptarrFormatMenu(
          value: format,
          onChanged: (value) => setState(() => format = value),
        ),
      ],
    ),
    body: Column(
      children: [
        LunaTextInputBar(
          controller: query,
          autofocus: true,
          labelText: 'chaptarr.SearchTitle'.tr(),
          onChanged: changed,
          onSubmitted: search,
        ),
        if (request != null)
          Expanded(
            child: FutureBuilder<List<ChaptarrBook>>(
              future: request,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const LunaLoader();
                if (snapshot.hasError)
                  return LunaMessage.error(
                    onTap: () => search(query.text, refresh: true),
                  );
                final books = snapshot.requireData;
                if (books.isEmpty)
                  return LunaMessage(text: 'chaptarr.NoResults'.tr());
                return LunaListViewBuilder(
                  controller: scrollController,
                  itemCount: books.length,
                  itemBuilder: (_, i) {
                    final book = books[i];
                    final local = book.localEditions(format).isNotEmpty;
                    return ChaptarrBookTile(
                      api: widget.api,
                      book: book,
                      format: format,
                      lookup: true,
                      trailing: LunaIconButton(
                        icon: local ? Icons.check_rounded : Icons.add_rounded,
                        color: local ? LunaColours.accent : LunaColours.white,
                      ),
                      onTap: () => choose(book),
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

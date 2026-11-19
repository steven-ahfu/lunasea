import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/modules/chaptarr/routes/book_tile.dart';
import 'package:lunasea/modules/chaptarr/routes/management_dialogs.dart';

class ChaptarrAddBook extends StatefulWidget {
  final ChaptarrAPI api;
  final ChaptarrBook book;
  final ChaptarrFormat format;
  const ChaptarrAddBook({
    super.key,
    required this.api,
    required this.book,
    required this.format,
  });

  @override
  State<ChaptarrAddBook> createState() => _AddState();
}

class _AddState extends State<ChaptarrAddBook> with LunaScrollControllerMixin {
  final scaffold = GlobalKey<ScaffoldState>();
  late Future<List<ChaptarrRoot>> roots;
  ChaptarrRoot? selected;
  int? added;
  bool busy = false;
  bool uncertain = false;
  String? error;
  bool searchForMissing = false;
  (int, String)? quality, metadata;

  Widget profileTile(bool isQuality, int defaultId) {
    final field = isQuality ? quality : metadata;
    final label =
        (isQuality ? 'radarr.QualityProfile' : 'chaptarr.MetadataProfile').tr();
    return chaptarrSetting(
      label,
      field?.$2 ?? 'chaptarr.RootDefault'.tr(),
      busy || uncertain
          ? null
          : () async {
              try {
                final rows = await (isQuality
                    ? widget.api.qualityProfiles()
                    : widget.api.metadataProfiles());
                if (!mounted || busy || uncertain) return;
                final options = chaptarrProfileNames(rows, widget.format);
                final id = await chaptarrChoice<int>(
                  context,
                  label,
                  options,
                  current: field?.$1 ?? defaultId,
                );
                if (!mounted || id == null) return;
                setState(() {
                  final next = (id, options[id]!);
                  if (isQuality) {
                    quality = next;
                  } else {
                    metadata = next;
                  }
                });
              } catch (e) {
                if (mounted)
                  showLunaErrorSnackBar(
                    title: 'chaptarr.ActionFailed'.tr(),
                    error: e,
                  );
              }
            },
    );
  }

  @override
  void initState() {
    super.initState();
    roots = widget.api.roots(widget.format);
    final pending = widget.api.pendingImport(widget.book, widget.format);
    if (pending != null) observe(pending);
  }

  Future<void> observe(Future<int> import) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await import;
      if (mounted) setState(() => added = id);
    } catch (e) {
      if (!mounted) return;
      final response = e is DioException ? e.response : null;
      final body = response?.data;
      final validation = body is List
          ? body
                .whereType<Map>()
                .map((row) => row['errorMessage'])
                .whereType<String>()
                .join('\n')
          : null;
      setState(() {
        uncertain =
            response == null ||
            (response.statusCode ?? 500) >= 500 ||
            response.statusCode == 409;
        error = uncertain
            ? 'chaptarr.ImportUnconfirmed'.tr()
            : (validation?.isNotEmpty ?? false)
            ? validation
            : 'chaptarr.ActionFailed'.tr();
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkLibrary() async {
    setState(() => busy = true);
    try {
      final books = await widget.api.lookup(widget.book.foreignBookId);
      final matches = books
          .where((book) => book.foreignBookId == widget.book.foreignBookId)
          .expand((book) => book.localEditions(widget.format));
      if (mounted)
        setState(() {
          added = matches.firstOrNull?.id;
          uncertain = false;
          error = added == null ? 'chaptarr.ImportNotFound'.tr() : null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'chaptarr.ImportUnconfirmed'.tr());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ChaptarrRoot>>(
    future: roots,
    builder: (context, snapshot) {
      final choices = snapshot.data ?? const <ChaptarrRoot>[];
      final root = selected ?? choices.firstOrNull;
      final identified =
          widget.book.foreignAuthorId.isNotEmpty &&
          widget.book.foreignBookId.isNotEmpty;
      return LunaScaffold(
        scaffoldKey: scaffold,
        appBar: LunaAppBar(
          title: 'chaptarr.AddBook'.tr(),
          scrollControllers: [scrollController],
        ),
        bottomNavigationBar:
            (root != null && identified || busy || added != null || uncertain)
            ? LunaBottomActionBar(actionsPerRow: 1, actions: [action(root)])
            : null,
        body: LunaListView(
          controller: scrollController,
          children: [
            ChaptarrDescriptionTile(api: widget.api, book: widget.book),
            if (added != null)
              LunaHeader(text: 'chaptarr.BookAdded'.tr())
            else if (!identified)
              LunaMessage.inList(text: 'chaptarr.MissingIdentifier'.tr())
            else ...[
              LunaHeader(text: 'chaptarr.RootFolder'.tr()),
              if (snapshot.connectionState != ConnectionState.done)
                const LunaLoader(useSafeArea: false)
              else if (snapshot.hasError)
                LunaMessage.error(
                  onTap: () {
                    setState(() {
                      roots = widget.api.roots(widget.format);
                    });
                  },
                )
              else if (choices.isEmpty)
                LunaMessage.inList(text: 'chaptarr.ConfigureRoot'.tr())
              else
                for (final folder in choices)
                  LunaBlock(
                    title: folder.path,
                    trailing: Icon(
                      folder == root
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: folder == root
                          ? LunaColours.accent
                          : LunaColours.grey,
                    ),
                    onTap: busy || uncertain
                        ? null
                        : () => setState(() {
                            selected = folder;
                            quality = null;
                            metadata = null;
                          }),
                  ),
              if (root != null) ...[
                profileTile(true, root.qualityProfileId),
                profileTile(false, root.metadataProfileId),
                LunaBlock(
                  title: 'chaptarr.SearchOnAdd'.tr(),
                  trailing: AbsorbPointer(
                    absorbing: busy || uncertain,
                    child: LunaSwitch(
                      value: searchForMissing,
                      onChanged: (v) => setState(() => searchForMissing = v),
                    ),
                  ),
                ),
              ],
              if (error != null) LunaMessage.inList(text: error!),
              if (busy) ...[
                const LinearProgressIndicator(),
                LunaMessage.inList(
                  text:
                      (uncertain
                              ? 'chaptarr.CheckingLibrary'
                              : 'chaptarr.ImportPending')
                          .tr(),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );

  Widget action(ChaptarrRoot? root) {
    if (added != null)
      return LunaButton.text(
        text: 'chaptarr.BookDetails'.tr(),
        icon: Icons.menu_book_rounded,
        onTap: () => context.pushReplacement('/chaptarr/book/$added'),
      );
    if (busy)
      return LunaButton.text(
        text: 'lunasea.GoBack'.tr(),
        icon: Icons.arrow_back_rounded,
        onTap: () => context.pop(),
      );
    if (uncertain)
      return LunaButton.text(
        text: 'chaptarr.CheckLibrary'.tr(),
        icon: Icons.refresh_rounded,
        onTap: checkLibrary,
      );
    return LunaButton.text(
      text: 'chaptarr.AddBook'.tr(),
      icon: Icons.add_rounded,
      backgroundColor: LunaColours.accent,
      color: Colors.white,
      onTap: () {
        if (!busy && root != null)
          observe(
            widget.api.add(
              widget.book,
              widget.format,
              ChaptarrRoot(
                root.path,
                quality?.$1 ?? root.qualityProfileId,
                metadata?.$1 ?? root.metadataProfileId,
              ),
              searchForMissing: searchForMissing,
            ),
          );
      },
    );
  }
}

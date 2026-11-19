import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/chaptarr.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/extensions/datetime.dart';

class ChaptarrDescriptionTile extends StatelessWidget {
  final ChaptarrBook book;
  final ChaptarrAPI api;
  const ChaptarrDescriptionTile({
    super.key,
    required this.book,
    required this.api,
  });
  @override
  Widget build(BuildContext context) {
    final summary = book.overview.isEmpty
        ? 'sonarr.NoSummaryAvailable'.tr()
        : book.overview;
    final cover = api.bookCover(book);
    final background = api.artworkUrl(book.fanart) ?? cover;
    return LunaBlock(
      title: book.title,
      posterUrl: cover,
      backgroundUrl: background,
      posterHeaders: api.artworkHeaders(cover),
      backgroundHeaders: api.artworkHeaders(background),
      posterPlaceholderIcon: book.format?.icon ?? Icons.menu_book_rounded,
      body: [LunaTextSpan.extended(text: summary)],
      customBodyMaxLines: 3,
      onTap: () => LunaDialogs().textPreview(context, book.title, summary),
    );
  }
}

extension ChaptarrFormatLabel on ChaptarrFormat {
  String get label =>
      (this == ChaptarrFormat.ebook ? 'chaptarr.Ebook' : 'chaptarr.Audiobook')
          .tr();
  IconData get icon => this == ChaptarrFormat.ebook
      ? Icons.menu_book_rounded
      : Icons.headphones_rounded;
}

class ChaptarrFormatMenu extends StatelessWidget {
  final ChaptarrFormat value;
  final ValueChanged<ChaptarrFormat> onChanged;
  final bool overflow;
  const ChaptarrFormatMenu({
    super.key,
    required this.value,
    required this.onChanged,
    this.overflow = false,
  });

  @override
  Widget build(BuildContext context) => LunaPopupMenuButton<ChaptarrFormat>(
    tooltip: value.label,
    icon: overflow ? Icons.more_vert_rounded : value.icon,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final format in ChaptarrFormat.values)
        CheckedPopupMenuItem(
          value: format,
          checked: value == format,
          child: Text(format.label),
        ),
    ],
  );
}

class ChaptarrBookTile extends StatelessWidget {
  final ChaptarrBook book;
  final ChaptarrAPI api;
  final bool grid;
  final ChaptarrFormat? format;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool lookup;
  const ChaptarrBookTile({
    super.key,
    required this.book,
    required this.api,
    this.format,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.grid = false,
    this.lookup = false,
  });

  @override
  Widget build(BuildContext context) {
    final media = format ?? book.format;
    final icon = media?.icon ?? Icons.menu_book_rounded;
    final cover = api.bookCover(book);
    final background = api.artworkUrl(book.fanart) ?? cover;
    Widget interactive(Widget child) => onTap == null
        ? child
        : Semantics(
            button: true,
            excludeSemantics: true,
            onTap: onTap,
            onLongPress: onLongPress,
            label: [
              book.title,
              book.author,
              if (media != null) media.label,
              if (!lookup)
                (book.hasFiles
                        ? 'chaptarr.Downloaded'
                        : book.monitored
                        ? 'chaptarr.Monitored'
                        : 'chaptarr.Unmonitored')
                    .tr(),
            ].join(', '),
            child: child,
          );
    if (grid) {
      return interactive(
        LunaGridBlock(
          title: book.title,
          subtitle: TextSpan(text: book.author),
          posterUrl: cover,
          posterHeaders: api.artworkHeaders(cover),
          backgroundUrl: background,
          backgroundHeaders: api.artworkHeaders(background),
          posterPlaceholderIcon: icon,
          disabled: !book.monitored,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      );
    }
    final date = book.releaseDate;
    final credits = [
      if (date != null) '${date.year}',
      if (book.pageCount > 0 && media == ChaptarrFormat.ebook)
        'chaptarr.Pages'.tr(args: ['${book.pageCount}']),
      if (book.author.isNotEmpty) book.author,
    ];
    final metadata = [
      if (media != null) media.label,
      if (book.narrator.isNotEmpty) book.narrator,
      if (book.added != null && book.added!.year > 1) book.added!.asDateOnly(),
    ];
    return interactive(
      LunaBlock(
        title: book.title,
        posterUrl: cover,
        posterHeaders: api.artworkHeaders(cover),
        backgroundUrl: background,
        backgroundHeaders: api.artworkHeaders(background),
        posterPlaceholderIcon: icon,
        disabled: !lookup && !book.monitored,
        body: [
          TextSpan(text: credits.join(' · ')),
          TextSpan(text: metadata.join(' · ')),
        ],
        bottom: lookup
            ? null
            : Row(
                children: [
                  Icon(
                    icon,
                    size: LunaUI.FONT_SIZE_H2,
                    color: LunaColours.orange,
                  ),
                  const SizedBox(width: LunaUI.DEFAULT_MARGIN_SIZE / 4),
                  Icon(
                    book.monitored
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: LunaUI.FONT_SIZE_H2,
                    color: book.monitored ? LunaColours.blue : LunaColours.grey,
                  ),
                  Icon(
                    Icons.check_circle_rounded,
                    size: LunaUI.FONT_SIZE_H2,
                    color: book.hasFiles
                        ? LunaColours.accent
                        : LunaColours.grey,
                  ),
                  const SizedBox(width: LunaUI.MARGIN_SIZE_HALF),
                  Flexible(
                    child: Text(
                      book.sizeOnDisk > 0
                          ? book.sizeOnDisk.asBytes()
                          : (book.hasFiles
                                    ? 'chaptarr.Downloaded'
                                    : book.monitored
                                    ? 'chaptarr.Monitored'
                                    : 'chaptarr.Unmonitored')
                                .tr(),
                      style: TextStyle(
                        color: book.hasFiles
                            ? LunaColours.accent
                            : LunaColours.grey,
                        fontSize: LunaUI.FONT_SIZE_H3,
                        fontWeight: LunaUI.FONT_WEIGHT_BOLD,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

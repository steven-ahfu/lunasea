enum LunaReleaseFilter {
  indexer,
  quality,
  resolution,
  dualAudio,
  audioFormat,
  language,
  customFormat,
}

enum _AudioFormat {
  trueHd('TrueHD', r'true[ ._-]?hd'),
  atmos('Atmos', r'atmos'),
  dolbyDigitalPlus(
    'Dolby Digital Plus',
    r'e[ ._-]?ac[ ._-]?3|ddp|dd\+|dolby[ ._-]+digital[ ._-]*(?:plus|\+)',
  ),
  dolbyDigital('Dolby Digital', r'ac[ ._-]?3|dd|dolby[ ._-]+digital'),
  dtsHdMa('DTS-HD MA', r'dts[ ._-]*hd[ ._-]*(?:ma|master[ ._-]+audio)'),
  dtsHd('DTS-HD', r'dts[ ._-]*hd'),
  dtsX('DTS:X', r'dts[ ._:-]*x'),
  dts('DTS', r'dts'),
  aac('AAC', r'aac'),
  flac('FLAC', r'flac'),
  alac('ALAC', r'alac|apple[ ._-]+lossless'),
  opus('Opus', r'(?:ogg[ ._-]+)?opus'),
  oggVorbis('Ogg Vorbis', r'ogg(?:[ ._-]+vorbis)?|vorbis'),
  wavPack('WavPack', r'wavpack'),
  wav('WAV', r'wav'),
  aiff('AIFF', r'aiff?'),
  wma('WMA', r'wma'),
  pcm('PCM', r'l?pcm'),
  mp3('MP3', r'mp3');

  final String label;
  final String pattern;
  const _AudioFormat(this.label, this.pattern);

  // Match a whole tag, optionally followed immediately by channels (DDP5.1).
  // More specific tags precede their base format so DTS-HD MA is one match.
  static final _tags = RegExp(
    r'(?:^|[^a-z0-9])(?:' +
        values
            .map((format) => '(?<${format.name}>${format.pattern})')
            .join('|') +
        r')(?=(?:[1-9]\.[0-9])?(?:[^a-z0-9]|$))',
    caseSensitive: false,
  );

  static List<LunaReleaseFilterOption> detect(Iterable<String> labels) {
    final formats = <LunaReleaseFilterOption>{};
    for (final label in labels) {
      for (final match in _tags.allMatches(label)) {
        final format = values.firstWhere(
          (f) => match.namedGroup(f.name) != null,
        );
        formats.add(LunaReleaseFilterOption.named(format.label));
      }
    }
    return formats.toList();
  }
}

class LunaReleaseFilterOption {
  final String key;
  final String label;

  const LunaReleaseFilterOption(this.key, this.label);

  factory LunaReleaseFilterOption.named(String? name, {int? id}) {
    final label = name?.trim() ?? '';
    if (id == null && label.isEmpty) return unknown;
    return LunaReleaseFilterOption(
      id == null ? 'name:${label.toLowerCase()}' : 'id:$id',
      label,
    );
  }

  factory LunaReleaseFilterOption.resolution(int? resolution) =>
      resolution == null || resolution <= 0
      ? unknown
      : LunaReleaseFilterOption('resolution:$resolution', '${resolution}p');

  static const unknown = LunaReleaseFilterOption('unknown', '');
  static const none = LunaReleaseFilterOption('none', '');
  static const dualAudio = LunaReleaseFilterOption('dualAudio', '');

  @override
  bool operator ==(Object other) =>
      other is LunaReleaseFilterOption && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class LunaReleaseFilterData {
  final String? title;
  final String? audioQuality;
  final Map<LunaReleaseFilter, List<LunaReleaseFilterOption>> values;

  const LunaReleaseFilterData({
    this.title,
    this.audioQuality,
    this.values = const {},
  });

  List<LunaReleaseFilterOption> optionsFor(LunaReleaseFilter filter) {
    if (filter == LunaReleaseFilter.audioFormat && audioQuality != null) {
      final formats = _AudioFormat.detect([audioQuality!]);
      if (formats.isNotEmpty) return formats;
    }
    final options = filter == LunaReleaseFilter.audioFormat
        ? _AudioFormat.detect([
            ?title,
            for (final format
                in values[LunaReleaseFilter.customFormat] ??
                    const <LunaReleaseFilterOption>[])
              format.label,
          ])
        : values[filter];
    return options == null || options.isEmpty
        ? const [LunaReleaseFilterOption.unknown]
        : options;
  }
}

class LunaReleaseFilters {
  final Map<LunaReleaseFilter, Set<LunaReleaseFilterOption>> selections;

  LunaReleaseFilters({
    Map<LunaReleaseFilter, Set<LunaReleaseFilterOption>> selections = const {},
  }) : selections = Map.unmodifiable({
         for (final entry in selections.entries)
           if (entry.value.isNotEmpty)
             entry.key: Set<LunaReleaseFilterOption>.unmodifiable(entry.value),
       });

  int get activeCount => selections.length;

  Set<LunaReleaseFilterOption> selectedFor(LunaReleaseFilter filter) =>
      selections[filter] ?? const {};

  LunaReleaseFilters withSelection(
    LunaReleaseFilter filter,
    Set<LunaReleaseFilterOption> options,
  ) => LunaReleaseFilters(selections: {...selections, filter: options});

  bool matches(LunaReleaseFilterData release) {
    return selections.entries.every((entry) {
      if (entry.key == LunaReleaseFilter.dualAudio) {
        return (release.title ?? '').toLowerCase().contains('dual audio');
      }
      final options = release.optionsFor(entry.key);
      if (entry.key == LunaReleaseFilter.customFormat) {
        return entry.value.every(options.contains);
      }
      return options.any(entry.value.contains);
    });
  }

  List<LunaReleaseFilterOption> optionsFor(
    LunaReleaseFilter filter,
    Iterable<LunaReleaseFilterData> releases,
  ) {
    if (filter == LunaReleaseFilter.dualAudio) {
      return const [LunaReleaseFilterOption.dualAudio];
    }
    final options = {
      ...releases.expand((release) => release.optionsFor(filter)),
      ...selectedFor(filter),
    }.toList();
    options.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return options;
  }
}

enum LunaReleaseFilter {
  indexer,
  quality,
  resolution,
  dualAudio,
  language,
  customFormat,
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
  final Map<LunaReleaseFilter, List<LunaReleaseFilterOption>> values;

  const LunaReleaseFilterData({this.title, this.values = const {}});

  List<LunaReleaseFilterOption> optionsFor(LunaReleaseFilter filter) {
    final options = values[filter];
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
      return release.optionsFor(entry.key).any(entry.value.contains);
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

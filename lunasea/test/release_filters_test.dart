import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/types/release_filters.dart';

void main() {
  final trackerA = LunaReleaseFilterOption.named('Tracker A', id: 1);
  final trackerB = LunaReleaseFilterOption.named('Tracker B', id: 2);
  final hd = LunaReleaseFilterOption.resolution(1080);
  final uhd = LunaReleaseFilterOption.resolution(2160);

  LunaReleaseFilterData release({
    String? title = 'Movie Dual Audio',
    LunaReleaseFilterOption? tracker,
    LunaReleaseFilterOption? resolution,
    List<LunaReleaseFilterOption>? languages,
    List<LunaReleaseFilterOption>? formats,
  }) => LunaReleaseFilterData(
    title: title,
    values: {
      if (tracker != null) LunaReleaseFilter.indexer: [tracker],
      if (resolution != null) LunaReleaseFilter.resolution: [resolution],
      if (languages != null) LunaReleaseFilter.language: languages,
      if (formats != null) LunaReleaseFilter.customFormat: formats,
    },
  );

  test('unrestricted filters include releases with missing metadata', () {
    expect(LunaReleaseFilters().matches(release(title: null)), isTrue);
  });

  test('multiple values match with OR and filter groups combine with AND', () {
    final filters = LunaReleaseFilters()
        .withSelection(LunaReleaseFilter.indexer, {trackerA, trackerB})
        .withSelection(LunaReleaseFilter.resolution, {hd, uhd})
        .withSelection(LunaReleaseFilter.dualAudio, {
          LunaReleaseFilterOption.dualAudio,
        });
    expect(filters.matches(release(tracker: trackerA, resolution: hd)), isTrue);
    expect(
      filters.matches(release(tracker: trackerB, resolution: uhd)),
      isTrue,
    );
    expect(filters.matches(release(tracker: trackerA)), isFalse);
    expect(
      filters.matches(
        release(
          tracker: LunaReleaseFilterOption.named('Other', id: 3),
          resolution: hd,
        ),
      ),
      isFalse,
    );
    expect(
      filters.matches(
        release(title: 'Movie single audio', tracker: trackerA, resolution: hd),
      ),
      isFalse,
    );
  });

  test('dual audio uses a literal case-insensitive substring', () {
    final filters = LunaReleaseFilters().withSelection(
      LunaReleaseFilter.dualAudio,
      {LunaReleaseFilterOption.dualAudio},
    );
    for (final title in [
      'Movie Dual Audio 1080p',
      'DUAL AUDIO',
      'dual audio',
    ]) {
      expect(filters.matches(release(title: title)), isTrue, reason: title);
    }
    for (final title in [null, '', 'dual-audio', 'dual.audio', 'dual  audio']) {
      expect(filters.matches(release(title: title)), isFalse, reason: '$title');
    }
  });

  test(
    'languages and custom formats match any selected value in each group',
    () {
      final english = LunaReleaseFilterOption.named('English', id: 1);
      final french = LunaReleaseFilterOption.named('French', id: 2);
      final hdr = LunaReleaseFilterOption.named('HDR', id: 10);
      final dv = LunaReleaseFilterOption.named('DV', id: 11);
      final filters = LunaReleaseFilters()
          .withSelection(LunaReleaseFilter.language, {english, french})
          .withSelection(LunaReleaseFilter.customFormat, {hdr, dv});
      expect(
        filters.matches(release(languages: [french], formats: [dv])),
        isTrue,
      );
      expect(
        filters.matches(release(languages: [english], formats: [])),
        isFalse,
      );
      expect(filters.matches(release(formats: [hdr])), isFalse);
    },
  );

  test('unknown metadata is explicit and distinct from no custom formats', () {
    final unknown = LunaReleaseFilters().withSelection(
      LunaReleaseFilter.customFormat,
      {LunaReleaseFilterOption.unknown},
    );
    final none = LunaReleaseFilters().withSelection(
      LunaReleaseFilter.customFormat,
      {LunaReleaseFilterOption.none},
    );
    expect(unknown.matches(release()), isTrue);
    expect(none.matches(release()), isFalse);
    expect(
      none.matches(release(formats: [LunaReleaseFilterOption.none])),
      isTrue,
    );
    expect(
      unknown.matches(release(formats: [LunaReleaseFilterOption.none])),
      isFalse,
    );
  });

  test('editing or clearing one filter preserves other filter selections', () {
    final original = LunaReleaseFilters()
        .withSelection(LunaReleaseFilter.indexer, {trackerA, trackerB})
        .withSelection(LunaReleaseFilter.resolution, {hd});
    final changed = original.withSelection(LunaReleaseFilter.indexer, {});
    expect(changed.selectedFor(LunaReleaseFilter.resolution), {hd});
    expect(changed.activeCount, 1);
    expect(original.selectedFor(LunaReleaseFilter.indexer), {
      trackerA,
      trackerB,
    });
    expect(LunaReleaseFilters().activeCount, 0);
  });

  test('options use all results and retain selected values after refresh', () {
    final filters = LunaReleaseFilters()
        .withSelection(LunaReleaseFilter.indexer, {trackerB})
        .withSelection(LunaReleaseFilter.resolution, {uhd});
    final results = [
      release(tracker: trackerA, resolution: hd),
      release(tracker: trackerA, resolution: uhd),
    ];
    expect(filters.optionsFor(LunaReleaseFilter.indexer, results), [
      trackerA,
      trackerB,
    ]);
  });

  test('provider identity uses IDs and name fallback is case-insensitive', () {
    expect(LunaReleaseFilterOption.named('Renamed', id: 1), trackerA);
    expect(LunaReleaseFilterOption.named('Tracker A', id: 9), isNot(trackerA));
    expect(
      LunaReleaseFilterOption.named('  TRACKER A  '),
      LunaReleaseFilterOption.named('tracker a'),
    );
    expect(
      LunaReleaseFilterOption.resolution(0),
      LunaReleaseFilterOption.unknown,
    );
  });

  test('selections are immutable snapshots of dialog values', () {
    final options = {trackerA};
    final filters = LunaReleaseFilters().withSelection(
      LunaReleaseFilter.indexer,
      options,
    );
    options.add(trackerB);
    expect(filters.selectedFor(LunaReleaseFilter.indexer), {trackerA});
    expect(
      () => filters.selectedFor(LunaReleaseFilter.indexer).clear(),
      throwsUnsupportedError,
    );
  });
}

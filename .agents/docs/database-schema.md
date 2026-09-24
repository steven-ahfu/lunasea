# Local Database: Hive CE

The app uses **Hive Community Edition** (`hive_ce`, `hive_ce_flutter`, `hive_ce_generator`). There is no server database: all persistent state lives on the device. Paths below are relative to `lunasea/lib/`.

## Boxes (`database/box.dart`)

```dart
enum LunaBox<T> { alerts<dynamic>, externalModules<LunaExternalModule>, indexers<LunaIndexer>,
                  logs<LunaLog>, lunasea<dynamic>, profiles<LunaProfile> }
```

Box API: `read(key, fallback:)`, `update(key, v)`, `create(v)`, `delete`, `clear`, `watch`, `listenable`,
`listenableBuilder(selectKeys:, selectItems:)`, and `export()`.

| Box | Holds |
|---|---|
| `lunasea` | All key/value settings, written through `LunaTable` enums (below) |
| `profiles` | `LunaProfile` objects, keyed by profile name. The default key is `'default'` |
| `indexers` | Newznab indexers for the Search module |
| `externalModules` | User-defined external links |
| `logs` | `LunaLog` entries, compacted to 50 at boot |
| `alerts` | Dismissed banners, e.g. `LUNASEA_MODULE_INFORMATION_<key>` |

`LunaDatabase` (`database/database.dart`) handles:
- `Hive.initFlutter(path)`
- `LunaTable.register()` (registers adapters)
- opening every box
- creating the `default` profile if none exists
- nuking or clearing the database

## Tables: typed settings (`database/table.dart`)

```dart
enum LunaTable<T extends LunaTableMixin> {
  bios<BIOSDatabase>('bios', items: BIOSDatabase.values),
  dashboard<DashboardDatabase>('home', ...),   // NOTE: key is 'home'
  lidarr, lunasea, nzbget, radarr, sabnzbd, search, sonarr, tautulli, tracearr }

mixin LunaTableMixin<T> on Enum {
  T get fallback; LunaTable get table; LunaBox get box => LunaBox.lunasea;
  String get key => '${table.key.toUpperCase()}_$name';   // e.g. TRACEARR_REFRESH_RATE, HOME_...
  T read() => box.read(key, fallback: fallback);
  void update(T value) => box.update(key, value);
  void register() {}                       // override to Hive.registerAdapter(...)
  List get blockedFromImportExport => [];
  dynamic export(); void import(dynamic value);
  ValueListenableBuilder listenableBuilder(...);
}
```

This is what a per-module table looks like (`database/tables/tracearr.dart`):

```dart
enum TracearrDatabase<T> with LunaTableMixin<T> {
  NAVIGATION_INDEX<int>(0), REFRESH_RATE<int>(15), CONTENT_LOAD_LENGTH<int>(50);
  @override LunaTable get table => LunaTable.tracearr;
  @override final T fallback;
  const TracearrDatabase(this.fallback);
}
```

**Storage key = `<TABLE_KEY_UPPER>_<ENUM_NAME>`.** Renaming an enum value or a table key silently resets that setting for every user.

`LunaSeaDatabase` (`database/tables/lunasea.dart`) holds the global settings:
- `ENABLED_PROFILE`
- `THEME_AMOLED` and `THEME_AMOLED_BORDER`
- `NETWORKING_TLS_VALIDATION` (default **false**)
- `DRAWER_MANUAL_ORDER`
- `QUICK_ACTIONS_*`
- `USE_24_HOUR_TIME`
- `NOTIFICATIONS_SERVICE_URL`, `NOTIFICATIONS_TOPIC` and `NOTIFICATIONS_TOKEN`
- `CHANGELOG_LAST_BUILD_VERSION`

Tables that store custom enums need three things. `RadarrDatabase` and `BIOSDatabase` are examples:
1. Override `register()` to register the enum's adapter.
2. Override `export()` / `import()` to convert to and from `.key` strings.
3. Optionally list values in `blockedFromImportExport`.

## Profiles (`database/models/profile.dart`)

`LunaProfile extends HiveObject` is annotated with both `@HiveType(typeId: 0)` and `@JsonSerializable()`.

- **One profile holds a full set of service connections.** `LunaProfile.current` resolves `LunaSeaDatabase.ENABLED_PROFILE`.
- **Per-service fields** follow the pattern `<svc>Enabled`, `<svc>Host`, `<svc>Key` and `<svc>Headers`. There are two exceptions:
  - NZBGet uses user and password fields.
  - Wake-on-LAN uses `wakeOnLANEnabled`, `wakeOnLANBroadcastAddress` and `wakeOnLANMACAddress`.
- **Constructors:** a private `_internal` constructor takes the required fields. A public factory takes nullable arguments and applies defaults. Any new field goes into **both**.
- **HiveField indices in use:** 0–15, 23–33, 35 and 40–47. **The next safe index is 48.** The gaps (16–22, 34, 36–39) are retired, so never reuse them.
- **Saving:** save edits with `LunaProfile.current.save()`, then call `context.read<XState>().reset()`.

## Hive typeId registry

| typeId | Class | File |
|---|---|---|
| 0 | LunaProfile | `database/models/profile.dart` |
| 1 | LunaIndexer | `database/models/indexer.dart` |
| 2–7, 11 | `_DeprecatedNN` placeholders (do not reuse) | `database/models/deprecated.dart` |
| 8 | LidarrRootFolder | `modules/lidarr/core/api/data/rootfolder.dart` |
| 9 | LidarrQualityProfile | `modules/lidarr/core/api/data/qualityprofile.dart` |
| 10 | LidarrMetadataProfile | `modules/lidarr/core/api/data/metadata.dart` |
| 12 | CalendarStartingDay | `modules/dashboard/core/adapters/calendar_starting_day.dart` |
| 13 | CalendarStartingSize | `modules/dashboard/core/adapters/calendar_starting_size.dart` |
| 14 | SonarrMonitorStatus | `modules/sonarr/core/types/monitor_status.dart` |
| 15 | CalendarStartingType | `modules/dashboard/core/adapters/calendar_starting_type.dart` |
| 16 | SonarrSeriesSorting | `modules/sonarr/core/types/sorting_series.dart` |
| 17 | SonarrReleasesSorting | `modules/sonarr/core/types/sorting_releases.dart` |
| 18 | RadarrMoviesSorting | `modules/radarr/core/types/sorting_movies.dart` |
| 19 | RadarrMoviesFilter | `modules/radarr/core/types/filter_movies.dart` |
| 20 | RadarrReleasesFilter | `modules/radarr/core/types/filter_releases.dart` |
| 21 | RadarrReleasesSorting | `modules/radarr/core/types/sorting_releases.dart` |
| 22 | LunaIndexerIcon | `types/indexer_icon.dart` |
| 23 | LunaLog | `database/models/log.dart` |
| 24 | LunaLogType | `types/log_type.dart` |
| 25 | LunaModule | `modules.dart` |
| 26 | LunaExternalModule | `database/models/external_module.dart` |
| 27 | SonarrSeriesFilter | `modules/sonarr/core/types/filter_series.dart` |
| 28 | SonarrReleasesFilter | `modules/sonarr/core/types/filter_releases.dart` |
| 29 | LunaListViewOption | `types/list_view_option.dart` |

**Next free typeId: 30.** You can verify this with:

```bash
grep -rhoE "typeId: [0-9]+" lunasea/lib | sort -t' ' -k2 -n | uniq
```

The **next free HiveField is 13** in `LunaModule`, and **48** in `LunaProfile`.

## Backup and restore (`database/config.dart`)

- **Export:** `LunaConfig.export()` produces JSON with these keys:
  - `profiles`
  - `indexers`
  - `external_modules`
  - one entry per `LunaTable.key`, shaped `{itemKey: value}`
- **Import:** `import()` clears the database, restores the data, then calls `LunaState.reset()`.
- **Compatibility:** changing table keys or enum `.key` strings breaks compatibility with old backups.

## Migration rules

Hive has no migration framework. Compatibility depends entirely on these invariants:

1. Never change or reuse a typeId or a HiveField index.
2. Add new fields with `@HiveField(n, defaultValue: ...)` so that existing records still load.
3. To retire a type, replace it with a placeholder adapter in `deprecated.dart`. Do not delete it.
4. After changing any annotation, run `dart run build_runner build`.

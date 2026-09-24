# Flutter App Architecture (`lunasea/`)

All paths in this document are relative to `lunasea/` unless noted.

## Bird's-eye view

```
main.dart ─ runZonedGuarded
  └─ bootstrap()                       (throws → LunaRecoveryMode)
       LunaDatabase().initialize()     Hive CE: adapters, boxes, default profile
       LunaLogger().initialize()       FlutterError → zone; compact logs to 50
       LunaTheme().initialize()
       LunaWindowManager / LunaNetwork / LunaImageCache  (each guarded by isSupported)
       LunaRouter().initialize()       GoRouter from LunaRoutes.values
       LunaMemoryStore().initialize()  stash in-memory cache
       LunaDeepLinks().initialize()    lunasea:// on Android/iOS/macOS
  └─ runApp(LunaBIOS)
       LunaState.providers (MultiProvider of ChangeNotifier module states)
        └ DevicePreview (debug + desktop only)
         └ EasyLocalization(supportedLocales: [en], path: assets/localization)
          └ LunaBox.lunasea.listenableBuilder(THEME_AMOLED, THEME_AMOLED_BORDER)
           └ MaterialApp.router(LunaRouter.router)
```

- The initial location is `/`, which is `BIOSRoutes.HOME`.
- That route is a redirect. It runs `LunaOS().boot(context)` (quick actions), then redirects to `BIOSDatabase.BOOT_MODULE.read().homeRoute`, falling back to `/dashboard`.
- The Hive database lives at `LunaSea/database` on Windows and Linux, and at `database` on all other platforms.

## `lib/` layout

```
lib/
  main.dart            entry + bootstrap
  core.dart            DEPRECATED catch-all barrel (still used almost everywhere)
  vendor.dart          re-exports third-party packages (dio, go_router, hive_ce, provider, retrofit, easy_localization, flash, stash, supercharged, tuple, xml…)
  modules.dart         LunaModule enum (Hive typeId 25) + metadata/routing/webhook/state extensions
  api/                 standalone API client libraries: nzbget, radarr, sabnzbd, sonarr, tautulli, tracearr, wake_on_lan
  database/            LunaDatabase, LunaBox, LunaTable(+Mixin), LunaConfig (backup), models/, tables/
  extensions/          datetime, double, duration, int (bytes/duration), string (links/string), scroll/page controller
  modules/             <module>.dart barrels + <module>/ dirs: dashboard, external_modules, lidarr, nzbget, radarr, sabnzbd, search, settings, sonarr, tautulli, tracearr
  router/              router.dart (LunaRouter), routes.dart (LunaRoutes + LunaRoutesMixin), routes/<module>.dart
  system/              bios, state, flavor, platform, logger, webhooks, environment.dart (GENERATED), cache/, deeplinks/, filesystem/, network/, quick_actions/, window_manager/, recovery_mode/
  types/               enums, LunaException, indexer_icon (22), list_view_option (29), loading_state, log_type (24)
  utils/               dialogs (LunaDialogs), links, parser, profile_tools, uuid, validator
  widgets/             ui.dart barrel + LunaUI constants; ui/ (Luna* widgets, theme, colours, icons, assets.dart [spider]); pages/ (error/invalid/not_enabled); sheets/
```

There are about 1,380 hand-written Dart files. About 187 `part '*.g.dart'` files are generated and **not committed**.

## The module system (`lib/modules.dart`)

```dart
const MODULE_TRACEARR_KEY = 'tracearr';

@HiveType(typeId: 25, adapterName: 'LunaModuleAdapter')
enum LunaModule {
  @HiveField(0) DASHBOARD(MODULE_DASHBOARD_KEY),
  @HiveField(11) EXTERNAL_MODULES(...), @HiveField(1) LIDARR(...), @HiveField(2) NZBGET(...),
  @HiveField(3) OVERSEERR(...), @HiveField(4) RADARR(...), @HiveField(5) SABNZBD(...),
  @HiveField(6) SEARCH(...), @HiveField(7) SETTINGS(...), @HiveField(8) SONARR(...),
  @HiveField(9) TAUTULLI(...), @HiveField(12) TRACEARR(...), @HiveField(10) WAKE_ON_LAN(...);
```

- **Next free HiveField: 13.** Never renumber a field.
- Module behavior lives in extensions that switch exhaustively over every value. When you add a value, the compile errors list every site you need to update:

| Extension | Provides |
|---|---|
| `LunaModuleEnablementExtension` | `featureFlag` (OVERSEERR returns **false**; WAKE_ON_LAN returns `isSupported`), `isEnabled` (from `LunaProfile.current.<x>Enabled`) |
| `LunaModuleMetadataExtension` | `title`, `icon`, `color`, `website`, `github`, `description`, `information` |
| `LunaModuleRoutingExtension` | `homeRoute`, `settingsRoute`, `launch()` |
| `LunaModuleWebhookExtension` | `hasWebhooks`, `webhookDocs`, `handleWebhook(data)` |
| `LunaModuleExtension` | `shortcutItem`, `state(context)`, `informationBanner()` |

`LunaModule.active` returns every module except DASHBOARD and SETTINGS whose `featureFlag` is true.

### Module internal layout

**Older, larger modules** (radarr, sonarr, tautulli):

```
modules/radarr.dart                       barrel: api/radarr + radarr/core.dart + radarr/routes.dart
modules/radarr/core.dart                  exports tables + core/{api_helper,bottom_modal_sheets,dialogs,extensions,state,types,webhooks}
modules/radarr/core/state.dart            RadarrState extends LunaModuleState
modules/radarr/core/api_helper.dart       wraps API calls with snackbars + logging + state refresh
modules/radarr/core/types/                Hive-persisted sort/filter enums (.key / .fromKey)
modules/radarr/core/webhooks.dart         RadarrWebhooks extends LunaWebhooks
modules/radarr/routes/<page>/route.dart   the page (StatefulWidget)
modules/radarr/routes/<page>/widgets.dart barrel over widgets/*.dart
```

**Newest module: Tracearr.** It is the leanest and the best template to copy:

```
api/tracearr/{tracearr.dart, api.dart (Retrofit), models.dart, models/*.dart, types.dart, utils/converters.dart}
modules/tracearr.dart
modules/tracearr/core/state.dart
modules/tracearr/routes/{home,streams,history,users,violations,stream_details,history_details,user_details}/
router/routes/tracearr.dart
database/tables/tracearr.dart
modules/settings/routes/configuration_tracearr/route.dart
localization/tracearr/en.json
```

Lidarr, NZBGet and SABnzbd also keep legacy in-module API layers in `modules/<m>/core/api/`.

### Page patterns

**Home page** (`modules/tracearr/routes/home/route.dart`):
- `LunaScaffold(module:, drawer: LunaDrawer(page: key), appBar: LunaAppBar.dropdown(...), bottomNavigationBar:, body:)`
- The body is a `Selector<XState, bool>` on `enabled`:
  - disabled → `LunaMessage.moduleNotEnabled`
  - enabled → `LunaPageView` of tabs
- The initial tab comes from `XDatabase.NAVIGATION_INDEX.read()`.

**List page:**
- The `_State` mixes in `LunaScrollControllerMixin` / `LunaLoadCallbackMixin`, plus `AutomaticKeepAliveClientMixin` for tabs.
- The body is `LunaRefreshIndicator` → `FutureBuilder`, with one widget per state:
  - error → `LunaLogger().error(...)` + `LunaMessage.error(onTap: refresh)`
  - loading → `LunaLoader()`
  - empty → `LunaMessage(text: 'x.NoFoo'.tr(), buttonText: 'lunasea.Refresh'.tr())`
  - data → `LunaListViewBuilder`

## State management: Provider + ChangeNotifier

`lib/system/state.dart`:

```dart
abstract class LunaModuleState extends ChangeNotifier { void reset(); }
static MultiProvider providers({required Widget child}) => MultiProvider(providers: [
  ChangeNotifierProvider(create: (_) => DashboardState()), ... SettingsState, SearchState, LidarrState,
  RadarrState, SonarrState, NZBGetState, SABnzbdState, TautulliState, TracearrState ], child: child);
static void reset([BuildContext? context]) => LunaModule.values.forEach((m) => m.state(ctx)?.reset());
```

Each module state:
- calls `reset()` in its constructor
- in `resetProfile()`, copies `LunaProfile.current.<x>Enabled/Host/Key/Headers` into fields and builds the API client, or sets it to null when the module is disabled
- caches `Future`s (`_movies`, `_tags`) behind `fetchX()` methods that call `notifyListeners()`

In the UI, use `context.read<RadarrState>()` for one-off access and `context.watch<RadarrState>().tags` to rebuild on change.

`LunaState.reset()` runs:
- on a profile switch (`utils/profile_tools.dart`)
- after a backup import (`database/config.dart`)
- from Settings → System

**After you edit connection fields**, call `context.read<XState>().reset()`.

`provider` is **not declared in pubspec**. It comes in transitively and is re-exported via `vendor.dart` / `core.dart`.

## Routing: go_router, driven by enums

`lib/router/router.dart`:

```dart
router = GoRouter(navigatorKey: navigator, errorBuilder: (_, s) => ErrorRoutePage(exception: s.error),
  initialLocation: LunaRoutes.initialLocation, routes: LunaRoutes.values.map((r) => r.root.routes).toList());
```

**Route definitions:**
- `lib/router/routes.dart` defines `enum LunaRoutes { bios(...), dashboard(...), ..., tracearr('tracearr', root: TracearrRoutes.HOME) }`, with one entry per module.
- `mixin LunaRoutesMixin on Enum` requires `path`, `module`, `routes` and `isModuleEnabled(context)`. `subroutes` is optional.
- `route(widget:|builder:)` automatically shows `NotEnabledPage` when the module is disabled.
- Route names follow the pattern `'<module.key>:<EnumName>'`.
- Only `HOME` has an absolute path (`'/radarr'`). Children use relative paths (`'movie/:movie'`) nested through `subroutes`.

**Navigating and reading parameters:**

```dart
RadarrRoutes.MOVIE.go(params: {'movie': id.toString()});      // pushNamed
RadarrRoutes.QUEUE.go(buildTree: true);                        // goNamed (used by webhooks/deeplinks)
state.pathParameters['movie']; state.uri.queryParameters['q']; state.extra as RadarrMovie?;
```

**`extra` is lost on web refresh and on deep links.** Routes that rely on it must handle `null`. `router/routes/tracearr.dart` does this with `_MissingExtraMessage`.

## API clients: four styles

1. **Retrofit + json_serializable (modern; preferred for new code)**: `api/tracearr`, `api/sabnzbd`, `api/nzbget`.
   ```dart
   part 'api.g.dart';
   @RestApi()
   abstract class TracearrService {
     factory TracearrService(Dio dio, {String baseUrl}) = _TracearrService;
     @GET('/streams') Future<TracearrStreamsResponse> streams({@Query('serverId') String? serverId});
     @POST('/streams/{id}/terminate')
     Future<TracearrTerminateStreamResponse> terminateStream(@Path('id') String id, @Body() TracearrTerminateStreamBody body);
   }
   ```
   `TracearrAPI` builds the Dio client with `baseUrl: '$host/api/v1/public'`, an `Authorization: Bearer` header and the user's custom headers, then exposes `.service`. NZBGet uses a Dio interceptor that rewrites calls into JSON-RPC.
2. **Hand-written "commands"** (a `library` split into `part` files): `api/radarr`, `api/tautulli`.
   ```dart
   // api/radarr/commands/tag/add_tag.dart
   part of radarr_commands;
   Future<RadarrTag> _commandAddTag(Dio client, {required String label}) async {
     Response response = await client.post('tag', data: {'label': label});
     return RadarrTag.fromJson(response.data);
   }
   ```
   `RadarrAPI` builds Dio with `baseUrl: host/api/v3/` and `queryParameters: {'apikey': key}`, then exposes `.tag`, `.movie`, `.queue` and so on (`RadarrCommandHandler<Group>`).
3. **"Controllers"**: `api/sonarr/controllers/*.dart`, e.g. `SonarrControllerTag`. Same shape as the commands style.
4. **Legacy in-module APIs**: `modules/lidarr/core/api/api.dart`, which parses responses by hand.

**Models** use `@JsonSerializable(explicitToJson: true, includeIfNull: false)` plus `part 'x.g.dart'`, `fromJson` and `toJson`, and a `toString` that returns JSON. Tracearr models also use `@JsonKey(unknownEnumValue: ...)` and a tolerant `intFromJson` converter, because the server sends some numbers as strings.

## Networking

`system/network/network.dart` uses conditional imports.

On IO platforms it installs an `HttpOverrides` that:
- **skips certificate validation unless** `LunaSeaDatabase.NETWORKING_TLS_VALIDATION` is true. The default is false.
- sets the User-Agent.

This override is not supported on web. Every API client passes the profile's custom headers to Dio.

## Notifications, webhooks, deep links

**Notifications:**
- There is no Firebase. Notifications are delivered by ntfy via `lunasea-notification-service`.
- `system/webhooks.dart`: `LunaWebhooks.supportedModules` = {LIDARR, RADARR, SONARR, TAUTULLI, OVERSEERR}.
- `buildTopicURL(module)` returns `'<NOTIFICATIONS_SERVICE_URL>/v1/<module.key>/<NOTIFICATIONS_TOPIC>'`. Users paste that URL into their *arr instances.
- Users configure this in `modules/settings/routes/configuration_notifications/route.dart`.

**Deep links:**
- `system/deeplinks/deeplinks.dart` (`LunaDeepLinks`, built on `app_links`) handles `lunasea://<module>?event=...&...`. These are the ntfy click URLs built by the service.
- The flow is `LunaModule.fromKey(uri.host)` → `module.handleWebhook(queryParameters)`. Each module's `core/webhooks.dart` then maps the event string to a navigation, e.g. `'Download'` → `RadarrRoutes.QUEUE.go(buildTree: true)`.

## Platform abstraction pattern

Used by `system/{network,filesystem,quick_actions,window_manager,cache/image}` and `api/wake_on_lan`:

```dart
// ignore: always_use_package_imports
import 'platform/x_stub.dart' if (dart.library.io) 'platform/x_io.dart' if (dart.library.html) 'platform/x_html.dart';
abstract class LunaX { static bool get isSupported => isPlatformSupported(); factory LunaX() => getX(); ... }
```

Callers always guard with `if (LunaX.isSupported)`.

`LunaFileSystem` uses the **file_picker 12 static API**:
- **Desktop:** `FilePicker.saveFile(fileName:, bytes:, lockParentWindow: true)`. This call writes the file itself.
- **Mobile:** write to the temp dir, then share with `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`.

## Theme and UI kit

- **Theme:** `LunaTheme` is Material 2 (`useMaterial3: false`) and dark only. It has two variants: "midnight" and AMOLED black.
- **Colours:** `LunaColours` (British spelling):
  - `accent 0xFF4ECCA3`
  - `primary 0xFF32323E`
  - `secondary 0xFF282834`
- **Constants:** `LunaUI` in `widgets/ui.dart` holds `FONT_SIZE_H1..H5`, `BORDER_RADIUS 10`, `DEFAULT_MARGIN_SIZE 12`, `MARGIN_*`, `ANIMATION_SPEED 250`, `TEXT_BULLET`, `TEXT_EMDASH`.
- **Shared widgets** (always reuse these instead of raw Material equivalents):

| Group | Widgets |
|---|---|
| Page structure | `LunaScaffold`, `LunaAppBar` (`.dropdown`), `LunaDrawer`, `LunaPageView` |
| Lists and blocks | `LunaBlock`, `LunaListView`, `LunaListViewBuilder`, `LunaHeader`, `LunaTableCard`, `LunaBanner` |
| Status and feedback | `LunaMessage` (`.error`, `.goBack`, `.moduleNotEnabled`), `LunaLoader`, `LunaRefreshIndicator` |
| Controls | `LunaButton`, `LunaIconButton`, `LunaSwitch` |
| Dialogs and sheets | `LunaDialog`, `LunaBottomModalSheet`, `LunaDialogs().editText(...)` (returns `Tuple2<bool,String>`) |
| Snackbars | `showLunaSuccessSnackBar`, `showLunaErrorSnackBar` |

- **Icons:** `LunaIcons` (`widgets/ui/icons/icon.dart`) uses the `LunaBrandIcons` font. `LunaAssets` (`widgets/ui/assets.dart`) is generated by spider and committed.

## Localization

- The library is `easy_localization`. Look up strings like `'radarr.NoTagsFound'.tr()` or `'settings.EnableModule'.tr(args: [title])`.
- **Source files:** `localization/<module>/<lang>.json`. There are 13 module folders and up to 19 languages. `tracearr/` has only `en.json`.
- **Build step:** `scripts/generate_localization.dart` wipes `assets/localization/` and rebuilds it by merging every module file into `assets/localization/<lang>.json`. The merged output is **committed**.
- Keys are flat and prefixed with the module name: `"dashboard.Calendar"`, `"lunasea.Refresh"`.
- **Only `Locale('en')` is registered** in `supportedLocales`, so the other languages ship but cannot be selected.

## Logging and errors

**Logging:** `LunaLogger` (`system/logger.dart`) writes `LunaLog` entries to the Hive `logs` box. It keeps the newest 50 at boot.
- Methods: `debug`, `warning(msg, className, methodName)`, `error(msg, error, stack)`, `critical`, `exception(LunaException)`.
- Users can view and export logs at Settings → System → Logs.

**Errors:**
- `types/exception.dart` defines `abstract class LunaException { LunaLogType get type; }` plus `WarningExceptionMixin` and `ErrorExceptionMixin`.
- Uncaught errors go through `FlutterError.onError` → the zone → `critical`.
- If bootstrap fails, the app shows `LunaRecoveryMode`, which lets the user retry or clear the database.

## Flavors

`LunaFlavor` (EDGE / BETA / STABLE) comes from `LunaEnvironment.flavor` in the **generated** `lib/system/environment.dart`.

- The value is baked in from the `FLAVOR` **env var** when `dart run environment_config:generate` runs. The default is `edge`.
- The `--dart-define=FLAVOR=...` flags that CI passes do nothing, because nothing calls `String.fromEnvironment`.

## Web specifics

**Unsupported on web:** `LunaNetwork`, quick actions, window manager, image cache and deep links.

**Also note:**
- Wasm needs the COOP/COEP headers set in `nginx/default.conf`.
- go_router `extra` is lost when the page refreshes.
- Tracearr images are host-relative. Use `TracearrState.resolveImageUrl()` and `imageHeaders`.

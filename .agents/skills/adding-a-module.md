# Skill: Add a New Service Module to the Flutter App

Use this when you integrate a new self-hosted service (the example below calls it "foo") into
`lunasea/`. The reference implementation is the Tracearr module, added in commit `bc2a9b6`.
Copy its structure file by file.

Expect about 15 files to change. The compiler's exhaustive-switch errors in `lib/modules.dart`
will list the remaining sites for you.

## Checklist

1. **Write the API client in `lunasea/lib/api/foo/`.**
   - `foo.dart`: `class FooAPI` builds a `Dio` with the base URL, auth (a Bearer header or an `apikey` query param) and the profile's custom headers. It exposes `.service`.
   - `api.dart`: `@RestApi() abstract class FooService { factory FooService(Dio dio, {String baseUrl}) = _FooService; ... }` with `part 'api.g.dart';`.
   - `models/*.dart`: `@JsonSerializable(explicitToJson: true, includeIfNull: false)` classes with `part '*.g.dart'`, `fromJson`, `toJson`, and a `toString` that returns JSON.
   - `models.dart` and `types.dart`: barrel files.
   - Use `@JsonKey(unknownEnumValue: ...)` for server enums, and tolerant converters where the server is inconsistent (see `api/tracearr/utils/converters.dart`).

2. **Add the module to `lunasea/lib/modules.dart`.**
   - `const MODULE_FOO_KEY = 'foo';`
   - `@HiveField(13) FOO(MODULE_FOO_KEY)`. Use the next unused field, which is 13 today. **Never renumber existing fields.**
   - Add `fromKey`.
   - Fill in every switch the compiler flags: `isEnabled`, `title`, `icon`, `color`, `website`, `github`, `description`, `information`, `homeRoute`, `settingsRoute`, `state()` and `shortcutItem`. Add `featureFlag` if you need to gate the module, and the webhook switches if the module sends webhooks.

3. **Add profile fields in `lunasea/lib/database/models/profile.dart`.**
   - Add `fooEnabled`, `fooHost`, `fooKey` and `fooHeaders`. Each gets `@JsonKey()` and `@HiveField(48..51, defaultValue: ...)`, since the next free index is 48.
   - Add each field to **both** the `_internal` constructor and the public factory, with defaults in the factory.

4. **Create the settings table.**
   - New file `lunasea/lib/database/tables/foo.dart`:
     ```dart
     enum FooDatabase<T> with LunaTableMixin<T> {
       NAVIGATION_INDEX<int>(0), REFRESH_RATE<int>(15);
       @override LunaTable get table => LunaTable.foo;
       @override final T fallback;
       const FooDatabase(this.fallback);
     }
     ```
   - In `lunasea/lib/database/table.dart`, add `foo<FooDatabase>('foo', items: FooDatabase.values)`.

5. **Create the module state.**
   - New file `lunasea/lib/modules/foo/core/state.dart`: `class FooState extends LunaModuleState`.
     - The constructor calls `reset()`.
     - `reset()` calls `resetProfile()` and then `notifyListeners()`.
     - `resetProfile()` reads `LunaProfile.current.foo*` and builds `FooAPI`, or sets it to null when the module is disabled.
   - In `lunasea/lib/system/state.dart`, add `ChangeNotifierProvider(create: (_) => FooState())`.

6. **Add the barrel.** `lunasea/lib/modules/foo.dart` exports the table and the state.

7. **Add routes.**
   - New file `lunasea/lib/router/routes/foo.dart`: `enum FooRoutes with LunaRoutesMixin { HOME('/foo'), DETAILS('item/:id'); ... }`.
     - `module` returns `LunaModule.FOO`.
     - `isModuleEnabled` returns `context.read<FooState>().enabled`.
     - Implement the `routes` switch and `subroutes`.
   - In `lunasea/lib/router/routes.dart`, add `foo('foo', root: FooRoutes.HOME)`.

8. **Build the pages** in `lunasea/lib/modules/foo/routes/<page>/route.dart`, with a `widgets/` folder alongside.
   - Copy `modules/tracearr/routes/home/route.dart`: `LunaScaffold` with `module:` and `drawer:`, a `Selector` on `enabled`, and `LunaPageView`.
   - List pages use `LunaRefreshIndicator`, `FutureBuilder`, `LunaLoader`, `LunaMessage` and `LunaListViewBuilder`.

9. **Build the settings UI.**
   - `lunasea/lib/modules/settings/routes/configuration_foo/route.dart`: copy `configuration_tracearr`. It needs an enable switch and host/key tiles, and each change calls `LunaProfile.current.save()` and then `context.read<FooState>().reset()`.
   - In `lunasea/lib/router/routes/settings.dart`, add `CONFIGURATION_FOO('foo')` with its `routes` case, and add it to HOME's `subroutes`.
   - In `lunasea/lib/modules/settings/core/pages/headers.dart`, add the headers cases.

10. **Add localization.** Create `lunasea/localization/foo/en.json` with flat keys: `{"foo.NoItemsFound": "No Items Found", ...}`.

11. **Regenerate and commit.**
    ```bash
    cd lunasea
    dart scripts/generate_localization.dart
    dart run build_runner build
    flutter analyze
    ```
    Commit `assets/localization/*.json`. Do **not** commit `*.g.dart`, because those files are gitignored.

12. **Optional extras:**
    - Webhooks: add `modules/foo/core/webhooks.dart` extending `LunaWebhooks`, add FOO to `LunaWebhooks.supportedModules`, and update the `hasWebhooks` / `handleWebhook` switches. The server side needs a matching module in `lunasea-notification-service` (see `.agents/docs/notification-service.md`).
    - Quick action: add a `LunaSeaDatabase.QUICK_ACTIONS_FOO` entry.
    - Docs: add `docs/modules/foo.md` with Just the Docs front matter (`parent: Modules`).

## Verify

- `flutter analyze` is clean.
- The app boots and the module appears in the drawer after you enable it in Settings.
- Switching profiles resets the state, because `LunaState.reset()` iterates all `LunaModule` values.
- A backup export includes `FOO_*` keys and the new profile fields.

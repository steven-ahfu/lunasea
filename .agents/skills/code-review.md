# Skill: Code Review Checklist for LunaSea

There is no CI on pull requests, so review is the only gate. Check these items, most important first.

## Flutter app (`lunasea/`)

1. **Hive compatibility**
   - Never reuse or change a `typeId`. The next free typeId is 30.
   - Never reuse or change a `@HiveField` index. The next free index is 13 in `LunaModule` and 48 in `LunaProfile`.
   - New fields carry a `defaultValue`.
   - Retired types stay as placeholders in `deprecated.dart`.
   - No `LunaTable` enum value or table key was renamed. A rename silently resets user settings and breaks old backups.
2. **Generated code**
   - The PR does not commit `*.g.dart` files or `lib/system/environment.dart`, because both are gitignored.
   - The PR **does** commit `assets/localization/*.json` whenever `localization/**` changed.
   - The PR commits `lib/widgets/ui/assets.dart` whenever `assets/images` changed.
3. **Exhaustive module wiring**
   - A new `LunaModule` value is handled in every extension switch, and also in `system/state.dart`, `router/routes.dart`, `database/table.dart`, the settings routes and `settings/core/pages/headers.dart`.
4. **State reset**
   - Settings screens that edit connection fields call `LunaProfile.current.save()` and then `context.read<XState>().reset()`.
5. **Routing**
   - New routes are added to the parent's `subroutes`.
   - Child paths are relative.
   - Routes that read `state.extra` handle `null`, which happens after a web refresh or a deep link.
6. **Imports**
   - Use `package:lunasea/...`; the `always_use_package_imports` lint enforces this.
   - Prefer direct imports over the deprecated `lib/core.dart` barrel in new code.
   - Platform-conditional imports use the `_stub`/`_io`/`_html` pattern with the `// ignore:` comment.
7. **Platform guards**
   - Use `LunaNetwork`, `LunaWindowManager`, `LunaImageCache`, `LunaDeepLinks`, `LunaQuickActions` and `LunaWakeOnLAN` only behind `isSupported`.
   - Web must not crash.
8. **UI consistency**
   - Use `Luna*` widgets (`LunaScaffold`, `LunaBlock`, `LunaMessage`, `LunaLoader`, and so on) and the `LunaUI` / `LunaColours` constants rather than raw Material widgets and magic numbers.
   - User-facing strings go through `'<module>.Key'.tr()`.
9. **Errors**
   - API failures are logged with `LunaLogger().error(msg, error, stack)` and shown with `LunaMessage.error` or `showLunaErrorSnackBar`.
   - No silent `catch (_) {}`.
10. **Security**
    - Never log API keys, headers or ntfy tokens.
    - Remember that TLS validation is **off** by default (`NETWORKING_TLS_VALIDATION`), so do not add code that assumes certificates are verified.
11. **Dependencies**
    - Respect the pinned versions and the comments in `pubspec.yaml`: `file_picker` beta 12, `xml ^6`, `hive_ce_generator ^1.11.1`.
    - A Flutter version bump must update all 5 pins: the 4 workflows plus `lunasea/Dockerfile`.

## Notification service (`lunasea-notification-service/`)

1. A new module is registered in `src/modules/index.ts`, and its controller uses `Middleware.extractTopic`.
2. A new event is added in all three places: the `models.ts` enum, a `payloads.ts` function, and the controller `case`.
3. Payloads that should deeplink into the app set `data.module`, which must match a `LunaModule` key, plus an `event` that the app's `core/webhooks.dart` handles.
4. A new env var is added in all four places: `utils/environment.ts` (redacted if secret), `.env.sample`, the README table, and the root `docker-compose.yml`.
5. `npm run lint` and `npm run build` pass. There are no tests.
6. Webhook bodies and headers are not logged at `info` level.

## Infra

1. Workflow changes go in the **root** `.github/workflows/`. The nested `.github` directories are inactive.
2. Dockerfiles keep the hardening:
   - the images run as non-root
   - the root `docker-compose.yml` sets `read_only`, `cap_drop: ALL` and `no-new-privileges` on its services
3. The distroless runtime has no shell and no `wget`.
4. No `*.jks`, `*.keystore`, `key.properties` or `.env` files are committed.

## Commits

- Commits use Conventional Commits.
- The app's `.commitlintrc` allows only `chore`, `docs`, `feat`, `fix`, `refactor` and `release`.
- History also uses `ci`, `deps` and `build`.
- Scopes such as `(notif)`, `(android)` and `(web)` are common.

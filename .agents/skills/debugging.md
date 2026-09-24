# Skill: Debugging LunaSea

## Flutter app

| Symptom | Likely cause | Fix |
|---|---|---|
| Hundreds of "Target of URI doesn't exist: '*.g.dart'" errors, or `LunaEnvironment` undefined | Codegen has not run. Generated files are gitignored | `cd lunasea && FLAVOR=edge dart run environment_config:generate && dart scripts/generate_localization.dart && dart run build_runner build` |
| `HiveError: Cannot read, unknown typeId` or `There is already a TypeAdapter for typeId N` | A typeId collision, or a deleted adapter | See `.agents/docs/database-schema.md`. Use the next free ID (30). Keep a placeholder in `deprecated.dart` for any retired ID |
| App opens straight into Recovery Mode | `bootstrap()` threw, usually because Hive failed to open or an adapter is missing | Check the adapter registration in the table's `register()` and in `LunaSeaDatabase.register()`. Use "Clear database" in recovery mode as a last resort |
| A setting "resets" after an update | A table enum value or `LunaTable` key was renamed, which changes the storage key `<TABLE>_<NAME>` | Restore the old name |
| New strings show the raw key (`foo.MyKey`) | `assets/localization` was not regenerated | `dart scripts/generate_localization.dart`, then commit `assets/localization/*.json` |
| A translation is never shown | Only `Locale('en')` is registered in `main.dart` | Expected behaviour. English is used |
| Page shows "module not enabled" | `isModuleEnabled` reads state, and the state was not reset after the settings change | Call `context.read<XState>().reset()` after `LunaProfile.current.save()` |
| Detail page is blank after a web refresh or deep link | go_router `extra` was lost | Handle `state.extra == null`, e.g. with `_MissingExtraMessage` in `router/routes/tracearr.dart`, or fetch by ID |
| Web build falls back to JS, or Wasm fails | COOP/COEP headers or the `.mjs` MIME type are missing | Serve through `lunasea/nginx/default.conf` (Docker image) |
| Remote images are blocked on web | COEP `require-corp` | The image host must send CORP or CORS headers |
| Flavor shows EDGE in a "stable" build | `FLAVOR` env var was unset during `environment_config:generate`. `--dart-define` is ignored | Export `FLAVOR=stable` **before** running codegen |
| Android release build fails on signing | `android/key.properties` is missing | Use `flutter build apk --debug`, or create `key.properties` from `key.properties.sample` |
| Save file does nothing on desktop | file_picker 12 API change | Use `FilePicker.saveFile(bytes: ..., lockParentWindow: true)`. It writes the file itself (commit `99d3578`) |

In-app logs are at Settings → System → Logs, stored in the Hive `logs` box and capped at 50 entries. Log with
`LunaLogger().error('msg', error, stack)` and `LunaLogger().warning(msg, className, methodName)`.

## Notification service

Run it locally with pretty logs:

```bash
cd lunasea-notification-service && cp .env.sample .env   # fill the 3 required vars
npm ci && npm run start:dev
curl -X POST localhost:9000/v1/radarr/test-topic -H 'Content-Type: application/json' -d '{"eventType":"Test"}'
```

| Symptom | Cause |
|---|---|
| Process exits right away with "Unable to find environment value" | A required env var is empty. Validation happens at import time in `src/utils/environment.ts` |
| Caller gets 200 but no push arrives | The handler responds before processing. Check the logs for a `warn` ("unknown EventType"), ntfy errors, or a TypeError from a missing JSON body (no `Content-Type: application/json`) |
| 401 on `/v1/*` | `WEBHOOK_TOKEN` is set and the caller did not send `Authorization: Bearer <token>` |
| Compose reports `notifications` unhealthy | The compose healthcheck uses `wget`, which the distroless image does not have. The service itself is fine |
| iOS gets no pushes from a self-hosted ntfy | The ntfy server needs `upstream-base-url`, or its own APNs setup |
| Push arrives without a poster | TMDB or fanart lookup failed and was logged. Overseerr and custom payloads never have a click deeplink |

## CI

- **Nothing runs on push or PR.** Workflows run only when a release is published, or from `workflow_dispatch`.
- **Docker job pushes no tags.** The release tag was not semver. Use `vX.Y.Z`.
- **Android APKs will not upgrade in place.** The four `ANDROID_KEYSTORE_*` secrets are missing, so CI generated a throwaway key.

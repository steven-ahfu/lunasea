# Notification Service: Deep Dive

Path: `lunasea-notification-service/`

## What it is

A TypeScript + Express 5 HTTP service. It receives webhooks from Sonarr, Radarr, Lidarr,
Tautulli, Overseerr and a generic "custom" source. It turns each webhook into a notification
and publishes it to a self-hosted **ntfy** server.

This is the "ntfy edition" fork of the upstream LunaSea notification service. Firebase/FCM and
Redis were removed. There is no database. The only cache is in-process (`lru-cache`).

```
Sonarr/Radarr/... --POST webhook--> [notification-service :9000] --POST JSON--> ntfy --> devices
                                           |
                                           +--> TMDB (posters, cached 7d) / fanart.tv (artist thumbs)
```

Modules that exist: `custom`, `lidarr`, `overseerr`, `radarr`, `sonarr`, `tautulli`.
**There is no Tracearr module** here, even though the Flutter app and docs have a Tracearr module.

License: GPL-3.0-only.

## Tooling

| Item | Value |
|---|---|
| Node | `engines.node >=24`; Docker uses `node:24-alpine` build → `gcr.io/distroless/nodejs24-debian12:nonroot` runtime |
| Language | TypeScript `^6`, `strict: true`, `module/moduleResolution: node16` (emits CommonJS), target es2022, `rootDir: src`, `outDir: dist` |
| HTTP | `express ^5` |
| HTTP client | `axios` (ntfy, TMDB, fanart.tv) |
| Logging | `pino` (JSON to stdout); `pino-pretty` for dev |
| Env | `dotenv`, preloaded via `-r dotenv/config` (never imported in code) |
| Lint | ESLint 10 flat config (`eslint.config.js`) + `typescript-eslint` recommended; `no-explicit-any` off |
| Format | Prettier: single quotes, semicolons, trailing commas, width 100, 2 spaces, LF |
| Tests | **None.** No framework, no `test` script |

### Scripts (`package.json`)

| Script | What it does |
|---|---|
| `npm start` | `nodemon` + `ts-node -r dotenv/config src/index.ts`, `NODE_ENV=development` (debug logs) |
| `npm run start:dev` | Same, piped through `pino-pretty` |
| `npm run build` | `tsc` → `dist/` |
| `npm run serve` | `NODE_ENV=production node -r dotenv/config dist/index.js` |
| `npm run lint` | `eslint "src/**/*.ts"` |
| `npm run format` | `prettier --write` on ts/js/json/md |

## Environment variables

Defined and validated in `src/utils/environment.ts`. Template: `.env.sample`.

| Var | Required | Default | Purpose |
|---|---|---|---|
| `NTFY_BASE_URL` | yes | none | ntfy server base URL. Messages POST to `/` |
| `FANART_TV_API_KEY` | yes (redacted in logs) | none | Lidarr artist images |
| `THEMOVIEDB_API_KEY` | yes (redacted) | none | Sonarr/Radarr/Overseerr posters (TMDB v3) |
| `NTFY_TOKEN` | no | none | ntfy `Authorization: Bearer`. Wins over basic auth |
| `NTFY_USERNAME` / `NTFY_PASSWORD` | no | none | ntfy basic auth. Used only if both are set and no token |
| `WEBHOOK_TOKEN` | no | none | If set, every `/v1/*` request needs `Authorization: Bearer <token>` or gets 401 |
| `PORT` | no | `9000` | Listen port |
| `NODE_ENV` | implicit | none | `development` → pino level `debug`, else `info` |

Validation runs **at import time**. The `_Var` constructor calls `process.exit(1)` when a required
variable is missing or empty:

```ts
// src/utils/environment.ts
export const NTFY_BASE_URL = new _Var('NTFY_BASE_URL');
export const NTFY_TOKEN = new _Var('NTFY_TOKEN', { redacted: true, optional: true });
export const PORT = new _Var('PORT', { fallback: '9000' });
```

A new env var needs updates in 4 places: `environment.ts`, `.env.sample`, the service `README.md`
table, and the root `docker-compose.yml` `notifications.environment` block.

## Source layout

```
src/
  index.ts                  Entry: Ntfy.initialize(); Server.start();
  server/
    server.ts               express.json(), GET /, GET /health, mount /v1, listen(PORT)
    middleware.ts           startNewRequest, checkWebhookAuth, extractTopic, extractNotificationOptions
    models.ts               interface Response { message: string }
  modules/
    index.ts                /v1 router: shared middleware, then <Module>.enable(router)
    <svc>/index.ts          export { Controller, Models, Payloads }
    <svc>/controller.ts     route + handler + switch on event discriminator
    <svc>/models.ts         EventType enum + payload interfaces
    <svc>/payloads.ts       one async fn per event → Notifications.Payload
  services/ntfy/index.ts    axios client, auth mode selection, publish()
  api/the_movie_db/         api.ts (raw calls), cache.ts (LRU), index.ts (cache-then-API, builds image URL)
  api/fanart_tv/index.ts    getArtistThumbnail (getAlbumCover exists but is unused and buggy)
  utils/
    constants.ts            MESSAGE strings, CACHE ttl/size, TMDB URLs
    environment.ts          _Var env validation
    logger.ts               pino root logger + uncaughtException/unhandledRejection loggers
    notifications.ts        Payload, Settings, iOSInterruptionLevel, toNtfyPriority, generateTitle, buildClickUrl
```

Barrel files (`index.ts`) re-export namespaces. Code imports like
`import { Constants, Logger, Notifications } from '../../utils';` and uses `Notifications.Payload`.

## Startup

1. Imports run first:
   - `utils/logger.ts` creates the pino logger.
   - `utils/environment.ts` validates env and can exit.
   - `api/*` creates the axios instances with API keys baked in.
   - `modules/*` builds the routers.
2. `Ntfy.initialize()` creates the ntfy axios client (10 s timeout) and picks auth `token` | `basic` | `none`.
3. `Server.start()` registers routes and calls `listen(PORT)`. A listen error exits with code 1.

## Endpoints

| Method | Path | Auth | Query | Behavior |
|---|---|---|---|---|
| GET | `/` | none | none | 301 → `https://dim145-lunasea.gitbook.io/dim145-lunasea` |
| GET | `/health` | none | none | `200 {"status":"OK","version":<npm_package_version>}` |
| POST | `/v1/custom/:topic` | `WEBHOOK_TOKEN` if set | `sound`, `interruption_level` | Body `{title, body, image}` → ntfy as is |
| POST | `/v1/radarr/:topic` | same | `profile`, `sound`, `interruption_level` | switch on `eventType` |
| POST | `/v1/sonarr/:topic` | same | same | switch on `eventType` |
| POST | `/v1/lidarr/:topic` | same | same | switch on `eventType` |
| POST | `/v1/overseerr/:topic` | same | same | switch on `notification_type` |
| POST | `/v1/tautulli/:topic` | same | same | switch on `action`, falls back to deprecated `event_type` |

### Middleware on every `/v1/*` request, in this order (`src/modules/index.ts`)

```ts
router.use(Middleware.startNewRequest);            // log url + method
router.use(Middleware.checkWebhookAuth);           // Bearer WEBHOOK_TOKEN (no-op if unset)
router.use(Middleware.extractNotificationOptions); // ?sound (default true), ?interruption_level
```

`extractTopic` is attached per route inside each controller. It sets:
- `response.locals.topic` from the `:topic` path segment
- `response.locals.profile` from `?profile`, default `'default'`

### Controller pattern (every module)

```ts
// src/modules/radarr/controller.ts
export const enable = (api: express.Router) => api.use(route, router);
const logger = Logger.child({ module: 'radarr' });
const router = express.Router();
const route = '/radarr';
router.post('/:topic', Middleware.extractTopic, handler);

async function handler(request, response) {
  try {
    response.status(200).json({ message: Constants.MESSAGE.OK });  // respond FIRST
    await _handleWebhook(request.body, response.locals.topic,
                         response.locals.profile, response.locals.notificationSettings);
  } catch (error) { logger.error(error); response.status(500).json(...); }
}
```

`_handleWebhook` switches on the discriminator. Each case calls `Payloads.<fn>(data, profile)`,
then runs `if (payload) await Ntfy.publish(topic, payload, settings);`. Unknown events log a
warning and are dropped.

## Notification model (`src/utils/notifications.ts`)

```ts
interface Payload { title: string; body: string; image?: string; data?: { [key: string]: string } }
interface Settings { sound: boolean; ios: { interruptionLevel: iOSInterruptionLevel } }
```

- **Priority** (`toNtfyPriority`):
  - `sound=false` → 1.
  - Otherwise `passive` → 2, `active` → 3 (default), `time-sensitive` → 4.
- **Title** (`generateTitle`): `"<Module>: <body>"`, or `"<Module> (<profile>): <body>"` when the profile is not `default`.
- **Click URL** (`buildClickUrl`): `lunasea://<data.module>?<other data keys>`. It is only built when `data.module` is set. The Flutter app must handle the `lunasea://` scheme.

### ntfy publish (`src/services/ntfy/index.ts`)

The service uses the ntfy JSON publish API: `POST /` with a body like
`{ topic, title, message, priority, attach?, icon?, click? }`.

- The image URL goes into both `attach` and `icon`.
- The topic is exactly the URL `:topic`. Anyone who knows the topic can publish to it.
- `publish()` never throws. It logs the error and returns `false`, and no caller checks that return value.

## Per-module behavior

| Module | Discriminator | Events | Image source | Deeplink `data` |
|---|---|---|---|---|
| radarr | `eventType` | Download, Grab, Health, Rename, MovieDelete, MovieFileDelete, Test | TMDB `movie/{tmdbId}` | module, profile, event, id |
| sonarr | `eventType` | Download, EpisodeFileDelete, Grab, Health, Rename, SeriesDelete, Test | TMDB `find/{tvdbId}?external_source=tvdb_id` | module, profile, event, seriesId, seasonNumber |
| lidarr | `eventType` | Test, Grab, Rename, Retag, Download | fanart.tv `music/{mbId}` artistthumb | module, profile, event, artistId(, albumId) |
| overseerr | `notification_type` | MEDIA_{APPROVED,AUTO_APPROVED,AVAILABLE,DECLINED,FAILED,PENDING}, ISSUE_{CREATED,RESOLVED,REOPENED,COMMENT}, TEST_NOTIFICATION | TMDB movie or series | **none** (no click link) |
| tautulli | `action` (modern, nested `data`), fallback `event_type` (deprecated, flat) | buffer, error, pause, resume, play, stop, ext/int up/down, pmsupdate, created, watched, newdevice, concurrent, test… | Tautulli's `poster_url` | module, profile, event, user_id, session ids |
| custom | none | none | `body.image` | none |

The Tautulli body uses `data.message` when it is present. Otherwise the service generates a sentence such as
`"<user> (<player>) started playing <title>"`. `tautulli/payloads.ts` is about 800 lines and covers both formats.

## Caching and external APIs

- **TMDB**: base `https://api.themoviedb.org/3/`.
  - The `api_key` is a default axios param.
  - The cache holds the poster path in `LRUCache({ max: 5000, ttl: 7 days })`, keyed `tmdb:movie:<id>` / `tmdb:series:<id>`. It is lost on restart.
  - Returned image URLs look like `https://image.tmdb.org/t/p/w780<path>`.
- **fanart.tv**: base `http://webservice.fanart.tv/v3/`. Note it is plain HTTP, and results are not cached.

## Recipes

### Add a new webhook module (e.g. `tracearr`)

1. Copy `src/modules/radarr/` to `src/modules/<svc>/`.
2. In `models.ts`, define `export enum EventType {...}` and the payload interfaces. Make fields optional.
3. In `payloads.ts`, write one async function per event:
   ```ts
   const title = (profile: string, body: string) => Notifications.generateTitle('<Svc>', profile, body);
   const moduleKey = '<svc>';
   export const test = async (data: Models.TestEventType, profile: string): Promise<Notifications.Payload> => ({
     title: title(profile, 'Connection Test'),
     body: 'LunaSea is ready for <Svc> notifications!',
     data: { module: moduleKey, profile, event: data.eventType! },
   });
   ```
4. In `controller.ts`, change `route`, the logger module name, and the `switch`.
5. In `index.ts`, write `export { Controller, Models, Payloads };`.
6. Register the module in `src/modules/index.ts` with `import { Controller as Svc } from './<svc>';` and `Svc.enable(router);`.
7. Run `npm run lint && npm run build`.

### Add an event to an existing module

1. Add the enum member plus its interface in `models.ts`.
2. Add a payload function in `payloads.ts`.
3. Add a `case` in the controller `_handleWebhook`.
4. Tautulli only: choose the modern `ActionType` switch or the deprecated `EventTypeDeprecated` switch.

### Manual smoke test

```bash
cp .env.sample .env   # fill NTFY_BASE_URL, FANART_TV_API_KEY, THEMOVIEDB_API_KEY
npm ci && npm run start:dev
curl -X POST localhost:9000/v1/radarr/mytopic -H 'Content-Type: application/json' -d '{"eventType":"Test"}'
```

## Gotchas

1. **200 is sent before processing.** Webhook senders never see failures. If processing throws, the `catch` tries a second response and raises `ERR_HTTP_HEADERS_SENT`.
2. **A missing JSON body crashes the handler.** Without `Content-Type: application/json`, `req.body` is undefined and `data.eventType` throws. Only `custom` uses `data?.`.
3. **`/health` usually has no `version`.** The distroless image runs `node` directly, so `npm_package_version` is undefined. The pino mixin is affected the same way.
4. **Root `docker-compose.yml` healthcheck uses `wget`,** which does not exist in the distroless image, so it always fails. The Dockerfile `HEALTHCHECK` uses node, but the compose healthcheck overrides it.
5. **Env vars are read at import time.** API keys are baked into the axios instances, and a missing required var exits from inside an import.
6. **`WEBHOOK_TOKEN` is a plain string compare** and is optional. The ntfy topic is the real secret.
7. **Stale husky hook.** `.husky/pre-commit` uses v4-style `_/husky.sh` and calls `pretty-quick`, which is not installed.
8. **Upstream leftovers.**
   - These still point at `JagandeepBrar/LunaSea-Notification-Service`: `lunasea-notification-service/.github/workflows/build.yaml` (never runs, because GitHub only runs root workflows), the `package.json` `repository` field, and the OCI labels.
   - `.vscode/settings.json` points at the upstream author's local path.
9. **`FanartTV.getAlbumCover` is buggy and unused.**
10. **Overseerr notifications have no `data`,** so they do not deeplink into the app.
11. **Uncaught exceptions are only logged** and do not crash the process.

---

# Legacy: `lunasea-cloud-functions/`

This is a Firebase Cloud Functions project from the original Firebase-backed LunaSea. It is **kept for reference only**, and nothing in this fork depends on it.

- Toolchain: Node 14, `firebase-functions ^3`, `firebase-admin ^10`, TypeScript 4.5, ESLint 8 with the `google` config.
- `.firebaserc` default project: `comettools-lunasea` (upstream's).
- There is one function, `deleteUserController = functions.auth.user().onDelete(...)`:
  - It recursively deletes Firestore `users/<uid>` and its subcollections.
  - It deletes the `<uid>/` prefix in the storage bucket `backup.lunasea.app`.
  - Neither step is fully awaited.
- Scripts in `functions/`: `lint`, `build` (tsc → `lib/`), `serve` (emulator), `deploy` (`firebase deploy --only functions`, which runs lint and build first).

Do not modernize or deploy this project unless asked.

# Build, CI, Docker and Deployment Guide

## Git and repo context

- Remote `origin`: `https://github.com/steven-ahfu/lunasea`. **`master` is the remote default branch.**
- This is a fork of a fork: `JagandeepBrar/lunasea` (upstream, which ended at 11.0.0) → `Dim145/lunasea` → `steven-ahfu/lunasea`.
- The app was re-versioned to `1.2.0`, and the bundle id was renamed `app.lunasea.lunasea` → `app.dim145.lunasea` (commit `83dd00c`, 23 files).
- Commit style is conventional commits: `feat`, `fix`, `chore`, `ci`, `docs`, `build` and `deps`, with scopes such as `(notif)`, `(android)` and `(web)`.
- Cloud-session clones may be shallow, so do not rely on `git rev-list --count`.

## CI: GitHub Actions

**Only `/.github/workflows/*` runs.** These nested dirs are upstream leftovers and are **inactive**:
- `lunasea/.github/` (reusable `JagandeepBrar/lunasea/...@master` workflows, issue templates, FUNDING)
- `lunasea-notification-service/.github/`

Editing them does nothing.

### Common to all 5 root workflows

- **Triggers:** only `release: [published]` and `workflow_dispatch`. **There is no CI on push or PR.** Nothing runs analyze, lint or tests automatically.
- **Node for actions:** `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: 'true'`.
- **Flutter:** `FLUTTER_VERSION: 3.41.9`, stable, via `subosito/flutter-action@v2` (cached). Flutter jobs set `working-directory: lunasea`.
- **Code generation runs before every Flutter build.** Generated files are gitignored, so builds need this step:
  ```yaml
  env: { FLAVOR: stable, COMMIT: ${{ github.sha }}, BUILD: ${{ github.run_number }} }
  run: |
    dart run environment_config:generate
    dart scripts/generate_localization.dart
    dart run build_runner build
  ```
- **Build flags:** `--dart-define=FLAVOR=stable --dart-define=COMMIT=<sha> --dart-define=BUILD=<run_number> --build-number=<run_number>`.
- **Version:** the release `tag_name` with the leading `v` stripped. If there is no tag, the `pubspec.yaml` `version:` without the `+build` part.
- **Outputs:**
  - Staged to `<repo>/output/`.
  - Uploaded with `actions/upload-artifact@v4` (30 days).
  - Attached to the release with `softprops/action-gh-release@v2` when triggered by a release, or by a dispatch with a `release_tag` input.

### Per-workflow

| Workflow | Runner | Output | Secrets |
|---|---|---|---|
| `build-android.yml` | ubuntu, JDK 17 | `lunasea-<ver>-android.apk`, or `-android-unsigned.apk` when an ephemeral key was used | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` |
| `build-ios.yml` | macos (x64 Flutter) | `lunasea-<ver>-ios-unsigned.ipa`: runs `pod install`, `flutter build ios --no-codesign`, then zips `Payload/` | none |
| `build-linux.yml` | ubuntu + GTK deps | `lunasea-<ver>-linux-x86_64.tar.gz` and `lunasea_<ver>_amd64.deb`. The `DEBIAN/control` file is rewritten inline | none |
| `build-macos.yml` | macos (x64 Flutter) | `lunasea-<ver>-macos-unsigned.zip` and `.dmg` | none |
| `build-docker.yml` | ubuntu | GHCR images, Trivy SARIF, SPDX SBOM | `GITHUB_TOKEN` only |

**Android signing:**
- If all four secrets are set, CI writes `android/key.jks` and `android/key.properties`.
- If not, it generates a **throwaway keystore every run**. APKs signed this way cannot upgrade over each other.

### `build-docker.yml`

- **Matrix:**

  | Image | Build context |
  |---|---|
  | `lunasea-web` | `lunasea` |
  | `lunasea-notification-service` | `lunasea-notification-service` |
  | `lunasea-docs` | `docs` |

- **Image name:** `ghcr.io/<owner/repo lowercased>/<image>`, for example `ghcr.io/steven-ahfu/lunasea/lunasea-web`.
- **Tags:**
  - On a release: `{{version}}`, `{{major}}.{{minor}}` and `{{major}}`, plus `latest` unless it is a prerelease. **The release tag must be semver (`vX.Y.Z`).** Otherwise no tags are produced and the push fails.
  - On a dispatch: the `version` input, or a short sha. Add `latest` if `tag_latest` is set (default true).
- **Pipeline:**
  1. Build with `load` as `:scan`.
  2. Trivy scan (CRITICAL/HIGH, `exit-code: 0`, so it never fails) and upload the SARIF.
  3. Generate an SBOM with `anchore/sbom-action`.
  4. Multi-arch push for `linux/amd64,linux/arm64` with `provenance: false`.

### Not built by any active workflow

Windows (`msix_config` in pubspec), Snap (`snap/snapcraft.yaml`), Android AAB and Play Store, and App Store and notarized macOS. The configs and fastlane lanes still exist from upstream.

## Docker

### Root `docker-compose.yml`: reference deployment

Every service is hardened with `read_only`, `cap_drop: [ALL]`, `no-new-privileges`, tmpfs mounts and a healthcheck.

| Service | Build context | Host → container port |
|---|---|---|
| `web` | `./lunasea` | 8080 → 8080 |
| `docs` | `./docs` | 8081 → 8080 |
| `notifications` | `./lunasea-notification-service` | 9000 → 9000 (env: `NTFY_BASE_URL`, `FANART_TV_API_KEY`, `THEMOVIEDB_API_KEY`, plus optional ntfy auth and `WEBHOOK_TOKEN`) |

⚠️ The `notifications` healthcheck uses `wget`, but that image is distroless and has no wget. The compose healthcheck therefore always fails. The Dockerfile's own HEALTHCHECK uses node.

### `lunasea/Dockerfile`: web app

- **Build stage:** `debian:trixie-slim` on `$BUILDPLATFORM`, running as non-root `builder`.
  - It git-clones Flutter `3.41.9` and runs `flutter precache --web`, then `pub get` using only `pubspec.yaml` for layer caching.
  - It runs the 3 code generators, then `flutter build web --release --wasm` with dart-defines.
  - Build args: `FLUTTER_VERSION`, `FLAVOR=stable`, `BUILD`, `COMMIT`.
- **Runtime stage:** `nginxinc/nginx-unprivileged:stable-alpine`, UID 101, port **8080**, using `lunasea/nginx/default.conf`.
- **`nginx/default.conf`:**
  - Sends `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. These are required for Wasm threads; without them Flutter falls back to JS.
  - SPA fallback: `try_files ... /index.html`.
  - Serves `.wasm` as `application/wasm` and `.mjs` as `text/javascript`.
  - `require-corp` blocks cross-origin resources that lack CORP/CORS headers. Keep this in mind when loading remote images on web.
- `lunasea/.dockerignore` excludes the platform dirs, `build`, `.dart_tool` and `node_modules`.

### `docs/Dockerfile`

- **Build stage:** `ruby:3.3-alpine`, then `bundle install` with **no Gemfile.lock**, so versions float. Then `jekyll build --baseurl "$BASE_URL"`.
- **Runtime stage:** nginx-unprivileged on 8080.

### `lunasea-notification-service/Dockerfile`

- **Build stage:** `node:24-alpine`. It runs `npm ci`, then `tsc`, then `npm prune --omit=dev`.
  - It has no `--platform=$BUILDPLATFORM`, so the arm64 build is emulated and slow.
- **Runtime stage:** `gcr.io/distroless/nodejs24-debian12:nonroot` (UID 65532).
  - `CMD ["-r","dotenv/config","dist/index.js"]`
  - The HEALTHCHECK is a node one-liner.

### Local commands

```bash
docker compose build                 # all three
docker compose up web                # http://localhost:8080
docker compose up docs               # http://localhost:8081
docker build -t lunasea-web lunasea --build-arg FLAVOR=stable
```

## Docs site (`docs/`)

- It is **Jekyll with the Just the Docs theme** (`remote_theme: just-the-docs/just-the-docs`, dark). It is no longer GitBook, even though the root README still says GitBook.
- Navigation comes from front matter: `title`, `parent`, `grand_parent`, `nav_order`, `has_children`, `permalink`.
- **Sections:**

  | Directory | Contents |
  |---|---|
  | `getting-started/` | Getting-started pages |
  | `lunasea/` | Profiles, backups, logs, cloud account, `notifications/` per service |
  | `modules/` | One page per module; several are "Coming Soon!" |
  | `releases/` | One page per platform |

- Images live in `docs/.gitbook/assets/`.
- Callouts use `{: .note }` and `{: .warning }`.
- `_config.yml` needs `repository: Dim145/lunasea` so Jekyll can build without `.git` (for example in Docker).
- **Preview locally:** run `cd docs && bundle install && bundle exec jekyll serve`, or `docker compose up docs`.
- **Stale content:**
  - Pages still reference upstream `builds.lunasea.app`, `web.lunasea.app` and `ghcr.io/jagandeepbrar/lunasea:stable` on port 80.
  - This fork's image is `.../lunasea-web` on port 8080.
  - A Dockerfile comment mentions a GitHub Pages workflow that does not exist.

## Platform directories (`lunasea/`)

### Android (`lunasea/android`)

- **Toolchain:**
  - AGP `8.10.0` and Kotlin `2.1.20`, via the plugin DSL in `settings.gradle`.
  - Gradle wrapper `8.11.1`.
  - `gradle.properties` sets `-Xmx4g`, `useAndroidX=true`, `enableJetifier=false`.
- **`app/build.gradle`:**
  - `namespace` / `applicationId` are `app.dim145.lunasea`.
  - `compileSdk 36`, `minSdk 24`, `targetSdk 35`, NDK `28.2.13676358`, Java/Kotlin 11.
  - Debug builds add the suffix `.debug` and a version-name suffix `-dev`.
- **Release signing:**
  - It always uses `key.properties`, loaded from `rootProject.file('key.properties')`.
  - The template is `android/key.properties.sample`, with `storeFile=../key.jks`, which resolves to `android/key.jks`.
  - **A local release build without these files fails.** Use `flutter build apk --debug` for local testing.
  - Never commit `*.jks`, `*.keystore` or `key.properties`. They are gitignored at the root and in `lunasea/`.
- **Other files:**
  - `MainActivity.kt` is at `app/src/main/kotlin/app/dim145/lunasea/`.
  - The manifest declares the `lunasea://` deep-link scheme, allows cleartext traffic, and queries `com.plexapp.android`.

### iOS (`lunasea/ios`)

- **Bundle id and deployment target:** bundle id `app.dim145.lunasea`. The deployment target is 12.0, but the Podfile `post_install` forces pods to 11.0.
- **Signing:**
  - Manual signing with **upstream's** team `VPH33JQH4R` and match profiles.
  - `ios/fastlane/Matchfile` points to `JagandeepBrar/fastlane-match-storage`.
  - Signed builds need your own team, profiles and match repository.
- **Entitlements:** associated domain `webcredentials:www.lunasea.app` (upstream domain).

### macOS (`lunasea/macos`)

- `Configs/AppInfo.xcconfig`: `PRODUCT_NAME = LunaSea`, bundle id `app.dim145.lunasea`.
- Deployment target 10.15; the pods use 10.14.
- The app is sandboxed with network client/server, user-selected files and a keychain group.
- Fastlane lanes exist for notarized zip, pkg and dmg builds. They are not used by the current CI.

### Linux (`lunasea/linux`, `lunasea/debian`)

- `linux/CMakeLists.txt` sets `BINARY_NAME lunasea` and `APPLICATION_ID app.dim145.lunasea`.
- `debian/` holds `postinst`/`postrm` (which create and remove the `/usr/bin/lunasea` symlink) and a desktop entry.
- The checked-in `DEBIAN/control` template is malformed. CI rewrites it.

### Snap and Windows

- **Snap:** `snap/snapcraft.yaml` is core22, strict confinement, `version: 1.2.0`.
- **Windows:** the binary is `LunaSea`. `msix_config` sets `identity_name: app.dim145.lunasea`.

### Web (`lunasea/web`)

- Uses `index.html` with `$FLUTTER_BASE_HREF`, a custom splash, and the manifest.
- Icon hrefs are absolute (`/android-icon-*.png`), so hosting under a subpath breaks the icons.

## Versioning and release

- **Where the version lives:** `pubspec.yaml` (`1.2.0+1`), `package.json` (`1.2.0`) and `snap/snapcraft.yaml` (`1.2.0`). `npm run version` syncs pubspec and snap from package.json using `yq` and `jq`.
- **`CHANGELOG.md`** still ends at upstream `11.0.0`. `npm run release` uses standard-version (see `.versionrc`).
- **Cutting a release:**
  1. Bump the version in the 3 files.
  2. Commit `chore: bump app version ...`.
  3. Publish a GitHub Release with a semver tag `vX.Y.Z`.
  4. All 5 workflows run and attach their artifacts.

## Gotchas

1. **No PR CI.** Run the checks yourself: `flutter analyze`, `npm run lint`, `npm run build`.
2. **The Flutter version is pinned in 5 places:** 4 workflows plus `lunasea/Dockerfile`. Keep them in sync. Some dependency pins in `pubspec.yaml` depend on Flutter 3.41's `meta 1.17`.
3. **`FLAVOR` defaults to `edge`** in `environment_config.yaml` when the env var is unset during generation. `--dart-define` does not feed `environment_config`; only env vars do, at generation time.
4. **Android versionCode is `github.run_number`,** which is per workflow.
5. **Trivy SARIF upload** needs code scanning enabled on the repo.
6. **Stale upstream references remain:**
   - Domains `lunasea.app` and `builds.lunasea.app`.
   - The Apple team, the macOS copyright, and `.ruby-version 2.7.6`.
   - OCI labels, which are overridden at push time.

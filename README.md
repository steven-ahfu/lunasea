# LunaSea

LunaSea is a remote for the media services you run at home. Use it to add and monitor titles, pick releases, and check your download queues. Set up the services you want to control first. For library management, that means [Sonarr](https://github.com/Sonarr/Sonarr) for TV, [Radarr](https://github.com/Radarr/Radarr) for movies, [Lidarr](https://github.com/Lidarr/Lidarr) for music, or [Chaptarr](https://github.com/Chaptarr/chaptarr) for books. LunaSea connects directly to your servers.

This repo is a fork of [Dim145’s LunaSea](https://github.com/Dim145/lunasea), which continues [Jagandeep Brar’s original project](https://github.com/jagandeepbrar/lunasea).

<p align="center">
  <a href="https://github.com/steven-ahfu/lunasea/releases/latest"><img src="https://img.shields.io/github/v/release/steven-ahfu/lunasea?label=version&amp;color=7aa2f7" alt="Latest release"></a>
  <a href="https://github.com/steven-ahfu/lunasea/releases"><img src="https://img.shields.io/github/downloads/steven-ahfu/lunasea/total?color=9ece6a" alt="Total GitHub release downloads"></a>
  <a href="https://github.com/steven-ahfu/lunasea/actions/workflows/auto-release-android.yml"><img src="https://img.shields.io/github/actions/workflow/status/steven-ahfu/lunasea/auto-release-android.yml?branch=main&amp;label=Android%20release" alt="Android release workflow"></a>
  <a href="https://github.com/steven-ahfu/lunasea/releases/latest"><img src="https://img.shields.io/badge/Android-7.0%2B-9ece6a?logo=android&amp;logoColor=white" alt="Android 7.0 or newer"></a>
  <a href="lunasea/LICENSE.md"><img src="https://img.shields.io/badge/license-GPL%20v3-bb9af7" alt="GPL v3 license"></a>
</p>

<p align="center">
<a href="https://github.com/steven-ahfu/lunasea/releases/latest"><img src="docs/images/github.png" alt="Get it on GitHub" width="180"></a>
<a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22app.dim145.lunasea%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fsteven-ahfu%2Flunasea%22%2C%22author%22%3A%22steven-ahfu%22%2C%22name%22%3A%22LunaSea%22%7D"><img src="docs/images/obtainium.png" alt="Install with Obtainium" width="180"></a>
</p>

<p align="center">
  <a href="docs/screenshots/radarr-movies.png"><img src="docs/screenshots/radarr-movies.png" width="180" alt="Radarr movie library with posters"></a>
  <a href="docs/screenshots/sonarr-series.png"><img src="docs/screenshots/sonarr-series.png" width="180" alt="Sonarr TV library with posters"></a>
  <a href="docs/screenshots/chaptarr-library.png"><img src="docs/screenshots/chaptarr-library.png" width="180" alt="Chaptarr ebook library with covers and authors"></a>
  <a href="docs/screenshots/chaptarr-book-details.png"><img src="docs/screenshots/chaptarr-book-details.png" width="180" alt="Book details for The Left Hand of Darkness with cover, synopsis, and search actions"></a>
</p>

Captured in LunaSea with demo libraries. Artwork comes from Open Library, TMDB, and TVmaze.

## Features

- Browse your libraries, add and monitor titles, check upcoming and missing releases, and view activity. **Browse ebooks and audiobooks in list or grid view, see book files and history, and check whether an import finished after a dropped connection.**
- **Filter interactive torrent results** in Sonarr and Radarr by tracker or indexer, quality, resolution, language, audio format, dual audio, and custom formats. **Chaptarr also filters by indexer, quality, audio format, and custom formats. Lidarr can filter by audio format, including FLAC and MP3.**
- Manage Usenet queues in SABnzbd and NZBGet. Search Newznab indexers and send NZBs to a download client.
- Check Plex activity in Tautulli and monitor streams in Tracearr.
- Switch between server profiles, back up and restore settings, and add shortcuts to other web apps. **External module links now open correctly on Android, with a simpler add and edit form.**
- Receive push notifications through the optional [ntfy webhook bridge](lunasea-notification-service/).
- **Version changes on `main` trigger an Android APK release.**

## Supported services

| Use | Services |
| --- | --- |
| Media libraries | [Sonarr](https://github.com/Sonarr/Sonarr) (TV), [Radarr](https://github.com/Radarr/Radarr) (movies), [Lidarr](https://github.com/Lidarr/Lidarr) (music), **[Chaptarr](https://github.com/Chaptarr/chaptarr) (ebooks and audiobooks)** |
| Usenet downloads | [SABnzbd](https://sabnzbd.org/), [NZBGet](https://nzbget.com/) |
| Indexer search | [Newznab](https://www.newznab.com/) |
| Stream monitoring | [Tautulli](https://tautulli.com/), [Tracearr](https://github.com/connorgallopo/Tracearr) |
| Webhook notifications | [ntfy](https://ntfy.sh/) via the optional [LunaSea notification service](lunasea-notification-service/) |
## Get started

1. Install the APK from [GitHub Releases](https://github.com/steven-ahfu/lunasea/releases/latest).
2. Open **Settings → Configuration** and enable a service.
3. Enter the server URL and credentials, then tap **Test Connection**. Open the service from the drawer. [Chaptarr setup guide](docs/modules/chaptarr.md)

The Flutter app also targets iOS, macOS, Linux, Windows, and web. But none are tested other than the APK. Do not expect support for them.

## Acknowledgments

Thanks to [Jagandeep Brar](https://github.com/jagandeepbrar/lunasea) for building the original LunaSea and to [Dim145](https://github.com/Dim145/lunasea) for continuing it. I forked Dim145’s repo and maintain this version.
## License

[GPL v3 license](lunasea/LICENSE.md)

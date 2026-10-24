# DLPS Notify

A little menu bar app for macOS. It keeps an eye on a game release site and pings you when a game
shows up or gets an update. Click the notification and the game page opens.

<p align="center">
  <img src="Resources/appicon.png" width="128" alt="DLPS Notify icon">
</p>

## What it does

- Checks every 30 minutes (or 15, or 60, your call) and notifies you about **new games** and **updates**.
- On updates it tries to tell you what changed, e.g. `+ EUR (exFAT)`. If it can't figure that out,
  you just get "Update".
- You pick the platforms you care about: **PS2, PS3, PS4, PS5, PSN**.
- The menu lists the latest entries with a coloured platform badge. Click one to open it.
- **History window**: menu → *History…*, or right-click the menu bar icon. Search, filter, click the links.
- **My games**: point the app at a text file with your own library and it shows which of your games
  got a newer version. It can also stay quiet about everything you don't own (see below).
- 13 languages. English by default, or it follows your system language.
- Launch at login, if you want it.

The first run stays silent. The app just notes what's already there and only tells you about changes
after that. Nobody needs 300 notifications on day one.

### Your game library

One game per line, in this format:

```
Alan Wake II Deluxe Edition [PPSA02572] [v01.200.007] [PS5]
Alien Isolation [BLES01697] [PS3]
```

The version is optional and the brackets can come in any order. Pick the file under
*Library → Choose file…*. The app re-reads it when the file changes. Turn on *Notify only my games*
if you only care about stuff you own. The *My games* tab in the history window lists your whole
library with your version next to the newest one the site has seen.

Matching goes by TitleID first, then by name on the same platform. A PS4 game won't match a PS5 post.

If the file lives in Dropbox, iCloud or another folder macOS protects, pick it once through the dialog.
The app keeps a bookmark so it can still read the file after a restart.

### Platform icons

Out of the box you get coloured badges. Want logos instead? Put your own `ps5.png`, `ps4.png`,
`ps3.png`, `ps2.png` or `psn.png` (png, pdf, jpg or tiff) into
`~/Library/Application Support/DLPSNotify/platforms/`. The menu item *Platform icons…* opens that
folder. I don't ship any logos with the app, so bring your own.

## How it works

The site runs WordPress behind Cloudflare. I skip the HTML and read the REST API
(`/wp-json/wp/v2/posts`) instead, which hands back clean JSON. Cloudflare blocks anything without a
browser User-Agent, so the app sends one.

Each poll asks for everything modified since the last timestamp it saw, oldest first, page by page.
If your Mac was off for three days, you still get all of it. A post that's new to the app and whose
`modified` sits close to its `date` counts as a new game. Anything else is an update. The platform
comes from the WordPress categories. State lives in `~/Library/Application Support/DLPSNotify/state.json`.

### Notifications

macOS only lets code-signed apps post notifications under their own name, and I don't pay Apple for a
certificate. So the app ships its own copy of
[`terminal-notifier`](https://github.com/julienXX/terminal-notifier) and sends everything through that,
with the DLPS Notify title and icon. The small sender label says "terminal-notifier", everything else
is DLPS Notify. You don't need Homebrew for this.

## Install

Grab `DLPSNotify-<version>.dmg` from [Releases](https://github.com/knutwurst/dlps-notify/releases),
open it, then:

1. Right-click **Install.command** → **Open**. You only need this once, because the app isn't notarized.
2. The app lands in `/Applications` and shows up in the menu bar.
3. No banners? Allow notifications for **terminal-notifier** in System Settings → Notifications.

## Build from source

```sh
./build.sh            # release build, bundles terminal-notifier, ad-hoc signed
./make-dmg.sh         # makes DLPSNotify-<version>.dmg
swift test            # unit tests, needs Xcode (see below)
```

XCTest comes with Xcode, not with the Command Line Tools. If `xcode-select -p` points at
CommandLineTools, use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

### Self-test

```sh
DLPS_SELFTEST=1 open -W /Applications/DLPSNotify.app --args --selftest
```

Sends a test banner, then runs the real pipeline against the live API and fires a few real
notifications. The log goes to `~/Library/Application Support/DLPSNotify/dlps.log`.

## Requirements

- macOS 13 or newer
- For building: a Swift toolchain (Xcode or the Command Line Tools)

## Project layout

```
Sources/DLPSNotifyCore/   logic only, no AppKit, unit tested
  APIClient.swift         REST client (browser UA, pagination)
  ChangeDetector.swift    new vs. update, dedup, silent first run
  DLPSDate.swift          the API's timestamp format
  GamePost.swift          API model, decoded title, platform
  GameStore.swift         state.json
  HTMLEntities.swift      &amp; and friends
  Library.swift           library file parser, lookup, version compare
  Platform.swift          PS2/PS3/PS4/PS5/PSN categories + filter
  UpdateDetails.swift     "what changed" diff
Sources/DLPSNotify/       the app
  AppDelegate.swift       menu, polling, settings, debug flags
  History*.swift          history storage + window (History / My games tabs)
  LibraryModel.swift      loads your library file (with bookmark)
  Localization.swift      the 13 languages
  Notifier.swift          notification text
  ExternalNotifier.swift  delivery via terminal-notifier / osascript
  PlatformStyle.swift     badges and custom icons
  Recent.swift            dates in the menu
  SignatureStore.swift    snapshots for the update diff
  Log.swift               log file
dist/                     installer + DMG read-me
scripts/makeicon.swift    regenerates the app icon
```

## License

MIT, see [LICENSE](LICENSE). Bundles `terminal-notifier` (MIT).

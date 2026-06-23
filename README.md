# DLPS Notify

A macOS menu bar app that watches a game-release site and notifies you when an
entry is added or updated. Click a notification to open its page.

<p align="center">
  <img src="Resources/appicon.png" width="128" alt="DLPS Notify icon">
</p>

## What it does

- Polls on an interval (default every 30 minutes) and shows a notification for each
  **new entry** and each **update** to an existing one.
- Lets you pick which platforms you care about — **PS2 / PS3 / PS4 / PS5 / PSN**.
- Keeps a list of the most recent entries in the menu; click one to open its page.
- Available in **English** (default) and **German** — switch in the menu (or follow the system language).
- Optional launch-at-login.

On the first run it silently records the current entries — no flood of notifications —
and only notifies on changes from then on.

## How it works

The site is a WordPress install behind Cloudflare. Instead of scraping HTML, the app reads its REST
API (`/wp-json/wp/v2/posts`), which returns clean JSON. Cloudflare rejects requests without a browser
User-Agent, so the app sends one. Each poll asks for everything modified after the last-seen
timestamp, ordered oldest-first and drained across pages, so nothing is missed after downtime. A post
seen for the first time whose `modified` is close to its publish `date` is a **new entry**; a larger
gap (or a later change to a post already seen) is an **update**. The platform comes from the post's
WordPress categories. State lives in `~/Library/Application Support/DLPSNotify/state.json`.

### Notifications

macOS only lets a **code-signed** app post notifications under its own name. This app is distributed
unsigned, so it delivers notifications through a bundled copy of
[`terminal-notifier`](https://github.com/julienXX/terminal-notifier) — branded with the DLPS Notify
title and icon. The small sender label reads "terminal-notifier"; the icon, title and content are all
DLPS Notify. `terminal-notifier` is bundled inside the app, so no Homebrew is needed on the target Mac.

## Install

Download `DLPSNotify-<version>.dmg` from the
[Releases](https://github.com/knutwurst/dlps-notify/releases) page, open it, then:

1. Right-click **Install.command** → **Open** (needed once, because the app isn't notarized).
2. The app installs to `/Applications` and appears in the menu bar.
3. If no banners appear, allow notifications for **terminal-notifier** in
   System Settings → Notifications.

## Build from source

```sh
./build.sh            # builds DLPSNotify.app (release, bundles terminal-notifier, ad-hoc signed)
./make-dmg.sh         # packages DLPSNotify-<version>.dmg
swift test            # runs the unit tests (needs Xcode's toolchain — see below)
```

`swift test` needs XCTest, which ships with Xcode rather than the Command Line Tools. If
`xcode-select -p` points at CommandLineTools, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

### Self-test

```sh
DLPS_SELFTEST=1 open -W /Applications/DLPSNotify.app --args --selftest
```

Posts a test banner, then runs the real pipeline against the live API and posts a few real
notifications. Progress is logged to `~/Library/Application Support/DLPSNotify/dlps.log`.

## Requirements

- macOS 13 or newer
- To build: Swift toolchain (Xcode or Command Line Tools)

## Project layout

```
Sources/DLPSNotifyCore/   Pure logic — no AppKit, no UI. Unit-tested.
  GamePost.swift          API model + HTML-decoded title + platform
  Platform.swift          PS2/PS3/PS4/PS5/PSN category mapping + filter
  APIClient.swift         REST client (browser UA, paginated drain)
  ChangeDetector.swift    new-vs-update decision + dedup + first-run seeding
  GameStore.swift         JSON state persistence
Sources/DLPSNotify/       The app
  AppDelegate.swift       menu bar, polling timer, platform filter, self-test
  Notifier.swift          branding
  ExternalNotifier.swift  delivery via bundled terminal-notifier / osascript
  Recent.swift            recent list persistence
dist/                     installer + DMG read-me
scripts/makeicon.swift    regenerates the app icon
```

## License

MIT — see [LICENSE](LICENSE). Bundles `terminal-notifier` (MIT).

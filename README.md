# Whydunit

A native macOS utility that finds out why iCloud Drive files aren't syncing and safely fixes the cases it can.
It scans iCloud Drive (plus Desktop and Documents when they sync to iCloud), reads each item's sync status
without ever reading file contents, and explains every problem in plain English with next steps.

- **Free.** Every feature: diagnosis, verified backups, retrying stuck uploads, restarting iCloud sync. No account,
  no license, no payments (BUILD_PLAN §10).
- Nothing is ever deleted (only moved to the Trash), no shell is ever run, and every change is logged.
  See the hard safety rules in [docs/BUILD_PLAN.md §3](docs/BUILD_PLAN.md).
- macOS 15 or later, Apple silicon and Intel. Distributed as a notarized DMG from GitHub Releases, with Sparkle
  updates. The website and update feed are on GitHub Pages. There is no Mac App Store version.

## Repository layout

```
Package.swift            SwiftPM package: WhydunitCore + WhydunitMac (the Mac targets exist only on macOS)
Sources/WhydunitCore/    Foundation-only logic: model, iCloud classifier, report and format helpers (builds on Linux)
Sources/WhydunitMac/     macOS collectors and actions: scanner, upload probe, backup, retry, sync restart, activity log
Tests/                   WhydunitCoreTests, WhydunitMacTests
App/                     SwiftUI app target: AppStore, views, sheets, settings, Sparkle updater, Info.plist, assets
project.yml              XcodeGen spec for the app (Whydunit.xcodeproj is generated, never committed)
ExportOptions.plist      Developer ID export settings used by the release workflow
CHANGELOG.md             release notes, the single source for GitHub releases, Sparkle update notes and the site
AGENTS.md                rules for coding agents: safety rules, tests, ownership
site/                    the product website (site.json holds the base URL and links)
tools/build_site.py      builds the website into site/_dist (stdlib-only Python)
tools/changelog.py       CHANGELOG.md -> release notes as Markdown or HTML (stdlib-only Python)
tools/doctor.sh          what's configured and what's left before go-live
tools/make_icon.py       renders the app icon into App/Assets.xcassets (stdlib-only Python)
tools/make_og.py         renders the site's og.png and icons from the app icon (stdlib-only Python)
tools/sparkle_keys.py    generates the Sparkle update-signing key pair
tools/test_core_docker.sh  runs the Core tests in Docker (Windows, Git Bash)
.github/workflows/       ci.yml (tests, app build, repo checks), release.yml (tag -> notarized DMG, launch-tested on arm64 and Intel),
                         site.yml (website -> the releases repo's gh-pages)
docs/                    plan, decisions, UI spec, research, release and go-live guides
```

## Build and run (on a Mac)

```sh
brew install xcodegen
xcodegen generate
open Whydunit.xcodeproj
```

Run the **Whydunit** scheme. For local builds, pick your Apple Development team under Signing & Capabilities:
ad-hoc signed builds lose their Files & Folders permission every time you rebuild.

Re-run `xcodegen generate` after adding or removing files, or after editing `project.yml`.

## Tests

```sh
swift test                                   # on a Mac: Core and Mac tests
swift test --filter WhydunitCoreTests        # anywhere with Swift 6.2+: Core only
```

Without a Mac, CI runs both on every push to main and every pull request. With Docker, Core tests also run on Windows (Git Bash):

```sh
tools/test_core_docker.sh
```

Repo checks that CI also runs:

```sh
python tools/changelog.py --self-test
python tools/build_site.py --check
bash tools/doctor.sh          # ok/todo list of what's configured and what's next; add --ci to fail on base URL mismatches
```

## App icon

`python tools/make_icon.py` redraws every AppIcon size and `Contents.json` (about 40 s, no dependencies), then
`python tools/make_og.py` (about a minute) to refresh the website's images.

## Docs

| File | What it is |
|---|---|
| [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md) | **Authoritative** v1.0 plan: scope, safety rules, API contracts, UI decisions |
| [docs/GO_LIVE.md](docs/GO_LIVE.md) | Step by step from zero to the first public release: name check, GitHub Pages, Apple Developer Program, secrets, website, legal review |
| [docs/RELEASING.md](docs/RELEASING.md) | One-time signing, notarization and Sparkle setup, and how to cut a release |
| [CHANGELOG.md](CHANGELOG.md) | Release notes; every release tag needs a section |
| [docs/BUILDMAC_CHECKLIST.md](docs/BUILDMAC_CHECKLIST.md) | Gap analysis against the buildmac.app shipping checklist |
| [docs/DECISIONS.md](docs/DECISIONS.md), [docs/DECISIONS_REVIEW.md](docs/DECISIONS_REVIEW.md) | Product decisions and their review (BUILD_PLAN wins where they differ) |
| [docs/UI_SPEC.md](docs/UI_SPEC.md), [docs/UI_SPEC_REVIEW.md](docs/UI_SPEC_REVIEW.md) | UI specification and its review |
| [docs/research/](docs/research/) | Research notes: iCloud internals, competitors, distribution (licensing notes are historical: the app is free) |

# Whydunit vs the buildmac.app checklist (gap analysis, 2026-09-28)

Source: https://buildmac.app/ (a paid template's public checklist: 12 items + 8 "what broke" lessons).
We don't have its code; this maps each item to Whydunit's current state. Nothing in the Mac/App/CI layer has
been compiled or run yet, so "Done" means "written and reviewed", not "proven". Whydunit is free (BUILD_PLAN §10),
so the payment and licence items don't apply. References name workflow steps and symbols rather than line numbers.

## The 12 items

| # | Item | Status | Where, and what's left |
|---|---|---|---|
| 1 | Developer ID cert, hardened runtime, entitlements | Done (unrun) | release.yml "Import Developer ID certificate" (temporary keychain) and "Archive and export" (Developer ID identity, hardened runtime, secure timestamp, `codesign --strict`); project.yml hardened runtime and App/Whydunit.entitlements (empty: not sandboxed, no exceptions). Left: first real run (the Developer ID G2 intermediate VERIFY in the import step) |
| 2 | Universal build that launches on Apple silicon and Intel | Done (unrun) | release.yml "Archive and export" (`ARCHS="arm64 x86_64"`), "Check the bundle" (lipo on the app and Sparkle), "Launch smoke test (arm64)" before notarizing, job smoke-intel (macos-15-intel) before publishing; publish needs both. Left: first real run |
| 3 | notarytool, stapling, DMG Gatekeeper opens | Done (unrun) | release.yml "Preflight (notarytool accepts the App Store Connect key)" before any build time; "Notarize app, build DMG, notarize DMG": `notarytool --wait` failing with Apple's log unless Accepted, app and DMG notarized and stapled, `spctl` assessment of both. Left: first real run |
| 4 | Sparkle, EdDSA keys, signed appcast | Done (unrun) | `Updater.isConfigured` (off until a real 32-byte key) and `CheckForUpdatesView`'s tooltip; release.yml preflights (Sparkle declared at the pinned version, placeholder refused, key pair matches), "Check the bundle" (framework embedded), publish (tarball SHA-256 checked, appcast signed and checked). Left: generate keys (RELEASING.md step 4), first real run |
| 5 | Licence keys: per-Mac activation, weekly checks, offline grace | N/A — the app is free (BUILD_PLAN §10) | No licence code, key or check exists |
| 6 | Payment webhooks, signature checks, refunds that revoke | N/A — the app is free (BUILD_PLAN §10) | No payments |
| 7 | Receipts, key recovery, refund emails | N/A — the app is free (BUILD_PLAN §10) | No purchases, so no receipts, keys or refunds |
| 8 | SPF, DKIM, DMARC | N/A for now | Support is the releases repo's GitHub Issues, so there is no mailbox to protect. If a support address on a custom domain is ever added, GO_LIVE.md step 3 notes the records |
| 9 | Site with pricing, terms, privacy, refund policy | Terms and privacy done, legal review pending; pricing and refund policy N/A — the app is free (BUILD_PLAN §10) | site/src/pages/**; header nav links How it works/Safety/FAQ/Support and Download, footer links download, changelog, support, GitHub Issues, privacy, terms (site/src/layout.html); `build_site.py --check` passes. Left: fill `owner`/`governingLaw`, lawyer review then `"legalReviewed": true`, deploy (GO_LIVE.md step 6) |
| 10 | Download link that follows the latest release | Done (unrun) | release.yml publish uploads the fixed-name Whydunit.dmg and publishes the release only after its uploads; /download/ redirects to releases/latest/download/Whydunit.dmg (build_site.py) and shows "Coming soon" until main's CHANGELOG.md has a released section. Left: set `releasesRepo`; push main only after 1.0.0 publishes (RELEASING.md "Cutting a release" step 5) |
| 11 | Canonical URLs, sitemap, OG images, llms.txt | Done | build_site.py builds canonicals, sitemap, robots.txt, feed and llms.txt from `baseURL` (GitHub Pages project path or custom domain); site/static/og.png; `--check` enforces them for both URL shapes |
| 12 | Changelog feeding the feed, appcast and release notes | Done (release half unrun) | CHANGELOG.md → tools/changelog.py; release.yml preflight (changelog row), publish "Release notes from CHANGELOG.md" (release body and Sparkle notes); build_site.py /changelog/ and /feed.xml |

## The 8 "what broke" lessons

| Lesson | Status | Where |
|---|---|---|
| Updater can't ship missing | Done (unrun) | release.yml preflight (Sparkle declared in project.yml) and "Check the bundle" (Sparkle.framework embedded); `Updater.isConfigured` keeps it off without a real key |
| Every build launches before it ships | Done (unrun) | Item 2: arm64 before notarizing, Intel before publishing |
| Download links survive the product name | Done (unrun) | release.yml preflight refuses an APP that GitHub would rename, and a site.json `dmgName` other than $APP.dmg; fixed asset name Whydunit.dmg (item 10) |
| Our mistakes never lock out a buyer | N/A — the app is free (BUILD_PLAN §10) | Nothing to lock: every action is always available |
| Paste works from first launch | Done (unrun) | Only .appInfo/.newItem/.help are replaced (WhydunitApp.swift `.commands`); ci.yml "Standard Edit menu kept" fails on a replaced .pasteboard/.textEditing |
| No button can do nothing | Done | ci.yml "No empty Button actions in App/" |
| Nothing shipped names your machine | Done | ci.yml "No home paths in tracked files"; none remain (only /Users/Shared and the example users) |
| Website stuck in a stale theme | Done | No theme switch: site/static/styles.css follows `prefers-color-scheme` only. `build_site.py --check` measures the contrast of the text tokens on the page backgrounds in both schemes and fails on any `data-theme` or `localStorage` in the built HTML and CSS |

## Also from the template

Done:
- `tools/doctor.sh`: prints `ok`/`todo` lines (one base URL in site.json, Links.swift and SUFeedURL, placeholders,
  Sparkle key, changelog row, legal review, live site, GitHub secrets); ci.yml runs `bash tools/doctor.sh --ci` and
  release.yml's preflight runs it too.
- `AGENTS.md` with the BUILD_PLAN §3 safety rules, the test commands and the ownership rule.
- Links: the standard About panel credits link the website, terms and privacy and carry Sparkle's licence
  (`showAboutPanel`); the Help menu links support, What's New and privacy. Open-at-login waits for Dock Detective.

## What's left

1. First ci.yml run on macOS: WhydunitMac and App have never compiled, so expect code fixes.
2. Go-live: docs/GO_LIVE.md steps 1-9 (`bash tools/doctor.sh` lists the open todos: `OWNER` in the base URL and
   `releasesRepo`, SUPublicEDKey, owner/governingLaw, the 1.0.0 changelog row, legal review, Pages live, secrets).
3. The v0.0.1/v0.0.2 rehearsal (release.yml's first real run) turns every "Done (unrun)" above into proven.

# Whydunit: notes for coding agents

Whydunit is a native macOS utility (Swift/SwiftUI, macOS 15+, built with Xcode 26 in Swift 5 language mode,
non-sandboxed Developer ID app with Sparkle updates) that diagnoses and safely fixes stuck iCloud Drive files.
v1.0 is the iCloud Drive module only. The app is **free**: no licence, payments, paywall or trial (BUILD_PLAN §10), and
its website and update feed are on GitHub Pages. Don't add any of that back.

Read [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md) first. It is authoritative and overrides `DECISIONS.md`,
`DECISIONS_REVIEW.md`, `UI_SPEC.md` and `UI_SPEC_REVIEW.md`. Going live: [docs/GO_LIVE.md](docs/GO_LIVE.md), [docs/RELEASING.md](docs/RELEASING.md).

## Be honest about what has run

- Only `WhydunitCore` has been compiled and tested (Linux, in Docker). `WhydunitMac`, `App/` and the release
  workflow have never been compiled or run. **Never claim Mac or App code compiles, builds or works unless a CI run
  shows it.** Say "written, not compiled".
- Don't invent APIs, flags or service behavior. Check Apple, Sparkle and GitHub docs; mark anything you
  couldn't verify with `VERIFY`. If you're unsure an API exists on macOS 15, don't use it.

## Test

```sh
bash tools/test_core_docker.sh          # Core build + tests in Docker (Windows Git Bash too); must pass with no warnings
swift test                              # on a Mac: Core and Mac tests
python tools/changelog.py --self-test   # changelog parser and markdown renderer
python tools/build_site.py --check      # website build
bash tools/doctor.sh                    # what's configured and what's left before go-live
```

CI (`.github/workflows/ci.yml`) runs all of these plus the app build on macOS.

## Safety rules (BUILD_PLAN §3; CI checks the first three)

- Never call `removeItem`, `unlink`, `rmdir` or `rm` in `Sources/` or `App/`. Deleting means `FileManager.trashItem`.
- Never run a shell (`/bin/sh -c`, `bash -c`). `Process` only with an absolute executable path and an argument array.
- No `Button` with an empty action. The only exception is a dialog's `role: .cancel` button, which dismisses the dialog.
- Never read file contents during a scan. Materialization is disabled process-wide at launch; `EDEADLK` means
  "dataless" (record it, don't retry).
- Never toggle iCloud settings, sign out, evict, set `isExcludedFromSync`, kill root-owned processes, touch
  `~/Library/Application Support/CloudDocs`, FileProvider or CloudKit caches, write private xattrs, or change permissions.
- Retry Upload needs a verified backup of that exact item first. It runs one item at a time, re-checks the item right
  before acting, stages on the same volume and always moves the item back.
- Restart iCloud Sync only after explicit consent, only `/usr/bin/pkill -TERM -x -U <uid> bird`, never in a loop.
- Backups never go inside iCloud. Free space must be at least 2× the copy size, every item must be local, and any hash
  mismatch aborts.
- Every change is appended to the activity log.

## Repo rules

- No personal home paths in committed files (Windows user folders, or `/Users/` followed by a real name). CI fails on
  them. Use `~`, `<scratchpad>` or a repo-relative path. `/Users/Shared` and the example user `jane` are allowed.
- Every release needs a `## X.Y.Z — YYYY-MM-DD` section in `CHANGELOG.md`. The notes are user-facing: they become
  the GitHub release body, the Sparkle update notes and the site's changelog. Unreleased notes go under
  `## Unreleased` (never published: the site deploys on every push to `main`).
- One base URL (`https://OWNER.github.io/whydunit-releases` until go-live, BUILD_PLAN §10.2): `site/site.json`
  `baseURL` == `App/Links.swift` `Links.website` == `App/Info.plist` `SUFeedURL` minus `/appcast.xml`.
  `tools/doctor.sh --ci` fails when they disagree; `OWNER` is a todo, not an error.
- The only third-party dependency is Sparkle 2. Python tools use the standard library only (`tools/sparkle_keys.py`
  also needs `cryptography`).
- Never commit key material (`.p12`, `.p8`, Sparkle private key) or real secrets.
- Code style is ponytail (BUILD_PLAN §8): the shortest correct code, no protocols with one implementation, no view
  model per screen, and comments only where the why isn't obvious.

## Ownership

When several agents work in parallel, each one edits only its own files: BUILD_PLAN §7 for the app and §9.7 for
go-live (as amended by §10). If another owner's file needs a change, propose it in your report instead of editing it.

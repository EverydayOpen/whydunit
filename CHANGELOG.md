# Changelog

Newest first. `tools/changelog.py` turns each section into the GitHub release notes, the in-app update notes and
the website changelog, so write for users. Headings must be `## X.Y.Z — YYYY-MM-DD` (em dash); the release
workflow refuses a tag without one. Write upcoming notes under `## Unreleased`, which is never published (the
website deploys on every push to main). On release day, rename it to `## X.Y.Z — <that day>`, commit, push only
the tag, and push main once the release is published (docs/RELEASING.md "Cutting a release").
Links must be full `https://` URLs: the GitHub release and Sparkle's update window can't resolve site-relative ones.

## Unreleased

First release. Whydunit finds out why iCloud Drive files aren't syncing and safely fixes the cases it can.

- **Free**: every feature, on as many Macs as you like. No account, no license key, no in-app purchases.
- **Complete diagnosis** of iCloud Drive, plus Desktop and Documents when they sync to iCloud. It finds files
  that exist only on this Mac, uploads that are stuck or were rejected, a stalled sync, full iCloud storage, files
  too large for iCloud, locked files, conflicts, developer folders, files moved aside by macOS, and folders it
  couldn't check. Each finding comes with a plain-English explanation and next steps.
- A scan reads each file's sync status, never its contents. Your files and their names never leave your Mac. The app
  goes online only for update checks and a 1 MB test upload to your own iCloud Drive during each scan.
- **Back Up** copies the files you choose to a visible folder outside iCloud and checks every copy against the
  original with SHA-256. It stops at the first mismatch.
- **Retry Upload** moves a stuck file out of iCloud Drive and back, one file at a time, and only after a verified
  backup of that file exists.
- **Restart iCloud Sync** restarts the iCloud Drive sync process, only after you agree to it.
- An **activity log** records every change Whydunit makes. Whydunit never deletes your files.
- Requires macOS 15 or later, on Apple silicon or Intel.

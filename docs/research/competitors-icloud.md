# Competitor and demand teardown: stuck or missing iCloud Drive files on Mac (need 1)

Research date: 2026-09-27 (macOS 27 "Golden Gate" is current; macOS 26 Tahoe is the last Intel release).
Scope: Cirrus and Bailiff (Eclectic Light Company), Howard Oakley's iCloud Drive guidance, other tools, Apple's official guidance, user failure patterns from 2024 to 2026, and what a safe "iCloud Rescue" app could do.
Status labels used below: **verified** means checked against the cited page in this session. **Reported** means a single user or vendor claim. **Unverified** means not confirmed.

---

## 0. Summary

- **Main gap (verified).** Howard Oakley wrote in August 2026 that for iCloud Drive "No diagnostic or troubleshooting tools are provided", and that log entries go only to the Unified log ([An iCloud primer, 2026-08-25](https://eclecticlight.co/2026/08/25/an-icloud-primer/)). The free tool Cirrus is the only serious third-party tool for looking inside iCloud Drive. It is built for people who can read the log. No product we found gives a nontechnical user the following:
  - a safe, guided and verified way to get files moving again, and
  - a guarantee that nothing gets lost along the way.
- **The pain is real, keeps coming back, and is still happening on Tahoe and Golden Gate.**
  - Apple Developer Forums thread "iCloud for Mac is stuck on 'waiting to upload'": about 147k views and 143 participants ([thread 651829](https://developer.apple.com/forums/thread/651829)).
  - Tahoe-era Apple Community threads have 5 to 12 "Me too" votes each.
  - A Reddit reply dated **Sep 2026** says `killall bird` still unsticks uploads "with MacOS 27" ([r/MacOS](https://www.reddit.com/r/MacOS/comments/11q0r1w/finder_in_icloud_stuck_on_waiting_to_upload/)).
- **New in macOS 26 (verified).** Apple added public APIs for sync control:
  - `FileManager.pauseSyncForUbiquitousItem(at:completionHandler:)`
  - `resumeSyncForUbiquitousItem(at:with:completionHandler:)`
  - `uploadLocalVersionOfUbiquitousItem(at:withConflictResolutionPolicy:completionHandler:)`
  - `fetchLatestRemoteVersionOfItem(at:completionHandler:)`
  - the `URLResourceKey` values `ubiquitousItemIsSyncPausedKey` and `ubiquitousItemSupportedSyncControlsKey`

  Apple's documentation says a pause "doesn't automatically resume if the app closes or crashes". A rescue tool can therefore find **items left paused by a crashed app**. This is a new failure class, and Cirrus is not documented as covering it.
- **What most often destroys data is a bad "fix":**
  - deleting the wrong `CloudDocs` folder,
  - turning iCloud Drive off while items are still unsynced (this produced 0 KB files),
  - running permission tools on `~/Library`,
  - and Optimize Mac Storage leaving files dataless on a full disk.

  A rescue product should sell *safety first*: make a copy before any fix, and verify after every step.

---

## 1. How iCloud Drive works now (what a tool must model)

| Fact | Source | Status |
|---|---|---|
| Since Sonoma, iCloud Drive runs on Apple's **FileProvider** framework. Evicted files are **dataless**: attributes and extended attributes stay, but the data extents are gone. | [Sonoma changed iCloud Drive radically](https://eclecticlight.co/2023/10/25/macos-sonoma-has-changed-icloud-drive-radically/), [primer](https://eclecticlight.co/2026/08/25/an-icloud-primer/) | verified |
| Two modes: **replicated** (Optimize Mac Storage OFF, no eviction) and **non-replicated** (ON, files can become dataless). | [Understanding and testing iCloud, 2026-04-06](https://eclecticlight.co/2026/04/06/understanding-and-testing-icloud/) | verified |
| You can detect a dataless file with `SF_DATALESS` in `stat.st_flags` (from `stat` or `getattrlist`). Warning: `stat` and `getattrlist` **materialize any dataless intermediate folders** in the path. To opt out, call `setiopolicy_np` with `IOPOL_MATERIALIZE_DATALESS_FILES_OFF` at `IOPOL_SCOPE_THREAD` or `IOPOL_SCOPE_PROCESS`, and handle `EDEADLK`. The iotype is `IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES`. | [Apple TN3150](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files), [setiopolicy_np(3)](https://leancrew.com/all-this/man/man3/setiopolicy_np.html) | verified |
| Reading a dataless file blocks until iCloud serves it. A user reports git, npm, Obsidian and AI agents hanging after 18,492 files were evicted when iCloud was full and the disk had 2 GB free. | [Reddit, May 2026](https://www.reddit.com/r/MacOS/comments/1t5qnas/iclouds_299_200gb_filled_up_so_macos_silently/) | reported |
| Turning Optimize Mac Storage **off** re-downloads every evicted file ("could be many hours"). **Storage debt** happens when evicted bytes are larger than free space, and then you cannot turn Optimize off. Oakley: "There doesn't appear to be any simple way to determine whether your Mac has entered storage debt." | [Optimise Mac Storage or not?](https://eclecticlight.co/2024/03/11/icloud-drive-in-sonoma-optimise-mac-storage-or-not/), [TM and iCloud Drive](https://eclecticlight.co/2024/07/05/how-time-machine-backs-up-icloud-drive-in-sonoma/) | verified |
| Time Machine cannot back up dataless files, and Spotlight cannot index them. | [How Time Machine backs up iCloud Drive in Sonoma](https://eclecticlight.co/2024/07/05/how-time-machine-backs-up-icloud-drive-in-sonoma/) | verified |
| Pinning ("Keep Downloaded", Sequoia and later) is stored as the extended attribute `com.apple.fileprovider.pinned`. The Finder hides the command when more than 10 items are selected. There is no built-in way to see the total size of pinned items. | [Sequoia pinning](https://eclecticlight.co/2024/09/30/how-icloud-has-changed-in-sequoia-pinning-and-more/) | verified |
| User files live in `~/Library/Mobile Documents/com~apple~CloudDocs`. App containers live in `~/Library/Mobile Documents/com~apple~<App>`. Desktop and Documents stay in `~/Desktop` and `~/Documents`. | [CCC KB, 2026-07](https://support.bombich.com/hc/en-us/articles/20686419951767-Backing-up-the-content-of-cloud-storage-volumes) | verified |
| The daemons involved are `bird` (CloudDocs), `cloudd` (CloudKit), `fileproviderd` and `nsurlsessiond`. The main log subsystems are `com.apple.clouddocs` and FileProvider. Uploads go over CloudKit and MMCS (MobileMe Chunking Service). | [Test iCloud Drive using Cirrus, 2026-08-26](https://eclecticlight.co/2026/08/26/test-icloud-drive-using-cirrus/), [Matt Goodrich, Dec 2025](https://mattgoodrich.com/posts/fixing-icloud-drive-sync-issues-macos/), [dev forum 822534](https://developer.apple.com/forums/thread/822534) | verified |
| Throttling happens in `fileproviderd` (log line "schedule throttling handling", XPC `com.apple.fileproviderd.throttling-retry`). The upload chunk maximum is 28,455,742 bytes. | [Sonoma mechanisms and throttling](https://eclecticlight.co/2024/03/05/icloud-drive-in-sonoma-mechanisms-throttling-and-system-limits/) | verified |
| Document versions are **not** synced. Each Mac keeps only its own versions. | [Versions in iCloud Drive, 2025-05-05](https://eclecticlight.co/2025/05/05/how-document-versions-are-handled-in-icloud-drive/) | verified |
| What syncs (tested on Tahoe): Finder tags, `com.apple.lastuseddate#PS`, `com.apple.quarantine`, `com.apple.TextEncoding`, and extended attributes with the S flag. Most other extended attributes, versions and Spotlight indexes do not sync. | [What gets synced, 2026-05-12](https://eclecticlight.co/2026/05/12/what-gets-synced-in-icloud-drive/) | verified |
| **BSD flags (macOS 26.5):** files with `sappnd`, `schg` or `uappnd` **fail to sync and raise "iCloud Drive error"**, sometimes with "prolonged sync" that lasts until a restart. `uchg` is stripped. `arch`, `hidden`, `nodump` and `opaque` are stripped, but the file syncs. Detect with `ls -lO`. | [BSD flags incompatible, 2026-06-02](https://eclecticlight.co/2026/06/02/bsd-flags-are-incompatible-with-icloud-drive/) | verified |
| Excluded from sync: names ending `.nosync` or `.tmp`, `.DS_Store`, names starting `~$` or `_(A Document Being Saved`, `.ubd`, `*.weakpkg*`, and library packages (`.photoslibrary`, etc.). | [Exclusions, 2026-01-06](https://eclecticlight.co/2026/01/06/exclude-or-include-items-in-backup-search-icloud-drive-and-quicklook-preview/), [2024-07-09](https://eclecticlight.co/2024/07/09/excluding-folders-and-files-from-time-machine-spotlight-and-icloud-drive/) | verified |
| Extended attribute `com.apple.fileprovider.ignore#P`, written with `/usr/bin/xattr -w 'com.apple.fileprovider.ignore#P' 1 "path"`, excludes an item. The repo itself warns it "may not work reliably on macOS Sequoia (15.x) and later". Undocumented by Apple. | [edtadros/icloud-nosync](https://github.com/edtadros/icloud-nosync) | reported / unverified |
| File size limit is **50 GB**. Finder labels larger items "Ineligible". | [Apple: Check iCloud Drive status (macOS 27 guide)](https://support.apple.com/guide/mac-help/mchlc994344b/mac) | verified |
| Filename rules (colon, emoji, NFD/NFC normalization, 255-character names) are folklore on Mac. Apple documents a path-length limit only for iCloud for Windows. | [Apple 101649](https://support.apple.com/en-us/101649), [laptoprepairworld](https://www.laptoprepairworld.com/blog/icloud-drive-sync-stuck-fix/) | unverified for Mac |

---

## 2. Competitor teardown

### 2.1 Cirrus (Eclectic Light Company). Free. The main incumbent.
Sources: [Cirrus & Bailiff page](https://eclecticlight.co/cirrus-bailiff/), [1.16 update post 2025-06-27](https://eclecticlight.co/2025/06/27/updates-to-cirrus-icloud-revisionist-versions-spundle-sparse-bundles-and-t2m2-time-machine/), [1.15 post](https://eclecticlight.co/2024/10/02/pinning-icloud-drive-in-sequoia-is-bizarre-and-an-update-to-cirrus/), [Test iCloud Drive using Cirrus 2026-08-26](https://eclecticlight.co/2026/08/26/test-icloud-drive-using-cirrus/), [Homebrew cask `cirrus`](https://formulae.brew.sh/cask/cirrus).

- **Versions (verified).**
  - v1.16 (2025-06): Universal. Supports Big Sur, Monterey, Ventura, Sonoma, Sequoia, Tahoe and Golden Gate. The release notes say it has "an overhauled interface … ready for macOS 26 Tahoe".
  - v1.14: High Sierra to Sonoma.
  - v1.10: El Capitan to Big Sur.
- **Price.** Free.
- **Features (verified):**
  - Download and evict items. Detailed info on files and folders in iCloud Drive. Since Sonoma it recognises evicted items through `ubiquitousItemDownloadingStatus`, not the old stub filenames.
  - **Test Upload.** Creates a 1 MB file and copies it to the top level of iCloud Drive. You watch the Finder sync indicator for about 20 seconds. **Clean Up Test** removes the file.
  - **Log window.** A colour-coded log extract for a chosen clock time and length ("start the log extract at the clock time … for 20 seconds or so … Get Log"). It shows FileProvider mutations, CloudKit uploads (red) and MMCS chunk and upload completion (blue).
  - **Pinned-file deep scan (1.15+).** Reports which files and folders are pinned, individual sizes, and a total size and count.
- **Limits (verified):**
  - The log browser needs an **admin user** ("Cirrus must be run as an admin user").
  - It needs the user's consent to access iCloud Drive. It then appears under Privacy & Security > Files & Folders.
- **Not documented on Oakley's pages** (treat as gaps, but check by running Cirrus 1.16 on a real Mac):
  - a whole-drive list of *every* item not uploaded or with an error, with the reason,
  - a storage-debt calculation,
  - any guided or automatic remediation,
  - a safety copy of local-only items,
  - checks before and after an upgrade,
  - explanations in plain language,
  - a support bundle.

  Cirrus is a *diagnostic instrument*. Oakley himself says "Don't just turn it off and back on again."

### 2.2 Bailiff (Eclectic Light Company). Free. Legacy.
- A menu bar app to evict or download iCloud items. Latest version v1.5 is Universal and supports **El Capitan to Monterey only** (verified, [Cirrus & Bailiff](https://eclecticlight.co/cirrus-bailiff/)).
- Not updated for FileProvider-era macOS, so it is not a competitor on Sonoma and later.

### 2.3 Apple's own tools and guidance (verified unless noted)

- **Finder status labels (macOS 27 Mac User Guide):** In iCloud, **Ineligible** (usually larger than 50 GB), Downloaded, Keep Downloaded, **Waiting to Upload** ("not yet stored in iCloud"), **Out of Space**, and a pie chart for progress. To see sync status, hover over iCloud Drive in the sidebar and click the status icon. ([mchlc994344b](https://support.apple.com/guide/mac-help/mchlc994344b/mac), [mchle5a61431](https://support.apple.com/guide/mac-help/mchle5a61431/mac))
- **When iCloud storage is full:** "The document stays on your Mac, and is uploaded to iCloud Drive when space becomes available." ([mchle5a61431](https://support.apple.com/guide/mac-help/mchle5a61431/mac))
- **Broken permissions:** an error banner appears at the top of the iCloud Drive folder with a **Repair** button. ([Change permissions, mchlp1203](https://support.apple.com/guide/mac-help/change-permissions-for-files-folders-or-disks-mchlp1203/26/mac/26))
- **Conflicts:** a dialog lets you choose versions and click **Keep**. Kept duplicates are renamed "Name 2". Versions you do not select are deleted on all devices. ([mh40780](https://support.apple.com/en-gb/guide/mac-help/mh40780/mac))
- **Recovery:** Recently Deleted keeps files for 30 days. Also icloud.com/recovery > Data Recovery > **Restore Files**. "You can't recover or restore files you permanently remove." ([Recover deleted files](https://support.apple.com/guide/icloud/recover-deleted-files-mmae56ea1ca5/icloud))
- **Desktop & Documents:** switching it off leaves the files in iCloud Drive and creates new empty local folders. Signing out gives the option "keep a local copy". Other apps that sync Desktop and Documents "can interfere with or stop" iCloud Drive. ([109344](https://support.apple.com/en-us/109344), [mchle5a61431](https://support.apple.com/guide/mac-help/mchle5a61431/mac))
- **Service status page:** [apple.com/support/systemstatus](https://www.apple.com/support/systemstatus/).
- **CLI `brctl`:** the documented subcommands are `diagnose [-M] [-s] [-n name] [path]`, `download <path>`, `evict <path>`, `log [-c] [-d] [-f predicate] [-m] [-n] [-p] [-w] [-t] [-s]`, `dump`, `monitor [-S scope] <container>` and `versions` ([man page](https://keith.github.io/xcode-man-pages/brctl.1.html)).
  - `brctl status` is **not in the man page**, but people used it on Tahoe. Output looks like `client:idle server:full-sync|… sync:oob-sync-ack last-sync:<date>` or `… SYNC DISABLED` ([Goodrich, Dec 2025](https://mattgoodrich.com/posts/fixing-icloud-drive-sync-issues-macos/), [FlohGro, Feb 2026](https://flohgro.com/blog/fixing-fileproviderd-on-macos-tahoe/)).
  - **Conflict:** icloud-tools says "Apple removed `brctl download` and `brctl evict` in macOS Sonoma 14+" ([repo](https://github.com/icanhasjonas/icloud-tools)). Oakley's guides and a July 2026 forum post still list `brctl download`. **Unverified on 26/27.**
- **CLI `fileproviderctl`:** macOS 14.4 removed `evict`, `materialize`, `domain`, `stabilize`, `listproviders` and other subcommands. What remains is `dump`, `evaluate`, `check`/`repair` and `obfuscate` ([Iva Horn, 2024-03-11](https://i2h3.de/fileproviderctl-changes-macos-14.4/)). On Tahoe people run `fileproviderctl check -v`, `check -P`, and `repair -v -a ~/Library/Mobile\ Documents` ([FlohGro](https://flohgro.com/blog/fixing-fileproviderd-on-macos-tahoe/), [dev forum 837682](https://developer.apple.com/forums/thread/837682)). The exact meaning of each flag is unverified.

### 2.4 Other tools (paid and free)

| Tool | What it does | Price | Relevance | Source |
|---|---|---|---|---|
| **iCloud Control** (Njmcq fork of Obbut) | Finder extension to remove downloads and download again. Last version 1.8.1. The developer no longer updates it and points users to native Finder controls on Sonoma. | Free | Dead | [GitHub](https://github.com/Njmcq/iCloud-Control) |
| **icloud-tools** (icanhasjonas) | CLI: `status`, `download`, `evict`, `pin`/`unpin`, `mv`/`cp` with download-first. Uses `startDownloadingUbiquitousItem`, `evictUbiquitousItem`, `URLResourceValues`, and the xattr `com.apple.fileprovider.pinned#PX`. | Free (14 stars) | Shows these APIs work from unsigned binaries. Developer audience only. | [GitHub](https://github.com/icanhasjonas/icloud-tools) |
| **icloud-guard** (rexbrahh) | Stops unwanted re-downloads: evicts, keeps a watchlist of files that come back, auto-trims. Uses `getattrlistbulk`, `setiopolicy_np` and private FileProvider frameworks. Reads `bird` logs. Sequoia and later. | Free (2 stars) | Niche. Shows `setiopolicy_np` is used in practice. | [GitHub](https://github.com/rexbrahh/icloud-guard) |
| **icloud-nosync** | Zsh function that writes `com.apple.fileprovider.ignore#P`. | Free | Its own README doubts it works on Sequoia and later | [GitHub](https://github.com/edtadros/icloud-nosync) |
| **Carbon Copy Cloner** | Setting "Temporarily download cloud-only files to make a local backup": materializes files, copies them, then evicts them again. Keeps at most 100 files or 2 GB at a time. Bundle placeholders are not downloaded on Ventura. | Price unverified | The best "safety copy" tool, but backup-oriented, not a fixer | [CCC KB (2026-07)](https://support.bombich.com/hc/en-us/articles/20686419951767-Backing-up-the-content-of-cloud-storage-volumes) |
| **LSyncer** (Syntanea) | Filtered folder sync for developers that skips `node_modules`, `.git` and so on. Its own blog says it "will not repair iCloud Drive". | **$19.99** one-time | Covers only the "developer churn" symptom | [lsyncer.syntanea.com](https://lsyncer.syntanea.com/), [blog 2026-05-13](https://lsyncer.syntanea.com/blog/icloud-drive-stuck-uploading-mac/) |
| **CoreGuard** | General health monitor (temperatures, battery, SSD SMART, fans, "what's eating your Mac"). Publishes an article on `fileproviderd` CPU use. "Launching soon". | Free / Pro **$29** / Family **$49**, one-time | Nearby; no iCloud features | [coreguard.app](https://coreguard.app/), [fileproviderd article](https://coreguard.app/insights/what-is-fileproviderd-mac/) |
| **Sweep for Mac** | Cleaner (caches, uninstaller, duplicates). Publishes an iCloud troubleshooting guide that includes risky steps (moving the `CloudDocs` state folder, `sudo killall bird`, and `defaults write com.apple.bird optimize-storage`, which is unverified). | Free scan; plans "start at $9.95/month" | Content-marketing competitor for SEO | [sweepformac.com](https://www.sweepformac.com/), [guide](https://www.sweepformac.com/guides/mac-icloud-drive-not-syncing/) |
| **Data recovery vendors** (Stellar, Tenorshare 4DDiG, Wondershare Recoverit, EaseUS, iBoysoft) | Undelete from local disk. Publish SEO guides for "missing files after Tahoe / Golden Gate". | Stellar "$70" per a Reddit comment (vendor price unverified) | They cannot recover dataless or server-only data. They compete for the same search queries. | [Recoverit Golden Gate guide](https://recoverit.wondershare.com/mac-tips/recover-data-after-macos-27-golden-gate-upgrade.html), [4DDiG Tahoe guide](https://4ddig.tenorshare.com/mac-update/how-to-recover-missing-files-after-macos-tahoe-update.html) |
| **MacPaw (CleanMyMac) / MacKeeper** | SEO articles about high `fileproviderd` CPU | n/a | Content only; no dedicated iCloud rescue feature found (unverified) | [macpaw](https://macpaw.com/how-to/fix-fileproviderd-mac-high-cpu-usage), [mackeeper](https://mackeeper.com/blog/fileproviderd-mac-high-cpu/) |

**Conclusion:** no paid, maintained, GUI product for nontechnical users that *diagnoses and safely unsticks* iCloud Drive was found. The niche is Cirrus (free, expert-level) plus scattered command-line tools and SEO articles.

---

## 3. Howard Oakley's guidance (eclecticlight.co), timeline

| Date | Article | Key guidance |
|---|---|---|
| 2021-12-03 | [What to do when iCloud gets stuck](https://eclecticlight.co/2021/12/03/what-to-do-when-icloud-gets-stuck/) | Run `networkQuality`, then check Apple's system status, then the Cirrus Test Upload ("merely running this test can prove sufficient to kickstart iCloud syncing"), then the log window, then toggling services or signing out ("Ensure that you've downloaded all important documents" first), then wait "a day or two" or contact Apple. |
| 2023-07-24 | [How to fix problems with iCloud and iCloud Drive](https://eclecticlight.co/2023/07/24/how-to-fix-problems-with-icloud-and-icloud-drive/) | `killall bird` then `killall cloudd` (helps in about 90% of his cases). Turn on Content Caching. Avoid Optimise Mac Storage and Desktop & Documents. Move a stuck file out of iCloud Drive and back. Order of escalation: restart, then shut down all devices, then turning iCloud off as a last resort. |
| 2023-10 to 2024-03 | Sonoma series ([radical change](https://eclecticlight.co/2023/10/25/macos-sonoma-has-changed-icloud-drive-radically/), [throttling](https://eclecticlight.co/2024/03/05/icloud-drive-in-sonoma-mechanisms-throttling-and-system-limits/), [Optimise or not](https://eclecticlight.co/2024/03/11/icloud-drive-in-sonoma-optimise-mac-storage-or-not/), [how it works](https://eclecticlight.co/2024/03/18/how-icloud-drive-works-in-macos-sonoma/)) | FileProvider and dataless files. Storage debt. Keep at least one Mac with Optimise **off** as a full copy. Versions were lost on upload until 14.4.1. |
| 2024-07-05 | [Time Machine and iCloud Drive](https://eclecticlight.co/2024/07/05/how-time-machine-backs-up-icloud-drive-in-sonoma/) | Dataless files are not backed up. |
| 2024-09-30 / 2024-10-02 | [Sequoia pinning](https://eclecticlight.co/2024/09/30/how-icloud-has-changed-in-sequoia-pinning-and-more/), [bizarre pinning and Cirrus 1.15](https://eclecticlight.co/2024/10/02/pinning-icloud-drive-in-sequoia-is-bizarre-and-an-update-to-cirrus/) | Pinning bugs: unpinning cascades, the >10-item menu limit, new files in a pinned folder get auto-pinned. |
| 2026-01-06 | [Exclude items](https://eclecticlight.co/2026/01/06/exclude-or-include-items-in-backup-search-icloud-drive-and-quicklook-preview/) | `.nosync` and `.tmp` still work on Tahoe. |
| 2026-04-06 | [Understanding and testing iCloud](https://eclecticlight.co/2026/04/06/understanding-and-testing-icloud/) | Don't just "turn it off and back on"; shut down instead. Changing Optimise can take "several days". |
| 2026-05-12 / 06-02 | [What syncs](https://eclecticlight.co/2026/05/12/what-gets-synced-in-icloud-drive/), [BSD flags](https://eclecticlight.co/2026/06/02/bsd-flags-are-incompatible-with-icloud-drive/) | Extended attribute and BSD flag behaviour on 26.5 (see section 1). |
| 2026-08-25 / 08-26 | [iCloud primer](https://eclecticlight.co/2026/08/25/an-icloud-primer/), [Test with Cirrus](https://eclecticlight.co/2026/08/26/test-icloud-drive-using-cirrus/) | "No diagnostic or troubleshooting tools are provided." Test-first method with Cirrus. |

No Golden Gate-specific iCloud Drive article from Oakley was found as of 2026-09-27. His 2026-09-27 post mentions Golden Gate quirks in LogUI and Finder, not iCloud ([link](https://eclecticlight.co/2026/09/27/last-week-on-my-mac-spinning-plates/)).

---

## 4. Demand evidence and failure patterns (2024 to 2026)

### 4.1 Size and recency signals
- Dev Forums "iCloud for Mac is stuck on 'waiting to upload'" (opened June 2020): 110 replies, about **147k views, 143 participants** ([651829](https://developer.apple.com/forums/thread/651829)).
- Reddit "Finder in iCloud stuck on 'Waiting to Upload'": replies confirm `killall bird` fixes on "Tahoe 26.5.1 (25F80)" (June 2026) and "Sep. 2026 with MacOS 27" ([link](https://www.reddit.com/r/MacOS/comments/11q0r1w/finder_in_icloud_stuck_on_waiting_to_upload/)).
- Tahoe-era Apple Community threads:
  - "Uploading X items" stuck, 2025-10-07, **8 Me too** ([256158466](https://discussions.apple.com/thread/256158466))
  - Cloud icon or syncing issues, 2025-12-15, **12 Me too** ([256212342](https://discussions.apple.com/thread/256212342))
  - 26.2 flipped settings, 2025-12-16, **8 Me too** ([256212969](https://discussions.apple.com/thread/256212969))
  - Tahoe saves Desktop and Documents to iCloud, 2026-01-20, 5 Me too, 15 replies ([256229012](https://discussions.apple.com/thread/256229012))
- TidBITS: a 5-month stuck upload during a Dropbox-to-iCloud migration, fixed only by Apple engineering ([TidBITS 2023-10-12](https://tidbits.com/2023/10/12/cloudy-with-a-chance-of-insanity-unsticking-icloud-drive/)).

### 4.2 Failure patterns

| # | Pattern | Typical symptoms | Examples (date, OS) | Known or likely causes |
|---|---|---|---|---|
| A | **"Waiting to Upload" forever** | Dashed cloud badge. Upload count never reaches 0. | Reddit 2021 to 2026; Dev Forums 651829 | `bird` stalled; one bad item; churning folder; iCloud full; Time Machine or network interference (reported) |
| B | **Larger files stall; small files go through** | Anything larger than about 2 MB stuck; `bird` restart helps for hours | ASC 256158466 (Oct 2025, 26.0); Dev Forums [822534](https://developer.apple.com/forums/thread/822534) (Apr 2026, 26.4.1) | Reported root cause: a stale **HTTP/3 (QUIC) session** in `nsurlsessiond` (FB22476701, filed with Apple, not confirmed by Apple). Log signature: `log show --predicate 'process == "cloudd"' --last 5m \| grep "putContainer.*err=T.*requestDuration=-1.000.*protocol=h3"` |
| C | **Cloud icon that never clears** (false alarm) | Permanent cloud badge on Desktop and Documents in the Tahoe sidebar | MacRumors, Sep 2025 onward, 26.0 to 26.2 ([thread](https://forums.macrumors.com/threads/cloud-icon-next-to-desktop-and-documents-folder.2465899/)) | Users consider it a badging bug, "not an indication of incomplete sync" |
| D | **Files "disappeared"** (really dataless, or Optimize switched on) | Folders present but files missing or 0 KB; apps hang on open | Reddit May 2026 (18,492 evicted files, iCloud full); r/iCloud 2024 ("Lost All Files in Desktop and Documents", several "same here" replies) ([link](https://www.reddit.com/r/iCloud/comments/1c16309/lost_all_files_in_desktop_and_documents_folders/)) | Optimize Mac Storage plus full disk or full iCloud; storage debt. Some cases have no explanation or recovery. |
| E | **An update flips iCloud settings** | Desktop & Documents turned on or off, Optimize turned on without consent, files relocated | ASC 256212969 (26.2, Dec 2025, moderator: "bits get flipped, yes"); ASC 256229012 (26.2 to 26.4.1; toggle reverts); Reddit 26.3.1 (Mar 2026) ([link](https://www.reddit.com/r/MacOS/comments/1rxzx6r/folders_totally_rearranged_after_macos_tahoe_2631/)); ASC 256220553 (Jan 2026) | Files usually end up in `~/iCloud Drive (Archive)`, "Relocated Items", or `iCloud Drive/Desktop/Desktop - <Mac name>` |
| F | **High CPU in `bird` / `fileproviderd` / `cloudd`** | 70 to 95% CPU, Finder hangs, Xcode "Loading…" | FlohGro Feb 2026 (Tahoe): ghost FileProvider extensions, `brctl status` showed "574 containers" SYNC DISABLED. Dev Forums [837682](https://developer.apple.com/forums/thread/837682) (26.5.2, Jul 2026): "Possible slow statement", `fileproviderctl check -P` hangs. Dev Forums [789269](https://developer.apple.com/forums/thread/789269) (15.5): "Waiting on local metadata index". | Corrupt FileProvider database; leftover provider extensions; Spotlight interaction |
| G | **Conflicts and duplicates** | "Name 2" copies, conflict dialog | Apple docs | Offline edits on more than one device. Choosing versions deletes the unselected ones everywhere. |
| H | **Items that cannot sync** | "iCloud Drive error" notifications | Oakley, 26.5 | BSD flags `schg`, `sappnd`, `uappnd`; items over 50 GB (Ineligible); iCloud full ("Out of Space") |
| I | **Developer folders** | Endless uploading; `.git` corruption risk | LSyncer blog 2026; Reddit | Tens of thousands of small files (`node_modules`, `.git`, build output) |
| J | **Account, identity or permission problems** | `client:idle` while items wait; E2E data "not available"; apps permanently denied access | Goodrich Dec 2025 (keychain `<unknown>` item, error 4099, "failed to get ubiquityIdentityToken"); MacRumors Feb 2026 ([link](https://forums.macrumors.com/threads/icloud-problems.2478358/)); Dev Forums [827374](https://developer.apple.com/forums/tags/icloud-drive) (TCC `kTCCServiceUbiquity`/`kTCCServiceLiverpool`, only `tccutil reset All <bundle.id>` fixes) | Corrupt keychain; TCC regression on Tahoe |
| K | **Server-side or account-specific** | Nothing local helps | TidBITS 2023 (5 months, fixed by Apple engineering) | Not fixable by any local tool |
| L | **Sync paused by an app** *(new in macOS 26)* | An item stays unsynced after an app crash | Apple API docs | `pauseSyncForUbiquitousItem` "doesn't automatically resume if the app closes or crashes" |

### 4.3 User fixes that worked (reported), in rising order of risk

| Fix | Evidence | Risk |
|---|---|---|
| Wait, and stop whatever is creating the churn (quit dev servers and builds) | LSyncer blog; Oakley ("a day or two") | None |
| **`killall bird`** (as the user, no sudo) | Many Reddit confirmations up to **Sep 2026 on macOS 27**; Oakley about 90% | Low |
| `killall bird; killall cloudd` | Oakley; TidBITS | Low |
| `killall fileproviderd` (fixed "NSFileProviderInternalErrorDomain error 12") | Reddit ([qkv8l9](https://www.reddit.com/r/MacOS/comments/qkv8l9/folder_is_indefinitely_stuck_in_waiting_to_upload/)) | Low |
| Kill the **user** `cloudd` and `nsurlsessiond` (not the `--system` or `--privileged` ones) for the QUIC deadlock | Dev Forums 822534 | Low to medium |
| `touch` the stuck file or folder | Reddit qkv8l9 | Low |
| Make a new folder, move the contents in, delete the old empty folder | Reddit qkv8l9 | Medium (the move must complete) |
| Move out of iCloud Drive and back in; duplicate the stuck file; zip the folder | Oakley 2023; Reddit; Apple Community | Medium |
| Binary search: move half the folders out to find the file that blocks sync | TidBITS | Medium |
| Turn Optimize Mac Storage off | Reddit (2021, 2026) | **High if storage debt exists** |
| Remove BSD flags (`chflags nouchg,noschg…`) | Oakley 2026; MacRumors 2026 | Medium (`schg` needs root and Recovery on modern macOS; unverified) |
| Disable the second network interface (Wi-Fi plus Ethernet), `renice` bird, VPN off | TidBITS; Reddit | Low |
| Sign out and back in, choosing "Keep a copy" | Many; FlohGro; MacRumors | **High**: TidBITS got 0 KB files in the archive |
| Safe Mode; test in a new user account | Apple Support tech via TidBITS; MacRumors | Low |
| Delete the corrupt `<unknown>` keychain item and duplicate `com.apple.cloudd.deviceIdentifier.Production` entries | Goodrich Dec 2025 (a single report) | High, expert only |

### 4.4 Harmful "fixes" seen in the wild (the app must steer users away from these)
- **Deleting a "CloudDocs" folder.** `~/Library/Application Support/CloudDocs` is bird's *state*. `~/Library/Mobile Documents/com~apple~CloudDocs` holds the *user's files*. A user deleted "the CloudDocs folder" and emptied the Trash, which led to widespread "Waiting to Upload" and doubled System Data ([Reddit, Nov 2025](https://www.reddit.com/r/MacOS/comments/1ovnjcf/deleted_clouddocs_and_now_everything_is_bad/)). Guides still recommend this: [Sweep](https://www.sweepformac.com/guides/mac-icloud-drive-not-syncing/), [Goodrich](https://mattgoodrich.com/posts/fixing-icloud-drive-sync-issues-macos/) (`rm -rf ~/Library/Application\ Support/CloudDocs` and `~/Library/Caches/CloudKit`), and [TidBITS](https://tidbits.com/2023/10/12/cloudy-with-a-chance-of-insanity-unsticking-icloud-drive/).
- Deleting FileProvider databases. CoreGuard: "I would not delete databases under `~/Library/Application Support/FileProvider`."
- Turning iCloud Drive off while items are unsynced: files came back as 0 KB (TidBITS).
- A permissions tool (BatChmod) run on `~/Library` with "Apply to enclosed" left a Mac unable to boot (Tahoe 26.6.1, [MacRumors Aug 2026](https://forums.macrumors.com/threads/locked-files-on-desktop.2486559/)).
- Deleting `/Library/Preferences/SystemConfiguration/*` (reported on Reddit).
- `sudo killall` or `killall nsurlsessiond`, which also kills the system and privileged instances (Dev Forums 822534 warns against it).

---

## 5. Public APIs a Swift app can use (verified from Apple docs JSON)

| API | Availability | Use |
|---|---|---|
| `URLResourceKey.isUbiquitousItemKey`, `ubiquitousItemDownloadingStatusKey` (`URLUbiquitousItemDownloadingStatus.current` / `.downloaded` (stale) / `.notDownloaded`) | macOS 10.9+ | Classify items |
| `ubiquitousItemIsUploadedKey`, `ubiquitousItemIsUploadingKey`, `ubiquitousItemPercentUploadedKey`, **`ubiquitousItemUploadingErrorKey`** | 10.9+ | Find stuck items and **why** (NSError) |
| `ubiquitousItemIsDownloadedKey`, `ubiquitousItemIsDownloadingKey`, `ubiquitousItemDownloadRequestedKey`, `ubiquitousItemPercentDownloadedKey`, **`ubiquitousItemDownloadingErrorKey`** | 10.9+ | Download failures |
| `ubiquitousItemHasUnresolvedConflictsKey`, `NSFileVersion.unresolvedConflictVersionsOfItem(at:)` | 10.7+ | List conflicts |
| **`ubiquitousItemIsExcludedFromSyncKey`** ("locally on-disk, but isn't available on the server") | macOS 11.3+ | Explain "why isn't this in iCloud?" |
| `ubiquitousItemIsSharedKey`, `ubiquitousSharedItem*` keys, `ubiquitousItemContainerDisplayNameKey` | various | Context |
| **`ubiquitousItemIsSyncPausedKey`**, **`ubiquitousItemSupportedSyncControlsKey`** (`NSFileManagerSupportedSyncControls`: `.pauseSync`, `.failUploadOnConflict`) | **macOS 26.0+** | Find items left paused |
| `FileManager.startDownloadingUbiquitousItem(at:)`, `evictUbiquitousItem(at:)`, `isUbiquitousItem(at:)`, `setUbiquitous(_:itemAt:destinationURL:)` | long-standing | Download, evict, move in or out |
| **`pauseSyncForUbiquitousItem(at:completionHandler:)`**, **`resumeSyncForUbiquitousItem(at:with:completionHandler:)`** (`NSFileManagerResumeSyncBehavior`: `.preserveLocalChanges`, `.afterUploadWithFailOnConflict`, `.dropLocalChanges`), **`uploadLocalVersionOfUbiquitousItem(at:withConflictResolutionPolicy:completionHandler:)`** (`.conflictPolicyDefault`, `.conflictPolicyFailOnConflict`), **`fetchLatestRemoteVersionOfItem(at:completionHandler:)`** | **macOS 26.0+** | Could force an upload of one item with fail-on-conflict. Apple recommends `.preserveLocalChanges` "to avoid any risk of data loss". Pausing a regular (non-package) directory fails with `featureUnsupported`. |
| `setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)`; check `SF_DATALESS` | TN3150 | **Scan without triggering downloads** |
| `OSLogStore.local()` | Needs an **admin user**; does not work inside the App Sandbox ([Apple forums 666679](https://developer.apple.com/forums/thread/666679), [Tsai](https://mjtsai.com/blog/2021/12/10/oslogstore-on-monterey/)) | Log evidence (as Cirrus does) |

Unverified, must test on a real Mac:
- whether a third-party app can pause, resume or upload arbitrary `com~apple~CloudDocs` items it did not open,
- whether `ubiquitousItemUploadingErrorKey` is filled in for iCloud Drive items on 26/27,
- which `brctl` subcommands exist on 26/27.

---

## 6. What a safe "iCloud Rescue" could do that Cirrus doesn't

Principle: **read-only first, copy before changing anything, one reversible step at a time, verify after each step.**

1. **Full triage scan that downloads nothing.** Walk `com~apple~CloudDocs`, app containers, `~/Desktop` and `~/Documents`, with dataless materialization turned OFF.
   - Report counts and bytes for: not uploaded; uploading with an error (decode the `NSError`); download errors; conflicts; excluded (`.nosync`, `.tmp`, the exclusion key); **paused** (26+); dataless; pinned; Ineligible (>50 GB); BSD flags (`schg`/`sappnd`/`uappnd`/`uchg`); bundles and symlinks; high-churn trees (`node_modules`, `.git`, `DerivedData`) with file counts.
   - Cirrus shows per-item details and pinned totals. It is not documented to produce this whole-drive "what's wrong" list.
2. **Plain-language verdicts.** For example:
   - "All 12,400 items are in iCloud. The cloud badge is a known Tahoe display bug."
   - "37 items (2.1 GB) exist **only on this Mac**. Here they are."
   - "Your iCloud is full (Out of Space)."
   - "3 files have the system-immutable flag, which iCloud cannot sync."
3. **Storage-debt meter.** Compare the total logical size of dataless items with free space, and show whether turning Optimize off is safe. Oakley says there's no simple way to check this.
4. **Safety copy.** Before any fix, copy every *local-only* item (not uploaded, and not dataless) to a folder outside iCloud or to an external disk. Write a manifest of path, size and SHA-256. This is the core promise.
5. **Guided escalation ladder with verification after each step.** After every step, re-scan and show the count of stuck items going down.
   1. Stop the churn (detect busy dev trees and offer to add `.nosync` or move them out).
   2. Run a test upload of a 1 MB file with timing (like Cirrus).
   3. Restart `bird` for this user.
   4. Restart `fileproviderd`.
   5. Restart the user `cloudd` and `nsurlsessiond` only when the log shows the QUIC signature.
   6. Nudge individual items (`touch`; re-create the folder with a verified copy; on 26+, try `uploadLocalVersionOfUbiquitousItem` with `.conflictPolicyFailOnConflict`).
   7. Offer to clear BSD flags, with consent.
   8. Resume paused items with `.preserveLocalChanges`.
   9. Walk the user through Safe Mode or new-user tests, and sign-out only after step 4 (safety copy) is done. The app never performs these itself.
6. **Evidence log and support bundle.** An exportable report with a timeline and, as an admin user, log excerpts filtered to `com.apple.clouddocs`, FileProvider and `cloudd`. Include instructions for `brctl diagnose` or sysdiagnose so the user can hand it to Apple Support.
7. **Upgrade guard** (links to need 2). Before a macOS update:
   - make a manifest of local-only files,
   - record the Desktop & Documents and Optimize states (how to read these is unverified),
   - make a safety copy.

   After the update, show what moved, and look in `~/iCloud Drive (Archive)`, "Relocated Items" and `Desktop - <Mac name>` folders. This targets pattern E directly.
8. **"Where did my file go?" finder.** Search by name across CloudDocs, the archive folders, Relocated Items, Recently Deleted instructions (icloud.com/recovery) and Time Machine local snapshots. The app does not do the recovery itself; it points to where the file is.
9. **Conflict helper.** List `unresolvedConflictVersionsOfItem` with dates and devices. Save every version to a safe folder *before* the user chooses in Apple's dialog.

**Distribution implication:** the log access (`OSLogStore` or `log show`), restarting user daemons, and a broad scan of `~/Library/Mobile Documents` all point to **Developer ID with notarization outside the Mac App Store**. The sandbox blocks `OSLogStore.local()`. That the sandbox also blocks signalling other processes is likely but unverified. The app needs iCloud Drive access consent, as Cirrus does, and log features need an admin account.

**Testing implication (important for a Windows-only developer):**
- GitHub Actions macOS runners can build the app and run unit tests.
- They almost certainly cannot sign in to iCloud (unverified), so every iCloud behaviour must be tested on a **real Mac with an iCloud account**.
- Also note: VMs on 26.1 "can't access iCloud … with no workaround" ([Oakley 2025-11-04](https://eclecticlight.co/2025/11/04/early-bugs-in-macos-tahoe-26-1-vms-and-finder-services/)).

---

## 7. What must never be promised or done

**Never promise:**
- Recovery of files that exist only on Apple's servers, files deleted more than 30 days ago, or files "permanently removed" (Apple: cannot be recovered).
- A fix for server-side, account, keychain or E2E-key problems (TidBITS: 5 months, fixed by Apple engineering). Say "helps in most local cases" and back it with measured data.
- That uploads will be faster, or that iCloud will "never get stuck again".
- That the app makes iCloud a backup. It is sync, not backup. Recommend Time Machine or CCC.
- Apple endorsement. Also check Apple's trademark rules before putting "iCloud" in the product name (unverified).

**Never do automatically:**
- Delete or move `~/Library/Application Support/CloudDocs`, `~/Library/Mobile Documents/**`, `~/Library/Application Support/FileProvider`, `~/Library/Caches/CloudKit`, keychain items, or `SystemConfiguration` plists.
- Run `fileproviderctl repair`, `tccutil reset All`, or `sudo killall …`.
- `killall nsurlsessiond` (it also kills the privileged instance).
- Toggle iCloud Drive, Desktop & Documents or Optimize, or sign out, on the user's behalf.
- Evict anything not verified as uploaded; `evictUbiquitousItem` on a local-only item is a data-loss risk.
- Empty the Trash.
- Read file contents while scanning: this materializes dataless files and can hang.
- Use `.dropLocalChanges` on resume.
- Write undocumented private extended attributes (`com.apple.fileprovider.pinned#PX`, `com.apple.fileprovider.ignore#P`) as a product feature.
- Change permissions or ACLs recursively.
- Resolve conflicts by deleting versions (Apple deletes unselected versions on all devices).

---

## 8. Open questions (verify on a real Mac running 26.x and 27.0)
1. Which `brctl` subcommands exist on 26/27 (`status`, `download`, `evict`)? Run `brctl help 2>&1` or plain `brctl`. Whether `status` output is stable enough to parse.
2. Are `ubiquitousItemUploadingErrorKey` and `ubiquitousItemIsSyncPausedKey` filled in for third-party-visible CloudDocs items? Can a non-owner app call `resumeSyncForUbiquitousItem` or `uploadLocalVersionOfUbiquitousItem` on them?
3. Where are the Desktop & Documents and Optimize Mac Storage states stored? Can a third-party app read them (key names unverified; do not use `defaults write com.apple.bird optimize-storage`)?
4. Does Cirrus 1.16 list every not-uploaded item with its error? Install it and check, so we can position against it honestly.
5. Did Golden Gate (27.0) change the iCloud Drive status UI or FileProvider behaviour? No authoritative source found. The macOS 27 Mac User Guide lists the same status labels.
6. Mac-side filename rules for iCloud Drive (colon, NFD, length): no Apple source found.
7. The exact TCC service used when a non-sandboxed app reads `~/Library/Mobile Documents`, and the prompt text.

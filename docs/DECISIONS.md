# Whydunit v1: decision document

> **Superseded in part: the app is free ([BUILD_PLAN §10](BUILD_PLAN.md)); pricing/licensing sections are
> historical.** There is no licence, payment, paywall or trial, and the website and update feed are on GitHub Pages.
> Where this document and BUILD_PLAN disagree, BUILD_PLAN wins.

**Date:** 2026-09-27 · **Status:** Decided for v1 · **Author:** solo developer (India), Windows plus GitHub Actions, no local Mac yet

**Inputs:** the eight research reports in `D:\apple\docs\research\` (competitors ×4, tech ×3, distribution/licensing), plus name-collision checks made on 2026-09-27.

**Confidence tags:** **[V]** verified against a primary source (in the research reports or in this pass). **[L]** likely: secondary source, or a standard API not re-fetched. **[U]** unverified: must be tested on real hardware before anything depends on it.

---

## 0. Decisions at a glance

| # | Decision | Choice | Why, in one line |
|---|---|---|---|
| 1 | Product | **One app, "Whydunit"**, sold as an evidence-based troubleshooter: it tells you *why*, then proves the fix | Every incumbent either measures (WhatPort, iStat) or acts blindly (cleaners). None names a cause with evidence. |
| 2 | Name | **Whydunit**, with **Faultwise** as backup. Formal trademark clearance is a gate before buying the domain. | No software product with this name was found. Names built on "Mac…" collide and break Apple's rules. |
| 3 | One app or several | **One app** with modules, one licence and one Core | Shared recorder, report, KB and licensing. $29 needs more than a $6–10 single-purpose tool. |
| 4 | v1 modules | **iCloud Rescue** (need 1) and **Dock Detective** (need 3) | Both are genuine gaps with no paid GUI competitor, and both *fix* or *decide*, not just display |
| 5 | Deferred | Overnight drain → v1.1. Upgrade Rehearsal → v2.0, timed for the macOS 28 Rosetta cliff. System Data → v2.x. VM test-drive → never (hand off to UTM/VirtualBuddy). | Cheap follow-ons first. Upgrade work pays off only when macOS 28 arrives. |
| 6 | Platform | **Apple silicon only, macOS 14.0+**, non-sandboxed Developer ID app | macOS 27 runs only on Apple silicon. Intel lacks the port-controller data and we have no Intel test hardware. |
| 7 | Privilege | **No root, no helper, no Full Disk Access in v1.** Admin-only log features degrade gracefully. Root-level fixes are copy-paste Terminal commands, each with an undo. | This removes the biggest security and review surface |
| 8 | Merchant of record | **Dodo Payments** (Polar as fallback) | Onboards Indian individuals with PAN, charges 4% + 40¢, and has a public licence API |
| 9 | Licence | **Offline Ed25519-signed token** (`WD1.<payload>.<sig>`), minted once by a roughly 40-line Cloudflare Worker in exchange for the Dodo key. Not machine-bound. Never phones home. | A lifetime licence keeps working even if Dodo, the Worker or the company disappear |
| 10 | Trial | **Freemium, no time limit**: record and scan for free; pay to see the *why*, run the wizard, apply fixes and export reports. 14-day refund. | Dock tests run for days, so a trial clock would fight the product |
| 11 | Updates | **Sparkle 2.10.0**, EdDSA. DMGs on GitHub Releases in a public `whydunit-releases` repo, appcast on its GitHub Pages. | Verified CI path, no server needed |
| 12 | Price | **$29 one-time**, $19 for the first 30 days after launch. 3 Macs for one person. All 1.x and 2.x updates included. | Sits in the "clear-job multi-module utility" band ($19–29) and above the $6–10 information apps |
| 13 | CI | XcodeGen, then `xcodebuild archive`/`-exportArchive` on `macos-26`, notarytool with an API key, stapled DMG. Plus a non-blocking `xcode-27` job. | Covered in full by the distribution report |
| 14 | Mac App Store | **No** (not in v1, and no "lite" SKU) | The sandbox and Guideline 2.4.5 remove log access, process restarts, licence keys and Sparkle |

---

## 1. Product positioning and name

### 1.1 Positioning

**One line:** *Whydunit finds out why your Mac misbehaves and proves the fix. Evidence, not guesses. Pay once.*

**Buyer:** a non-technical to prosumer owner of an Apple-silicon Mac who is in the middle of one of two painful, recurring problems:

1. **"My iCloud Drive files are stuck, missing, or say Waiting to Upload."** Dev Forums thread 651829 has about 147k views, and fresh Tahoe/27 reports keep arriving.
2. **"My dock, monitor or external drive keeps dropping out."** Apple Community threads have 279 and 64+ "Me Too" votes, and OWC estimates about 1 in 100 users hit Thunderbolt disk ejects.

**What we say, and who it is aimed at:**

| Competitor | Their stance | Our line |
|---|---|---|
| Cirrus (free, Eclectic Light) | Diagnostic panels for people who read logs | "Tells you in plain English which files are stuck and why, copies what exists only on this Mac, then fixes one reversible step at a time." |
| WhatPort Pro (£9.99) / WhatCable | Records events and explicitly says an event does not prove which cable or device caused a fault | "WhatPort records the events. Whydunit runs the test that names which part to replace, or tells you it's a macOS bug and gives you the workaround." |
| Noah ($8.99/mo or $79/yr AI fixer) | A subscription AI that claims to fix stuck iCloud | "Offline, deterministic, evidence you can show Apple Support, and you pay once." |
| CleanMyMac, cleaners | Scare-scan, then clean | "Read-only by default. Nothing is deleted, ever. Every action is copied first or reversible." |

**Trust posture (a marketing pillar, not an afterthought):** local-only, no telemetry, read-only by default, verified safety copy before any change, `trashItem` and never delete, and a written lifetime-licence policy.

**Content marketing (free, compounding):** one landing page per problem, e.g. "Waiting to Upload on Mac: what each Finder status means" and "Disk Not Ejected Properly after sleep: how to find the cause". Include a "Don't do this" section on the two CloudDocs folders and on `killall nsurlsessiond`. Cleaner and data-recovery vendors currently own these searches.

### 1.2 Name: **Whydunit**

**Rule from Apple's trademark guidelines [V]** (https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html):
- A third-party name may contain "Mac" only when it is paired with a *non-generic* word.
- "Mac" must not be more prominent than the rest of the name.
- The name must not suggest a false association with Apple.

"MacDoctor" fails on the generic-word test, like Apple's own rejected example "MacSales". We avoid "Mac" in the name entirely and use "Whydunit **for Mac**" descriptively.

| Candidate | What the search found (2026-09-27) | Verdict |
|---|---|---|
| MacDoctor | An open-source macOS health/cleaner app `alanqoudif/macdoctor` (https://github.com/alanqoudif/macdoctor); Apple-certified repair shops at macdoctorinc.com (FL), **macdoctor.in (India)** and the-macdoctor.com (UK); and it fails Apple's non-generic-word rule | Rejected |
| Culprit | "CULPRIT" retail app on the App Store (https://apps.apple.com/us/app/culprit/id6448399003) | Rejected |
| Casefile | Maltego CaseFile (investigation software), the Casefile True Crime podcast, a "Casefile" MCP server | Rejected |
| Rootle | PBS KIDS "Rootle" 24/7 channel, an iOS vocabulary app, rootle.ai | Rejected |
| Rootwise | RootWise AI parenting app, rootwise.studio, rootwise.app in use | Rejected |
| Sleuth | The Sleuth Kit (forensics), the "MacSleuth" TryHackMe series | Rejected |
| Mac Detective | Apple-services business in Mauldin, SC | Rejected |
| Hunchless | Domain `hunchless.app` already resolves | Rejected |
| Probable Cause | Only generic usage found, but it is a stock legal phrase and a weak mark | Rejected |
| **Whydunit** | No software or app product found. It is a literary-genre word. The nearest mark is the iOS game **"Whodunit?™: Murder Mystery"** (https://apps.apple.com/us/app/whodunit-murder-mystery/id6605932965): a different word and different goods (games vs system utility), but the same Class 9 | **Chosen** |
| **Faultwise** | Zero web results | **Backup** |

**Gate (week 1):** run a formal clearance search for "Whydunit" in Classes 9 and 42 on USPTO, EUIPO and IP India before buying a domain or printing anything. **Status: unverified.** Only web searches were done here, and domain availability was not checked. If the search turns up a live Class 9/42 conflict, switch to Faultwise with no further debate.

**Module names inside the app** (they fit the detective theme): **iCloud Rescue** and **Dock Detective**. Later: **Sleep Detective** (v1.1) and **Upgrade Rehearsal** (v2).

### 1.3 One app, not several

**Decision: one app.**

1. **Shared machinery is most of the work.** The event recorder, evidence and verdict model, HTML report, redactor, signed KB updater, licensing, Sparkle and the CI pipeline are identical across modules. Three apps would mean three of each.
2. **Price support.** Single-purpose diagnostic tools sell for $6–15 (WhatPort £9.99, Rosetta Check $6.99, DaisyDisk $9.99). A multi-module "fixes the thing" tool supports $24–29 (DriveDx, EtreCheck $19.99, Sleep Aid $25, Juicy lifetime $24.99).
3. **Cross-module evidence.** Sleep and wake events feed both Dock Detective and the v1.1 drain report. The iCloud manifest feeds the v2 upgrade diff.
4. **Marketing.** One brand and one domain accumulate reputation. Per-problem landing pages still capture per-problem search, and all of them point at one download.
5. **The one downside** is weaker App Store discoverability for single-purpose apps. We are not on the App Store, so it does not apply.

---

## 2. v1 scope

### 2.1 What ships in v1.0

| Piece | Contents | Estimate (solo, full-time) |
|---|---|---|
| Shared | App shell (window plus `MenuBarExtra`), JSONL event store, Case/Finding/Verdict model, HTML report and redactor, signed KB updater, licensing and paywall, Sparkle, CI/release | 2.5 weeks |
| **Module A: iCloud Rescue** | Read-only triage scan, classifier, 1 MB probe, storage-debt meter, "where did my files go" finder, verified safety copy, consent-gated fix ladder | 5 weeks |
| **Module B: Dock Detective** | Always-on cross-layer recorder, lifetime-counter snapshots, episode builder, 12 preflight rules, A/B wizard with Fisher-exact scoring, verdicts, reversible fixes, vendor/Apple support packet | 6 weeks |
| Beta and hardening | Two closed betas (iCloud from week 7, dock from week 14), fixture corpus, KB seeding | 3 weeks |
| **Total** | | **≈16–17 weeks: launch around late January 2027** if work starts 2026-09-28 |

**Build order:**
1. **Week 1:** order the Mac and test gear, enrol in the Apple Developer Program, name clearance, Dodo account, repo, CI.
2. **Weeks 2–6:** iCloud Rescue. It needs only one Mac and an iCloud account.
3. **Week 7:** private iCloud beta on the Sparkle beta channel, 20–30 users recruited from the Apple Community and Reddit threads.
4. **Weeks 7–12:** Dock Detective.
5. **Week 13:** licensing, paywall and website.
6. **Weeks 14–16:** dock beta with users who have live problems.
7. **Week 17:** v1.0.

**Hardware (mandatory, before week 2):**
- one **Apple-silicon MacBook**. A laptop is required for battery, lid, accessory-security (TRM) and MagSafe behaviour. Enrolling in the Developer Program in India also requires the Apple Developer app on an Apple device [V].
- one Thunderbolt 4 dock
- one USB-C hub with HDMI
- one bus-powered USB SSD
- one USB HDD
- one DisplayPort/HDMI monitor
- one TB4 cable
- one cheap USB2-only USB-C cable, to trigger the preflight rules

Prices were not researched. iCloud behaviour on macOS 15, 26 and 27 can also be tested in Virtualization.framework VMs on that Mac: host and guest must run 15+ and the VM must be created from a 15+ image [V: Apple "Using iCloud with macOS virtual machines"]. Dock behaviour cannot be tested in a VM.

### 2.2 Module A: iCloud Rescue

**User-facing jobs**

1. "Tell me which files are stuck, and why, in plain English."
2. "Tell me which files exist **only on this Mac**, so I don't lose them."
3. "Is iCloud itself stalled, or only some files?"
4. "Fix it safely, one reversible step at a time, and prove it worked."
5. "An update moved or hid my files. Where are they?"
6. "Is it safe to turn off Optimize Mac Storage?"

**Data sources and APIs** (all public; no iCloud entitlement; non-sandboxed)

| Need | Source |
|---|---|
| Inventory | `FileManager.enumerator(at:includingPropertiesForKeys:options:)` over `~/Library/Mobile Documents/com~apple~CloudDocs`. Also `~/Desktop` and `~/Documents` when `URLResourceValues.isUbiquitousItem == true` on those folders. Options: `.skipsPackageDescendants`, and **not** `.skipsHiddenFiles`. A non-sandboxed read of CloudDocs works [V: DTS, forum 727902]. |
| Never materialize | A dedicated scan thread calls `setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)`, and the scanner handles `EDEADLK` [V: TN3150]. File contents are never read during a scan. |
| Per-item status | `URLResourceKey`: `.isUbiquitousItemKey`, `.ubiquitousItemIsUploadedKey`, `.ubiquitousItemIsUploadingKey`, `.ubiquitousItemUploadingErrorKey`, `.ubiquitousItemDownloadingStatusKey`, `.ubiquitousItemDownloadingErrorKey`, `.ubiquitousItemHasUnresolvedConflictsKey`, `.fileSizeKey`, `.totalFileAllocatedSizeKey`; on macOS 26+ also `.ubiquitousItemIsSyncPausedKey` and `.ubiquitousItemSupportedSyncControlsKey` [V docs]. Call `removeAllCachedResourceValues()` before every poll. **Every value is Optional, and nil means "unknown", never "ok"**: `ubiquitousItemDownloadingStatus` was reported nil for every materialized file on macOS 26 [L]. |
| Dataless and BSD flags | `lstat` → `st_flags`: `SF_DATALESS` (0x40000000) [V], and `SF_IMMUTABLE` (schg), `SF_APPEND` (sappnd), `UF_APPEND` (uappnd), `UF_IMMUTABLE` (uchg) from `<sys/stat.h>` [L]. |
| Pinned | xattr `com.apple.fileprovider.pinned` (read only) [V: Oakley] |
| Free space | `URLResourceKey.volumeAvailableCapacityForImportantUsageKey` on the home volume |
| Global probe | Write a 1 MB file `Whydunit Probe/probe-<uuid>.bin` into CloudDocs. The extension must **not** be `.tmp` or `.nosync`, which are excluded. Poll `ubiquitousItemIsUploadedKey` every 5 s for up to 120 s, then remove the probe with `trashItem(at:resultingItemURL:)`. |
| Cause strings (admin only) | `/usr/bin/log show --last 10m --style ndjson --predicate 'process == "cloudd"'`, matched in Core against the HTTP/3 signature `putContainer.*err=T.*requestDuration=-1\.000.*protocol=h3` [L: forum 822534]. For `fileproviderd`, the string "Possible slow statement" [L]. |
| Enrichment (optional, time-boxed at 10 s, parsed defensively) | `/usr/bin/brctl status` [L: still present on 27.0]. **Not** `brctl download/evict`, which is disputed [U]. |
| Conflicts | `NSFileVersion.unresolvedConflictVersionsOfItem(at:)` (read only in v1). Behaviour for a non-entitled app is [U]. |

**Diagnosis rules** (pure functions in Core: `ItemRecord → [Finding]`)

| ID | Trigger | Plain-English verdict | Safe next step |
|---|---|---|---|
| I1 | `uploadingError` is `NSCocoaErrorDomain` 4354, or `NSFileProviderErrorDomain` −1003 | "Your iCloud storage is full; nothing more can upload." | Link to the iCloud storage page. Show the size of what is waiting. |
| I2 | 4355 or FP −1004 | "Apple's servers can't be reached from this Mac." | Network check, probe, then retry |
| I3 | FP −2005 (`cannotSynchronize`) **and** the item is a package **and** macOS is 26.2 | "A known macOS 26.2 bug stops packages syncing; fixed in 26.3." | Update macOS (from KB) |
| I4 | −2005, any other case | "iCloud refused this item." | Per-item ladder L6 |
| I5 | `st_flags` has schg, sappnd or uappnd | "A lock-type flag blocks sync (macOS 26.5+)." [V: Oakley] | Clear uappnd in-app with consent (`lchflags`). For schg/sappnd, show a copyable `sudo chflags noschg,nosappnd "<path>"`. |
| I6 | Logical size > 50 GB | "Too big for iCloud (the 50 GB limit): Finder calls it Ineligible." [V] | Move it out of iCloud, or split it |
| I7 | Name ends `.nosync`/`.tmp`, or is on Oakley's auto-exclusion list | "Not stuck: iCloud never syncs this by design." | None (info only) |
| I8 | `hasUnresolvedConflicts == true` | "Two versions disagree." | Open in Finder. Warn that versions you don't keep are deleted everywhere [V] (conflict helper arrives in v1.2) |
| I9 | macOS 26+ and `isSyncPaused == true` | "An app paused this file and never resumed it (for example after a crash)." | `resumeSyncForUbiquitousItem(at:with: .preserveLocalChanges)` |
| I10 | Not uploaded, no error, older than 2 h, **probe OK** | "iCloud works, but these specific files are stuck." | Per-item ladder (L1, L6) |
| I11 | **Probe fails** (not uploaded within 120 s) | "iCloud sync is stalled for the whole Mac: don't touch individual files yet." | Daemon ladder (L3 to L5) |
| I12 | Admin, and the log matches the HTTP/3 signature | "Known stale-connection stall (reported on 26.4.1)." | L5 |
| I13 | Σ logical size of `SF_DATALESS` items > free space | "Storage debt: turning off Optimize Mac Storage would need X GB you don't have. Don't turn it off." | Free space first |
| I14 | Directory named `node_modules` or `.git` with > 5,000 descendants inside iCloud | "Developer folders churn and clog sync." | Move out, or rename to `.nosync` (guided) |
| I15 | Any of `~/iCloud Drive (Archive)`, `/Users/Shared/Relocated Items`, or a second Mac's `Desktop - <Mac>` / `Documents - <Mac>` folder inside iCloud Drive's Desktop/Documents exists [L: folder names from Oakley and user reports] | "An update or setting change moved files here." | Show them in Finder |
| I16 | `isUploaded == false` (or nil) and not dataless | "**N items (X GB) exist only on this Mac.** Do not sign out, turn off iCloud Drive or 'reset' anything yet." | Safety copy (L0) |
| I17 | User reports a cloud badge but every item is uploaded with no errors | "A Finder display bug; your files are fine." [L: Tahoe badge reports] | None |

**Safe actions: the fix ladder.** Each step has its own consent sheet stating what it does and how to undo it. Every step ends with a re-scan and a probe, and the ladder stops as soon as the problem is resolved. An audit log of every step is kept in the case.

- **L0 Safety copy.** Required before L3 and above.
  - Coordinated read (`NSFileCoordinator`, `.withoutChanges`) of every local-only affected item into `~/Library/Application Support/Whydunit/Rescue/<ISO-date>/`, or into a user-chosen folder. The app refuses any destination inside an iCloud-synced tree.
  - Preflight: free space must be at least 2× the copy size, and each item must be local (not `SF_DATALESS`).
  - Write a `manifest.json` with a streamed CryptoKit `SHA256` for every file, and a per-file manifest inside packages.
  - Abort on any hash mismatch.
- **L1 Remove per-item blockers.** Clear user flags; rename is guided only.
- **L2 Probe.** Classifies the problem as global or per-item.
- **L3 Restart the user's `bird`.** Run `/usr/bin/pkill -TERM -x -U <uid> bird`; launchd respawns it [L]. Wait 60 s, then probe. Never loop.
- **L4 Restart the user's `fileproviderd`.** Only if `pgrep -x -U <uid> fileproviderd` finds it running as the user; otherwise skip [U: whether it runs per user].
- **L5 Only when I12 matched:** `pkill -TERM -x -U <uid> cloudd`, then `nsurlsessiond`, touching the user's instances only.
- **L6 Per-item nudge.**
  - (a) On macOS 26+, if `ubiquitousItemSupportedSyncControls` contains `.failUploadOnConflict`, call `uploadLocalVersionOfUbiquitousItem(at:withConflictResolutionPolicy: .conflictPolicyFailOnConflict)` [V API; U whether iCloud Drive honours it for a non-entitled caller, so every error is caught and falls through to (b)].
  - (b) Otherwise use **Oakley's move-out / move-back, one item at a time**: move into `…/Whydunit/Staging/`, let the rest sync (probe), move back, re-hash, and wait for `isUploaded`.
- **L7 Resume items paused by crashed apps** with `.preserveLocalChanges`.
- **L8 Guided only, never automated,** and shown only after a verified L0:
  - Safe Mode test
  - new-user test
  - sign out with "Keep a copy"
  - Apple Support packet: our report plus instructions for `brctl diagnose`

**Never, in any version** (enforced in code review, and by a CI grep that fails the build if `removeItem` appears under `WhydunitMac/ICloud/`):
- delete anything
- move or delete CloudDocs, Mobile Documents, FileProvider or CloudKit caches or databases
- run `fileproviderctl repair`, `tccutil reset`, `sudo killall`, or kill any root-owned daemon
- toggle iCloud settings or sign out
- evict items that are not verified as uploaded
- set `ubiquitousItemIsExcludedFromSync` (it hangs [V])
- use `.dropLocalChanges`
- write private xattrs
- change permissions or ACLs recursively
- read file contents during a scan
- empty the Trash
- promise recovery of server-only files or files deleted more than 30 days ago

**Out of scope for v1:**
- iCloud Photos, Mail, Messages and Keychain
- third-party app containers under `~/Library/Mobile Documents/` (e.g. Obsidian), which move to v1.2 as read-only
- the conflict-version saver (v1.2)
- Dropbox, Google Drive and other FileProvider domains
- any server-side or account problem (reported as "nothing local will fix this; here's your support packet")

### 2.3 Module B: Dock Detective

**User-facing jobs**

1. "Record what happens when it drops, even overnight."
2. "Tell me if my setup is impossible or blocked before I waste days."
3. "Run a guided test and tell me *which part* (dock, cable, port, device, or macOS) is the cause, with a confidence level."
4. "Give me the fix, or the workaround if it's a macOS bug."
5. "Give me a report I can send to the dock vendor or Apple."

**Data sources and APIs** (no root, no entitlements, no FDA; all from the tech report)

| Layer | API / source | Records |
|---|---|---|
| Sleep/wake | `IORegisterForSystemPower`. Define the constants yourself: `kIOMessageSystemWillSleep` 0xE0000280, `kIOMessageSystemHasPoweredOn` 0xE0000300, `kIOMessageCanSystemSleep` 0xE0000270. Acknowledge with `IOAllowPowerChange` within 30 s [V]. Also `NSWorkspace.willSleepNotification` / `didWakeNotification` / `screensDidWakeNotification`. | Timestamps |
| DarkWake and reasons | `/usr/bin/pmset -g log` [L: no admin needed], parsed in Core with the report's regex `^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d [+-]\d{4}) (\S+(?: \S+)?)\s{2,}(.*)$` plus `due to (?:'([^']+)'\|(\S+))` | Sleep / Wake / DarkWake reasons |
| USB | `IONotificationPortCreate(kIOMainPortDefault)` + `IOServiceAddMatchingNotification` on `IOUSBHostDevice` (`kIOFirstMatchNotification`, `kIOTerminatedNotification`), draining the iterator to arm it. Read keys **one at a time** with `IORegistryEntryCreateCFProperty`, never the bulk call, because of a crash risk [V]. Keys: `idVendor`, `idProduct`, `locationID`, `Device Speed`, `bcdUSB`, `USB Product Name`, `UsbIOPort` (macOS 26+). | Attach/detach, speed |
| Thunderbolt | Match both `IOIOThunderboltSwitch` and `IOThunderboltSwitch`. On `IOThunderboltPort`: `Current Link Speed`, `Current Link Width`, `Supported Link Speed`, `Supported Link Width` [V: WhatCable source] | Dock link and degradation |
| Port controller (Apple silicon) | `AppleHPMInterfaceType10/11/12/18`, `AppleTCControllerType10/11` (keep nodes whose `PortTypeDescription` is USB-C or MagSafe*). Keys: `ConnectionActive`, `TransportsActive`, `Plug Event Count`, `ConnectionCount`, `Overcurrent Count`. `IOServiceAddInterestNotification(kIOGeneralInterest)` catches `kIOMessageServicePropertyChange` (0xE0000130) [V]. | Plug and over-current counters |
| Accessory security | `IOPortTransportState*` → `TRM_TransportRestricted`, `TRM_DeviceLocked`, `TRM_StateDescription` [V keys; reason codes U] | "Blocked by macOS" |
| Root and hub port stats | `AppleUSBHostPort` subclasses → `port-statistics` → `kPortStatConnectCount`, `kPortStatOverCurrentCount`, `kPortStatEnumerationFailureCount` [V] | Lifetime counters |
| Drives | `DASessionCreate`, `DARegisterDiskAppearedCallback`, `DARegisterDiskDisappearedCallback`, `DARegisterDiskUnmountApprovalCallback` (return nil after marking the BSD name as "graceful") [V: DiskArbitration source], plus `NSWorkspace.didUnmountNotification`. **We never open files on external volumes**, so no Removable Volumes prompt appears [L]. | Graceful vs surprise removal |
| Displays | `CGDisplayRegisterReconfigurationCallback` (`.addFlag`, `.removeFlag`, `.setModeFlag`, `.mirrorFlag` …) [V], `CGGetOnlineDisplayList`, `CGDisplayIsBuiltin`, `CGDisplayMirrorsDisplay`. `IOPortTransportStateDisplayPort` → `HPD_State`, `LinkRate`, `LaneCount`, `DriverStatus` [V]. | Drops, flaps, link |
| Power | `IOPSNotificationCreateRunLoopSource`, `IOPSCopyExternalPowerAdapterDetails()`, `AppleSmartBattery` → `ChargerData.NotChargingReason`, `ChargerResetCounter`, `PortControllerInfo.PortControllerHardResetCount` [V] | Charging-chain faults |
| Network through the dock | `NWPathMonitor` (wired interface appears or disappears) | Confirms a dock-wide drop |
| Cause strings (admin only) | For a ±90 s window around each episode, spawn `/usr/bin/log show --style ndjson --start "<t-90s>" --end "<t+90s>" --predicate 'process == "kernel" AND (sender == "IOUSBHostFamily" OR sender == "IOAccessoryManager" OR sender == "apfs" OR sender == "IOUSBMassStorageDriver")'` [V fields, L `--end`]. Core matches `terminateDevice: … (hardware connection lost\|link change interrupt\|connect change interrupt)`, extracts the port (`usb-drdN-port-*` vs `AppleUSB*HubPort@…`), and looks for `Found dangling mount`. | Physical vs link, and root vs hub |
| Dock firmware (best effort) | `system_profiler SPThunderboltDataType -json` at preflight only. The firmware key name is [U]; capture a fixture on real hardware. | Firmware vs KB baseline |

We do **not** rely on `OSLogStore.local()`. The CLI's predicate fields are verified; OSLogStore's `process`/`sender` predicates are [U]. Both need admin. The recorder must already be running when the fault happens: "launch at login" is enabled at first run through `SMAppService.mainApp.register()`, and the user can turn it off.

**Episode rules** (Core: events within a 5 s cluster become an Episode)

| ID | Pattern | Classification |
|---|---|---|
| E1 | At least 2 USB devices under one upstream hub terminate within 2 s, and/or the TB switch terminates, and/or the dock's wired interface disappears. With the admin log: root port `usb-drd*` reports `link change interrupt`. | **Dock-wide drop**: Mac↔dock segment or the dock |
| E2 | One device terminates and its siblings stay. Log: `AppleUSB*HubPort` reason. | **Single-device drop**: the device, its cable, or that dock port |
| E3 | `hardware connection lost` + `cableChangeOccurred`, or HPM `Plug Event Count` rises during a hands-off window | **Physical disconnect** (connector or cable movement). Excluded if the user pressed "I unplugged something". |
| E4 | DA disappeared, with no graceful mark, while `VolumePath` was set | **Surprise eject** (data risk). Links to the E1/E2 cluster. |
| E5 | CG `.removeFlag` on an external display, with `HPD_State` toggling or the DP transport going inactive, followed by `.addFlag` within 10 s | **Display flap** |
| E6 | Episode starts within 30 s after `HasPoweredOn` or a pmset DarkWake | Tagged **sleep-linked** |
| E7 | `kPortStatOverCurrentCount` or `Overcurrent Count` delta > 0 | **Over-current** at that port |

**Preflight rules** (run in about 5 s and give verdicts before any multi-day test)

| ID | Check | Verdict |
|---|---|---|
| P1 | Connected or desired external displays > the chip's limit (KB table keyed by `sysctl hw.model`; seeded from Apple 122212: MacBook Air M4/M5 = 2 [V]; other rows filled from Apple spec pages as verified) | "Your Mac can drive N external displays. No hub or dock changes that." |
| P2 | A daisy-chain or MST hub where displays end up mirrored (`CGDisplayMirrorsDisplay`) | "macOS supports MST only as mirroring." [V] |
| P3 | A USB device with `idVendor == 0x17E9` (DisplayLink [V]) and no running process named "DisplayLink Manager", or free disk space < 10 GB | "DisplayLink screens need DisplayLink Manager running, its Screen & System Audio Recording permission, and free disk space." [V: Plugable KB] |
| P4 | `TRM_TransportRestricted` or `TRM_DeviceLocked` is true | "macOS is blocking data from this accessory (it can still charge). Unlock the Mac or allow it. A Mac locked for 3+ days may need unlocking." [V: Apple 102282] |
| P5 | `Device Speed` ≤ 2 while `bcdUSB` ≥ 0x0300 | "Running at USB 2 speed: the cable or hub is USB2-only." |
| P6 | TB `Current Link Speed/Width` < `Supported` | "The dock link trained below its rated speed: suspect the cable." |
| P7 | Over-current delta since the last snapshot | "A device drew too much power: give it a powered hub or dock port." |
| P8 | macOS version/build matches a KB known issue (e.g. 26.4 HFS auto-mount → `diskutil mount`; 27.0 HDMI-audio stall → toggle HDR or match refresh rates [L]) | "This is a macOS bug. Workaround: …" |
| P9 | Dock firmware < KB baseline (e.g. CalDigit TS4 45.1 [V]) | "Update the dock firmware" plus a vendor link |
| P10 | `pmset -g` shows `disksleep` > 0, an HDD is attached, and E4 episodes are sleep-linked | "Disk sleep is ejecting your drive." Generated command: `sudo pmset -a disksleep 0` (undo restores the value recorded beforehand) |
| P11 | `LiquidDetected` is true | "Liquid detected in a port: unplug and let it dry." |
| P12 | `ChargerResetCounter` or `PortControllerHardResetCount` delta > 0, or `NotChargingReason` ≠ 0 | "Power negotiation is failing: suspect the charger or cable." |

**Guided A/B wizard**

- **Arms change exactly one variable versus the baseline:**
  - **Direct** (bypass the dock)
  - **Other Mac port** (each Apple-silicon TB port is its own bus [V: OWC])
  - **Other cable**
  - **Sleep blocked**: while the arm runs, the app holds `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep …)`
  - **Dock power-cycled / firmware updated** (a prompted step)
- A case runs **baseline plus up to 2 variant arms**.
- **Session** = one sleep→wake cycle, or a 2-hour awake block. A session "fails" if it contains at least one E1–E5 episode for the target device.
- **Minimum per arm:** at least 5 sessions **and** at least 24 h, **or** the baseline has already shown at least 3 failures. The wizard survives reboots, shows progress in the menu bar, and sends a notification when an arm is done.
- **Hands-off rule:** don't touch cables during an arm. An "I unplugged something" button annotates and excludes that session (plug counters also rise when you unplug the far end [V]).
- **Scoring:** a two-sided Fisher exact test on the 2×2 table (failing vs clean sessions, baseline vs variant), in Core. Unit-test vectors:
  - `[[3,1],[1,3]]` → p = 34/70 = 0.4857
  - `[[5,2],[0,7]]` → p = 42/2002 = 0.0210
- **Evidence strength:**
  - **Proven**: p < 0.05, variant failure rate lower, and admin log reasons consistent
  - **Likely**: p < 0.2 with at least 3 baseline failures, **or** a preflight rule hit
  - **Possible**: a single-episode classification
  - **Unknown**: nothing reproduced. "Keep recording": no verdict is invented.

**Verdict tree:**
1. Any preflight hit → verdict immediately, before testing.
2. Baseline fails, **Direct** clean → "the dock chain". Next arm: **other cable** (Mac↔dock). If that one is clean → "**replace the cable**"; otherwise → "**the dock** (power-cycle; firmware; vendor packet)".
3. Baseline fails **and** Direct fails, and episodes are E6 sleep-linked with a clean **Sleep blocked** arm → first-class verdict: "**It's macOS <build>'s sleep/wake handling**", followed by the workaround (P10 command, keep awake while docked, KB item).
4. Baseline fails, Direct fails, not sleep-linked → "**the device or its own cable**" (E2 plus hub-port reasons support this).
5. **Other Mac port** clean while baseline fails → "**one Mac port/controller**": use the other port and consider Apple service.
6. Nothing fails → "Couldn't reproduce yet."

**Safe actions** (all reversible)
- Hold a sleep assertion (released on quit).
- Back up the user-domain `~/Library/Preferences/ByHost/com.apple.windowserver.displays*.plist` into the case folder, then `trashItem` it and prompt for a restart. This is the most-cited fix in thread 256135940 [V]. Undo: move the backup back.
- For the `/Library/Preferences/com.apple.windowserver*.plist` variant: show a copyable `mkdir -p ~/Whydunit-Backup && sudo mv /Library/Preferences/com.apple.windowserver*.plist ~/Whydunit-Backup/` with an undo command.
- `diskutil mount <BSD name>` button for the 26.4 HFS auto-mount bug.
- Timed dock power-cycle prompt (unplug power for 30–45 s [V: CalDigit rep]).
- Vendor firmware links from the KB.
- **Support packet:** a self-contained HTML report with the verdict first, the timeline, counters, matched log lines and system summary. It is redacted and previewed before saving; use "Print to PDF" for a PDF.

**Out of scope for v1:**
- SMART (needs a kext and Reduced Security)
- EDID and e-marker decoding (BetterDisplay and WhatCable do this)
- DDC/brightness
- firmware flashing
- Intel Macs
- automatic eject-before-sleep (v1.2)
- per-port power graphs
- Wi-Fi/Bluetooth diagnosis
- any kext or system extension

### 2.4 Shared pieces

- **Known-issue KB:** a signed JSON file (`kb.json` + `kb.json.sig`, Ed25519, a separate offline key) on the releases repo's GitHub Pages, checked at most once a day, with a bundled copy as fallback.
  - Keyed on macOS version/build × `hw.model` × dock VID/PID × firmware.
  - Also holds the chip display-limit table and `revokedLicenses`.
  - **The KB can reference only action IDs compiled into the app plus text and URLs. Remote data can never introduce a new command.**
  - Seed entries: CalDigit TS4 firmware 45.1 baseline; the Plugable UD-ULTC4K/UD-ULTCDL/UD-3900PDZ issue; 26.4 HFS auto-mount; the 27.0 HDMI-audio stall; the 3-day-lock accessory rule; the 26.2 package −2005 bug; the 26.4.1 HTTP/3 stall.
- **Case model:** Case → Findings (evidence list, plain-English cause, strength, one next step, undo) → Actions (audit log).

### 2.5 Free vs paid (freemium; no trial clock)

| Free, forever | Paid ($29 lifetime) |
|---|---|
| Recorder and timeline, the iCloud scan, finding **titles and counts**, preflight **titles** | Full plain-English cause, evidence and next step for every finding |
| Safety warnings ("N items exist only on this Mac: don't sign out"), plus a CSV export of that list | Verified safety copy, the whole fix ladder, one-click fixes |
| KB updates | A/B wizard and verdicts |
| | HTML support/vendor report |

Safety-critical warnings are never paywalled. Users can always copy their own files by hand from the exported list.

### 2.6 Roadmap after v1.0

| Release | When | Contents |
|---|---|---|
| **v1.1 Sleep Detective** | about 3 weeks after launch | Overnight-drain report: the pmset DarkWake reasons already parsed, `pmset -g assertions` sampled every 10 min while on battery, battery % delta per sleep session, and top wake reasons with fixes (e.g. "TCPKeepAlive/Power Nap", Bluetooth wake). Reuses the recorder. The only dedicated competitor, Sleep Aid, stalled at 1.5 (April 2025). |
| **v1.2** | about 6 weeks after launch | Read-only scan of iCloud app containers (Obsidian etc.); conflict-version saver (copy every `NSFileVersion` before Apple's dialog); evidence-scoped eject-before-sleep for volumes with E4 history |
| **v2.0 Upgrade Rehearsal** | beta at WWDC in June 2027, when the macOS 28 beta arrives; GA before macOS 28 ships in fall 2027 | Details below |
| **v2.x System Data explainer** | when demand shows | Storage-category diff over time, naming the grower (e.g. `tmutil listlocalsnapshots /`) |
| **Technician licence** | when at least 5 consultants ask | $99, for use on client Macs (DriveDx precedent) |

**Why v2.0 is timed that way.** Rosetta works in full until macOS 28 [V: Apple 102527], so 28 is the cliff, not 27.

**What v2.0 Upgrade Rehearsal contains:**
- **Baseline snapshot** taken before the upgrade:
  - Mach-O scan of apps and nested helpers
  - the plug-in catalog (AU/VST3/CLAP/AAX/HAL/printers/…)
  - `auval -a`
  - `systemextensionsctl list`, `kmutil showloaded --collection aux --list-only`
  - launchd plists
  - processes currently translated under Rosetta (`P_TRANSLATED`)
  - Intel Homebrew prefix
  - "Open using Rosetta" flags
- **Compatibility sources:** Homebrew cask data (BSD, `caveats_rosetta`), a curated `compat.json` of vendor status, and Apple's on-device `IncompatibleAppsList.plist` (read locally, never redistributed).
- **"My workflow" checklist**, run before and after the upgrade.
- **Rollback readiness:** a recent Time Machine backup or clone.
- **Post-upgrade diff and fixes**, e.g. `softwareupdate --install-rosetta --agree-to-license` on 27.

**Never:**
- the VM "test drive". Instead, a guide to UTM or VirtualBuddy: App Store apps won't run in VMs, the SLA limits VM use, and CI cannot test it.
- charge limiting, fan control, junk cleaning
- a Mac App Store SKU

---

## 3. Architecture

### 3.1 Repository layout (private repo)

```
whydunit/
├─ project.yml                     # XcodeGen: app target "Whydunit" (macOS 14.0, arm64), Sparkle via SPM
├─ ExportOptions.plist             # method developer-id, signingStyle manual
├─ App/                            # SwiftUI: WindowGroup + MenuBarExtra, views only
│   ├─ Info.plist                  # SUFeedURL, SUPublicEDKey, NSDesktopFolderUsageDescription, NSDocumentsFolderUsageDescription
│   └─ Whydunit.entitlements       # hardened runtime; NO sandbox; no other entitlements
├─ Packages/
│   ├─ WhydunitCore/               # Foundation-only. Builds on Windows, Linux, macOS. No IOKit/AppKit/CryptoKit/os.
│   │   ├─ Sources/WhydunitCore/
│   │   │   ├─ Model/              # Event, Episode, Session, Arm, Case, Finding, Verdict, Evidence, Action
│   │   │   ├─ Parsers/            # PmsetLog, LogNDJSON, IORegPlist, SystemProfilerJSON
│   │   │   ├─ Dock/               # EpisodeBuilder, PreflightRules, Fisher, VerdictTree
│   │   │   ├─ ICloud/             # ItemRecord, Classifier, ErrorCatalog, Exclusions, StorageDebt, Manifest
│   │   │   ├─ KB/                 # KnownIssue, Matcher
│   │   │   ├─ Report/             # HTMLReport, Redactor
│   │   │   └─ License/            # TokenPayload decode + policy (signature check lives in Mac layer)
│   │   └─ Tests/WhydunitCoreTests/ + Fixtures/   # pmset logs, log ndjson, ioreg -a plists, profiler JSON, item records
│   └─ WhydunitMac/                # macOS-only collectors and actions; depends on WhydunitCore
│       ├─ Recorder/               # IOKitWatcher, DiskWatcher, DisplayWatcher, PowerWatcher, SleepWatcher,
│       │                          # NetWatcher, CounterSnapshotter, EventStore (JSONL)
│       ├─ Runners/                # Process wrappers: log show, pmset, system_profiler, brctl, pkill, diskutil
│       ├─ ICloud/                 # Scanner (iopolicy thread), Probe, RescueCopier, Ladder
│       ├─ Fixes/                  # WindowServerPrefs, SleepAssertion, CommandSheet (copy-paste sudo + undo)
│       └─ Platform/               # AdminCheck, LicenseVerifier (CryptoKit), KBUpdater, LoginItem (SMAppService)
├─ worker/                         # Cloudflare Worker: license exchange (~40 lines) + wrangler.toml
├─ tools/                          # keygen.py, issue_license.py (manual/offline), sign_kb.py
├─ kb/kb.json                      # KB source; CI signs and publishes it
└─ .github/workflows/ci.yml, release.yml
```

There are two local packages, not one. A single package with an IOKit target would not build on Windows or Linux, so Core would lose its portability.

### 3.2 Core rules

- **Pure functions only:** `(fixture text or struct) → [Finding]` / `Verdict`. No clocks (time is passed in), no file system, no processes.
- **Registry input** is a small `RegValue` enum decoded from `ioreg -a` plists. Every key is Optional; a missing key yields "unknown".
- Every parser has fixtures captured on real hardware per macOS version: `ioreg -a -l -w0 -r -c <Class>`, `pmset -g log`, `log show --style ndjson`, `system_profiler … -json`. The fixture folder is named `<hw.model>_<macOS build>/`.
- **Local development on Windows:**
  - Install: `winget install --id Swift.Toolchain -e --source winget` [V: swift.org], then run `swift test --package-path Packages\WhydunitCore`.
  - Risk: `PropertyListSerialization` in the Windows Foundation is [U]. If it fails, those plist-parser tests run only in macOS CI.

### 3.3 Collectors (WhydunitMac)

- **Watchers** feed one serial `DispatchQueue` and append `Event`s to `~/Library/Application Support/Whydunit/events/YYYY-MM-DD.jsonl`.
- **Counter snapshots:** every 15 min, at each sleep and wake, and at every arm boundary.
- **Process runners:**
  - always `Process` with an argument array and an absolute executable path
  - **never** `sh -c` with interpolated paths
  - 10 s timeout
  - stdout is parsed by Core
- **iCloud scanner:** one dedicated `Thread` with the materialization-off iopolicy. It emits `ItemRecord` structs and never touches file contents.
- **App shell:**
  - one process
  - the window closes into a `MenuBarExtra` that keeps recording
  - `SMAppService.mainApp.register()` provides launch at login
  - no helper, no XPC service, no daemon

### 3.4 Privilege model

| Level | What runs |
|---|---|
| Standard user | Everything that records (IOKit, DA, CG, NSWorkspace, `pmset -g log` [L]), the iCloud scan and probe, user-owned daemon restarts (`pkill -U <uid>`), user-domain file fixes, clearing user BSD flags |
| Admin user (group 80, checked with `getgrouplist`) | Adds kernel and cloudd cause strings via `log show` [V: admin required]. The UI labels evidence "Log-backed" versus "Counter-backed". Standard users see: "Ask an admin to open Whydunit once to capture cause strings." |
| Root | **Never run by the app.** Shown as a copy-paste Terminal sheet with a one-line explanation, the exact command, and the undo command. Examples: `sudo pmset -a disksleep 0` (undo `sudo pmset -a disksleep <recorded value>`), `sudo chflags noschg "<path>"`, the `/Library` WindowServer move. |

### 3.5 TCC and Full Disk Access

- **CloudDocs root:** readable by a non-sandboxed app [V]. No prompt was reported [L].
- **Desktop and Documents** (when in iCloud): standard Files & Folders prompts, triggered only when the user starts an iCloud scan. The purpose strings go in Info.plist. `EPERM` is treated as "needs permission" and gets an explainer screen; it is never reported as "empty".
- **Full Disk Access:** **not requested** in v1. Nothing in v1 needs it: no BTM database, no TCC.db (blocked on 27 anyway).
- **External volumes:** metadata only through DiskArbitration, so no Removable Volumes prompt [L].
- **macOS 27 Application Support protection** (`com.apple.macl`) protects our own folder from other apps. We never read other apps' containers (27 denies cross-team access silently [L]).

### 3.6 Data retention and privacy

- **Stays on the Mac:**
  - events and counters: rolling **30 days**
  - cases, including matched log lines only (never raw log dumps): kept until the user deletes them
  - rescue copies: kept until the user deletes them, with a reminder at 30 days; deleted via `trashItem`
- **Leaves the Mac only in these cases:**
  1. licence activation: the Dodo key and the Mac's display name go to our Worker, once
  2. the Sparkle appcast and KB fetch from GitHub Pages (no identifiers)
  3. a support packet, **only when the user saves it and sends it themselves**
- No analytics, no crash SDK, no accounts.
- **Redactor (Core) for reports:**
  - home path becomes `~`
  - user and Mac names are removed
  - device serial numbers are hashed
  - the licence email is never included
  - no Wi-Fi SSIDs are collected at all
- The privacy statement is one screen long and lists these three network endpoints exactly.

### 3.7 Testing and CI

**`ci.yml`:**
- Runs on PRs and on `main`, on `macos-26`:
  - `swift test --package-path Packages/WhydunitCore`
  - `swift test --package-path Packages/WhydunitMac`
  - `brew install xcodegen && xcodegen generate && xcodebuild build -scheme Whydunit -destination 'generic/platform=macOS'`
  - the grep guard: no `removeItem` under `ICloud/`, and no `sh -c`
- A non-blocking job on `xcode-27` compiles against the macOS 27 SDK.

**`release.yml`:** on tag `v*`, exactly the distribution report's §4 workflow.

**Cost:** private-repo macOS minutes cost $0.062/min beyond included usage [V], so a release run costs well under $1.

**What CI can't do:** hotplug, iCloud accounts or nested VMs [V]. Everything behavioural is validated on the one MacBook plus the two betas. Beta testers can send fixtures with a built-in "Export diagnostic fixtures" button, which runs the same ioreg/pmset commands and is redacted.

---

## 4. Licensing and distribution

### 4.1 The stack

| Layer | Choice |
|---|---|
| Apple | Developer Program, Individual, $99/yr; enrol through the Apple Developer app [V]. Developer ID Application certificate created from an OpenSSL CSR on Windows; `.p12` exported with the legacy PBE flags (distribution report §1). |
| Build | XcodeGen `project.yml` → `xcodebuild archive` → `-exportArchive` (developer-id, manual), `ENABLE_HARDENED_RUNTIME=YES`, `OTHER_CODE_SIGN_FLAGS=--timestamp`, `ARCHS=arm64` |
| Notarize | `ditto -c -k --keepParent` → `xcrun notarytool submit … --key … --key-id … --issuer … --wait` → `xcrun stapler staple` the app, then build the DMG with `hdiutil create -format ULFO`, sign it, notarize it, staple it, and finish with `spctl -vvv --assess --type exec` [V] |
| Updates | Sparkle 2.10.0 [V]; EdDSA key generated on Windows with Python `cryptography`; `generate_appcast --ed-key-file - --download-url-prefix …`; appcast on the `whydunit-releases` GitHub Pages site; a `beta` channel via `--channel beta` for the betas |
| Merchant of record | **Dodo Payments**: 4% + 40¢, +1.5% international; payouts in USD, $5 per payout under $1,000; PAN onboarding [V]. Product has a licence key with activation limit **3** and no expiry. **Fallback: Polar** (5% + 50¢). |
| Licence | Ed25519 token, §4.2 |
| Tax (India) | Consult a CA **before the first sale** about GST registration, the LUT, and FIRA for MoR payouts [U] |

**Secrets (10):** `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `ASC_KEY_P8_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `SPARKLE_ED_PRIVATE_KEY`, `KB_SIGNING_KEY`, `RELEASES_REPO_TOKEN`, plus the Worker secret `LICENSE_KEY_PKCS8_B64`, which lives in Cloudflare, not GitHub.

**Three separate Ed25519 keys**, so that a Worker compromise can't sign KB commands or updates:
1. Sparkle (CI)
2. KB (CI)
3. Licence (Worker)

### 4.2 Licence format and flow

**Format:**
```
WD1.<base64url(payload JSON)>.<base64url(Ed25519 signature over the payload bytes)>
payload = {"typ":"license","v":1,"lic":"lic_…","email":"…","name":"…","issued":"2027-01-25","maxMajor":2}
```

**Flow:**
1. The buyer pays on Dodo's hosted checkout. Dodo emails the licence key.
2. In the app: **Activate** → `POST https://license.<domain>/activate {license_key, name: <Mac name>}`.
3. The Worker calls `POST https://live.dodopayments.com/licenses/activate` (public, no API key [V]). It checks `product.product_id` against a constant and signs the payload with `license_key_id` (`lic_…`) and `customer.email` from the response [V: response fields].
4. The app verifies the token with `Curve25519.Signing.PublicKey(rawRepresentation:)` + `isValidSignature(_:for:)` [V]. It stores the token as `license.wd` in Application Support and shows "Licensed to <email>".
5. **From then on the app never contacts any licence server.** The token works on any of the buyer's Macs: **Save licence file** / paste it on a new Mac. Tokens are deliberately **not machine-bound**, so a lifetime licence survives new Macs, reinstalls and our own disappearance. The activation limit of 3 only throttles how many times a raw Dodo key can be exchanged, to discourage public key sharing.
6. **Refunds and chargebacks:** add the `lic_…` to `revokedLicenses` in the signed KB. Accepted limit: an offline Mac keeps working, which is fine for the honest-people model.
7. **No internet at activation:** the buyer emails the key and receives a token produced by `tools/issue_license.py`, the distribution report's tested Python issuer.
8. **Major versions:** v3.x checks `maxMajor >= 3`; otherwise it shows the upgrade offer. Sparkle's `--major-version` keeps 2.x users from silently auto-updating into v3.
9. **Sunset pledge (on the pricing page):** "If Whydunit is ever discontinued, a final update removes the licence check."

**Worker** (sketch, not run; standard `Ed25519` sign/verify/importKey is supported in Workers [V: Cloudflare Web Crypto table]; PKCS#8 import for the standard curve is [L]):
```js
const PRODUCT_ID = "pdt_REPLACE";                       // Dodo product id
const b64 = s => Uint8Array.from(atob(s), c => c.charCodeAt(0));
const b64url = u => btoa(String.fromCharCode(...u)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
export default {
  async fetch(req, env) {
    if (req.method !== "POST") return new Response("POST only", { status: 405 });
    const { license_key, name } = await req.json();
    const r = await fetch("https://live.dodopayments.com/licenses/activate", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ license_key, name: String(name).slice(0, 64) }) });
    if (!r.ok) return new Response(await r.text(), { status: r.status });   // 422 = activation limit reached
    const a = await r.json();
    if (a.product?.product_id !== PRODUCT_ID) return new Response("wrong product", { status: 403 });
    const body = new TextEncoder().encode(JSON.stringify({ typ: "license", v: 1, lic: a.license_key_id,
      email: a.customer.email, name: a.customer.name, issued: new Date().toISOString().slice(0, 10), maxMajor: 2 }));
    const key = await crypto.subtle.importKey("pkcs8", b64(env.LICENSE_KEY_PKCS8_B64), { name: "Ed25519" }, false, ["sign"]);
    const sig = new Uint8Array(await crypto.subtle.sign({ name: "Ed25519" }, key, body));
    return Response.json({ token: `WD1.${b64url(body)}.${b64url(sig)}` });
  }
};
```

**Key generation on Windows:**
- In Python `cryptography`, `Ed25519PrivateKey.generate()`:
  - `private_bytes(Encoding.DER, PrivateFormat.PKCS8, NoEncryption())`, base64-encoded → `npx wrangler secret put LICENSE_KEY_PKCS8_B64`
  - `public_bytes(Encoding.Raw, PublicFormat.Raw)`, base64-encoded → a constant in `LicenseVerifier.swift`
- Deploy with `npx wrangler deploy`.

**One-time test:** in CI, a token minted by the Worker's test deployment must verify in a unit test. That test should use Dodo's test base URL `https://test.dodopayments.com` [V].

### 4.3 Trial model

- Freemium (§2.5).
- No time-limited trial: nothing to tamper with, and multi-day A/B tests never hit a paywall mid-test. The recorder is free, so evidence is already collected when someone buys.
- 14-day no-questions refund through Dodo (Dodo charges $1 per refund [V]).

### 4.4 Price and policy

- **$29 USD one-time**; **$19 for the first 30 days** after v1.0.
- One person, up to **3 Macs**.
- **All 1.x and 2.x updates included**, which covers v1.1 Sleep Detective and v2.0 Upgrade Rehearsal.
- **Why this price:** it sits in the $19–29 band of multi-module diagnostic utilities (DriveDx $24.99 for 3 computers, EtreCheck $19.99, Sleep Aid $25, Juicy lifetime $24.99, BetterDisplay $21.99) and well above the $6–10 information apps. Including 2.x counters the CleanMyMac "lifetime means one version" backlash (about 686 upvotes on r/MacOS [L]).
- **Checkout-page text:** "Pay once, use forever. Includes every 1.x and 2.x update. A future version 3 would be a discounted upgrade, and it is free if you bought within the 90 days before its release. Whydunit checks your license about once a week; if it can't connect, everything keeps working (BUILD_PLAN §9.4). If we ever shut down, a final update removes the licence check. 14-day refund."
- **Deliberately not at launch:** regional pricing (Dodo support is [U]), family packs, the technician tier (see the v2 roadmap), and Setapp.

---

## 5. Top risks and mitigations

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| 1 | **No Mac, so nothing behavioural can be validated** | Certain / high | Buy the MacBook and test gear in week 1. Keep all logic in Core (tested on Windows and CI). Beta testers contribute fixtures. Budget 30–50% schedule slack for real-hardware surprises. |
| 2 | **iCloud action causes data loss** (and liability) | Low / severe | Safety copy with SHA-256 manifest before L3 and above. `trashItem` only, enforced by a CI grep for `removeItem`. Consent on every step. Never-do list. Guided-only for sign-out and toggles. Audit log. EULA disclaimer. The v1 ladder never evicts. |
| 3 | **Undocumented IORegistry keys or classes change** (they already changed in 15 and 26) | High / medium | Per-key Optional reads. Match old and new class names. "Unknown" is never "OK". Fixture corpus per `hw.model × build`. Non-blocking `xcode-27` job. Ship KB and code fixes within days of each macOS point release. |
| 4 | **WhatPort/WhatCable developer adds a guided wizard** (8.8k stars, fast shipping) | Medium / high | Move fast (dock beta in week 14). Differentiate on what they don't read: unified-log cause strings, DiskArbitration graceful-vs-surprise detection, CG display flaps, and sleep correlation. Add the macOS-bug verdict and KB. Bundle iCloud Rescue, which they don't do. |
| 5 | **Most causes turn out to be macOS bugs** | High / medium | "It's macOS <build>, here's the workaround" is a first-class verdict with a signed, updatable KB, not a failure mode |
| 6 | **Tests take days, and users quit** | Medium / medium | Preflight verdicts in seconds. Recorder always on, so evidence exists before the wizard starts. Minimum-session rule with visible progress, menu-bar status, and a notification when an arm is complete. |
| 7 | **macOS 26+ sync-control APIs don't work for a non-entitled app** | Medium / low | Runtime-gated behind `#available(macOS 26, *)` and `supportedSyncControls`. Every error falls through to Oakley's move-out/move-back. Nothing is advertised until beta confirms it. |
| 8 | **Standard (non-admin) users get weaker evidence** | Medium / medium | Counters, DiskArbitration and CG evidence work without admin. The UI shows evidence strength honestly and offers the "open once as admin" path. |
| 9 | **Dodo (founded 2023) fails or changes terms** | Low / high | Tokens never depend on Dodo after issuance. Polar is ready as a drop-in; the Worker swaps one fetch URL. Export the customer list monthly. |
| 10 | **Name conflict** | Low / medium | Formal Class 9/42 search in week 1. Faultwise is the pre-checked fallback. |
| 11 | **Noah (AI subscription) or Apple itself ships an iCloud fixer** | Medium / medium | Position on safety, evidence and pay-once. Cross-module value (dock, sleep, upgrade) makes the app worth more than an iCloud-only replacement. |
| 12 | **Signing or notarization secrets leak** | Low / severe | Private source repo. Secrets only in a protected `release` environment that requires a tag. Fine-grained PAT scoped to the releases repo. Three separate Ed25519 keys. Offline backup of `devid.key` and all seeds. |
| 13 | **Indian tax or compliance surprise** | Medium / medium | CA consultation before the first sale (GST, LUT, FIRA) [U] |
| 14 | **Solo support load** | Medium / medium | The support packet answers most questions. Per-problem help pages. Strict scope (Apple silicon, macOS 14+; Intel gets a refund). |

---

## 6. Must verify on hardware before building on it (week 2–3 checklist)

1. `ubiquitousItem*` values for non-entitled reads on 14, 15, 26 and 27; how often nil appears.
2. Whether `uploadLocalVersionOfUbiquitousItem` and `resumeSyncForUbiquitousItem` work on CloudDocs items from our app.
3. `pmset -g log` and `pmset -g` as a standard user [L]; `log show` as admin and as standard user.
4. Whether `fileproviderd`, `bird`, `cloudd` and `nsurlsessiond` run per user, and whether `pkill -U <uid>` restarts them cleanly.
5. Wording of the kernel `terminateDevice` reasons on macOS 27, and the Thunderbolt and DisplayPort kernel strings [U].
6. The DiskArbitration graceful-mark heuristic across Finder eject, `diskutil eject`, cable pull and sleep eject.
7. The firmware key in `SPThunderboltDataType` JSON [U]; the TRM reason codes [U].
8. Folder names for "iCloud Drive (Archive)" and "Relocated Items" on 26 and 27 [L].
9. `PropertyListSerialization` in Swift for Windows [U].
10. PKCS#8 Ed25519 import in Cloudflare Workers [L]; the end-to-end token round-trip.

---

## Sources (primary sources used for these decisions; everything else is cited in `docs/research/*.md`)

- Apple trademark guidelines: https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html
- Name checks:
  - https://github.com/alanqoudif/macdoctor
  - https://www.macdoctor.in/
  - http://www.macdoctorinc.com/
  - https://apps.apple.com/us/app/culprit/id6448399003
  - https://apps.apple.com/us/app/whodunit-murder-mystery/id6605932965
  - https://ipv4.bgp.he.net/dns/hunchless.app
- Swift on Windows: https://swift.org/install/windows/
- Cloudflare Workers Web Crypto (Ed25519 supported): https://developers.cloudflare.com/workers/runtime-apis/web-crypto/
- Dodo licence activate (public endpoint; response `id`, `license_key_id`, `customer`, `product.product_id`): https://docs.dodopayments.com/api-reference/licenses/activate-license
- DisplayLink USB vendor ID 17E9: https://www.displaylink.org/forum/showthread.php?t=68192 , https://support.displaylink.com/knowledgebase/articles/544834
- Rosetta end: https://support.apple.com/en-us/102527
- Accessory security: https://support.apple.com/en-us/102282
- Display limits: https://support.apple.com/en-us/122212
- TN3150 (dataless files): https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files
- Non-sandboxed CloudDocs read: https://developer.apple.com/forums/thread/727902
- HTTP/3 stall: https://developer.apple.com/forums/thread/822534
- Kernel terminate reasons: https://bombich.com/blog/2026/07/07/disk-not-ejected-properly
- Prior art (MIT): https://github.com/darrylmorley/whatcable , https://github.com/darrylmorley/whatport
- Sparkle 2.10.0: https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0
- GitHub runners: https://docs.github.com/en/actions/reference/runners/github-hosted-runners

# Next project: the pick

Decided 2026-09-28. Scope: EverydayOpen's second free, open-source Mac app after Whydunit. The goal is popularity (stars, downloads, Reddit/HN/Product Hunt traction, press), not revenue.
Numbers come from the three judges' evidence packs plus spot checks run today against the GitHub API, the Reddit archive (Arctic Shift), HN Algolia and the iTunes Search API. Anything not checked is marked **[unverified]**.

---

## 1. The pick: a used-Mac inspector ("wildcard"), working name **Tirekick**

Tirekick is a free app you open on a second-hand Mac. In about two minutes it tells you, in plain English:

- whether the Mac is still tied to someone's Apple ID, or assigned to a company that will lock it again after it's erased;
- how worn the battery and SSD are;
- whether the specs match the listing;
- whether it still gets macOS updates.

It then walks you through keyboard, screen, speaker, mic, camera and trackpad tests and produces a report card you can share.

### Why this one

1. **It had the highest combined score (18/30)** and was the only candidate that no judge scored below 4. It won differentiation (7) and came second on execution (7).
2. **There's an open gap with proof of demand.**
   - The only app with traction, andyhuo520/MacCheck, has **628 stars and 57 forks**. It is Chinese-only, has no licence, and hasn't been pushed since **2026-07-15** (re-checked today).
   - Everything else is scripts at 0–3 stars, in English, French and Chinese: qatoolist/macbook-checkup, User0856/mac-check, dragstor/mac-check, giocarbon/macbook-checker, the-abraar/Macbook-Pre-Purchase-Checker-Tool, iluoyao/mac-check-skill, chanmizq/mac-inspection. hwl513782273/MacInspect has 2 stars.
   - Many people have had the idea, and nobody has shipped a polished, notarized English app.
3. **English demand exists; the judges hadn't seen it.** New evidence found today:
   - r/mac, "Used a pre-owned MacBook Pro for years… After wiping data and installing new OS, it's giving me an MDM screen": **1,061 points, 260 comments** (2026-05-18, id 1tghec2). That is the exact failure Tirekick's deep check catches before you pay.
   - r/mac, "MacBook Pro, M2 – bought used from eBay": **582 points, 267 comments** (2026-06-30). The buyer was checking battery age with coconutBattery.
   - r/macbookpro, "Almost got scammed buying used locked macbook": **48 points** (2026-07-15).
   - r/mac, "Way of checking for MDM": 3 points (2026-07-23).
   - HN, by contrast, doesn't care: used-Mac stories top out around 13 points, and "Ask HN: How do I unlock the Activation Lock on my M1 MacBook?" got 4 (2026-02-02). **HN is not the channel.**
4. **The timing hook is real and dated.**
   - macOS 27 (shipped 2026-09-14) is Apple-silicon-only, so Intel owners are selling now.
   - Black Friday (2026-11-27) is when people buy new Macs and sell old ones.
5. **It fits the brand.** It's read-only, deletes nothing, runs no shell, and explains what's wrong in plain English, all like Whydunit. It can't hurt anyone's data. Of the three top candidates it has the lowest brand risk.
6. **It has a built-in sharing loop.** Sellers attach the report card to eBay, Facebook Marketplace and r/appleswap listings, and every listing advertises the app to buyers.

**Be honest about the ceiling.** The growth judge scored it 4 and estimated **1–3k stars in 3 months** (an estimate, not a measurement). The use is episodic, and MacInspect shows that an English version doesn't win automatically. Only one candidate had a credible path to 5k: system-data, which the growth judge scored 6. It lost because it would enter a saturated field with the highest risk to user data. See the table.

### Ranked candidates

| Rank | Candidate | Growth | Execution | Differentiation | Total | One-line reason |
|---|---|---|---|---|---|---|
| **1** | **wildcard: used-Mac inspector** | 4 | 7 | **7** | **18** | **Clearest gap (MacCheck 628★ Chinese-only and abandoned; English scripts at 0–3★), a 1,061-point Reddit horror story for proof, a timely Intel sell-off, read-only. Needs Developer ID from day one; episodic use caps the ceiling.** |
| 2 | upgrade-readiness (Rosetta cliff scanner) | 3 | **8** | 5 | 16 | Easiest to build and test in CI, but about 9 months early (demand peaks WWDC–Sept 2027). Apple's built-in list, Rosetta Check ($6.99) and Go64 cover the core. Clones sit at 0–6★, and Silicon peaked at 856★ in the M1 wave. Already planned as Whydunit's "Upgrade Rehearsal" for 2027. |
| 3 | slow-mac ("why is my Mac slow right now") | 4 | 6 | 3 | 13 | Good macOS 27 reindexing hook, but mac-performance-monitor (519★) is moving into the same gap, 5 identical 2026 repos sit at 0–2★, there is no honest ETA API, and Mole or Stats could add it in a day. |
| 4 | wifi-doctor | 3 | 5 | 4 | 12 | HN likes networking, but open-source Mac diagnosers stall (wifi-lens 115★, pingbar 75★), WhyFi ($10) already sells the split, and unsigned builds can't read the SSID. Wrong blame verdicts are public failures. |
| 5 | system-data explainer/cleaner | **6** | 3 | 2 | 11 | The highest star ceiling (PureMac 6.8k★, Mole 68.6k★, MangoDisk 3.4k★ in about 2 months). But it would be about the 48th "system data" repo of 2026. System Data Unpacked (803★ in 23 days) already ships the whole pitch. It needs Full Disk Access, signing and a privileged helper, and it deletes user data, the biggest threat to our "safe fixes" reputation. HN scores for this category are 1–3 points and Reddit calls it "slop". |
| 6 | battery-drain explainer | 2 | 5 | 3 | 10 | At least 7 open-source 2026 clones sit at 0–4★. Paid apps (Juicy, Mac4Breakfast, TurtleBar) own the morning report. The pmset parser can't be validated without real MacBooks. |
| 7 | dock/display recorder | 2 | 2 | 3 | 7 | Shows nothing until a fault happens, so there's no demo. WhatCable (8.8k★) and WhatPort (60★) already sit here. It can't be tested without the hardware. The biggest complaint pool is macOS regressions, which fits a Whydunit module better. |

**Fallbacks if Tirekick misses its kill criteria (section 5):**

- a read-only "why did my disk shrink after macOS 27" explainer inside Whydunit: explain the cause and link to Apple's controls, with no deletes;
- "Upgrade Rehearsal" in Whydunit for WWDC 2027.

---

## 2. Product

### Name

Rules: no "Mac" prefix (Apple's trademark rules; "for Mac" as a descriptor is fine), short, verb-able, and not easily read as a cleaner.

| Name | GitHub (repos with the name) | Mac App Store | iOS App Store | Verdict |
|---|---|---|---|---|
| **Tirekick** | 12 repos, the largest tirekick-dev/tirekick at 1★ | no match | "TireKicker Inspections" (vehicle inspections; found by searching "Tirekicker") | **Pick.** From "kick the tires": inspect before you buy. |
| Dealbreaker | 62 repos, top JEVietti/DealBreaker at 7★ | no match | "dealbreaker – red flag" (dating) | Backup 1 |
| OnceOver | 19 repos; voxpupuli/onceover 152★ (Puppet testing tool) | no match | not checked | Backup 2 |

Rejected:

- Alibi: SeldonIO/alibi 2.6k★, Myzel394/Alibi 1.7k★.
- Provenance: Provenance-Emu 6.4k★.
- Legit: frostming/legit 5.7k★.
- Vetted: collides with the Mac App Store app "Vetted AI Your Shopping Agent".
- Backstory: collides with the Mac App Store app "BackStory Wallpapers".
- CleanTitle: reads as a cleaner, the category users distrust.

Still to do before the repo goes public: a USPTO and India trademark knockout search for "Tirekick" **[not done]**.

Repo: `EverydayOpen/tirekick`. Site: `https://everydayopen.github.io/tirekick`.

### One-line pitch

> **Kick the tires on a used Mac before you pay.** Locks, battery, SSD, keys, screen and updates in two minutes. Free, open source, offline.

### Target users

1. **Buyer (primary).** A non-expert buying from eBay, Facebook Marketplace, Craigslist, r/appleswap or Xianyu. They use it at the meetup or in the first hour after delivery, while the return window is open.
2. **Seller (secondary, and the growth loop).** Especially Intel owners cut off by macOS 27. They want a listing that buyers trust and a "ready to sell" checklist: Find My off, signed out of iCloud, no MDM, then erase.
3. Small refurbishers and IT handovers. Out of scope for v1; they'd want CSV and fleet features.

### The screenshots that get shared

- **The bad-news card** (Reddit, the story people retell):
  > **Walk away.** This Mac is assigned to **"Acme Corp"** in Apple Business Manager. After it's erased, it will lock itself to them again.
- **The seller's card** (attached to listings, one ad per listing):
  > **Tirekick report · MacBook Pro 14" (2023) · M3 Pro 11-core · 18 GB · 512 GB**
  > PASS Not locked: Activation Lock off · PASS Not managed, not assigned to any company · CHECK Battery 81%, 540 of 1,000 rated cycles · PASS SSD healthy · PASS 78/78 keys, no dead pixels, both speakers, camera, mic · PASS Runs macOS 27 (current)
  > Checked 12 Nov 2026 on this Mac · Serial ····7QX · *Only trust a check you run yourself: tirekick (free)*
- Headline for posts: **"Free, open-source app that checks a used Mac for company locks before you pay."**

---

## 3. v1 scope (2–4 weeks)

### Must

| Feature | Exact data source (all without root) | Verdict rule |
|---|---|---|
| What you're buying: model, year, chip, CPU/GPU cores, RAM, storage, serial | `system_profiler -json SPHardwareDataType SPStorageDataType SPNVMeDataType SPDisplaysDataType`; `sysctl hw.model hw.memsize hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu machdep.cpu.brand_string`; bundled `models.json` (identifier → marketing name, year, last macOS), hand-built from Apple's "Identify your Mac" and macOS compatibility pages | Shown for comparison with the listing. An unknown identifier shows "Newer than this version of Tirekick". |
| Activation Lock | `SPHardwareDataType` "Activation Lock Status" (confirm the exact JSON key from a CI fixture) | Enabled → **Walk away**, unless the seller turns off Find My in front of you and it re-checks as Disabled |
| MDM enrollment | `/usr/bin/profiles status -type enrollment` ("Enrolled via DEP", "MDM enrollment") | Either says Yes → **Walk away** (unless it's your employer's Mac) |
| **Company assignment (ABM/ASM): the killer check** | Terminal handoff. The app shows the command `sudo /usr/bin/profiles show -type enrollment` with a Copy button and an "Open Terminal" button. The user pastes the output back, and a Core parser reads `OrganizationName` / `IsMDMUnremovable` or "Client is not DEP enabled". Needs admin and internet, and can show an enrollment notification (evidence pack) **[strings to verify on a real Mac]**. | Organization found → **Walk away**, naming the org. "Not DEP enabled" → Clear. |
| Battery | `system_profiler -json SPPowerDataType` (cycle count, condition, maximum capacity: the same numbers System Settings shows); `/usr/sbin/ioreg -r -c AppleSmartBattery -a` for raw and design capacity | Below 80% or "Service Recommended" → **Check**. Cycles shown against Apple's rated 1,000. |
| SSD | `SPNVMeDataType` / `SPStorageDataType` SMART status and capacity | Not "Verified" → **Walk away**. Capacity differs from the listing → **Check**. |
| macOS updates | `models.json` plus `ProcessInfo.operatingSystemVersion` | Apple silicon: "Runs macOS 27 (current)". Intel: "macOS 26 is its last; security updates usually continue for about 2 years (not guaranteed)". |
| Interactive tests | **Keyboard:** `NSEvent` local monitor (keyDown, flagsChanged, `.systemDefined` for the top row **[unverified]**), ANSI and ISO layouts. **Display:** full-screen solid, gray and checkerboard fills. **Speakers:** `AVAudioEngine` left/right tones. **Mic:** level meter. **Camera:** `AVCaptureSession` preview. **Trackpad:** click, force click (`NSEvent.stage`) and two-finger scroll. | Each test ends with Pass / Problem / Skip. |
| Report card | SwiftUI `ImageRenderer` → PNG (share card) and PDF (full report with raw evidence) | Serial masked to the last 4 by default; no user name, hostname or Apple ID |
| Buyer / Seller mode | Picked on the welcome screen | Seller mode adds the "Ready to sell" checklist below |

### Should (in v1 if the schedule holds, otherwise 1.1)

- **Ready-to-sell checklist:**
  - iCloud signed out, from `~/Library/Preferences/MobileMeAccounts.plist` (current user only);
  - FileVault on, from `/usr/bin/fdesetup status`, so the erase is instant;
  - Bluetooth devices unpaired, from `IOBluetoothDevice.pairedDevices`;
  - a deep link to Erase All Content and Settings **[URL unverified]**.
- **SSD wear %** through the IOKit NVMe SMART user client (the smartmontools method; works without root on Apple silicon **[unverified]**). Fall back to the SMART status alone.
- **Charging-port test:** "plug the charger into each port", confirmed with `IOPSCopyExternalPowerAdapterDetails`.
- **Touch ID** presence through `LAContext.biometryType`. **Wi-Fi and Bluetooth** radios on, through CoreWLAN and IOBluetooth.
- **Installed configuration profiles**, from `system_profiler -json SPConfigurationProfileDataType` **[device-profile visibility without root unverified]**.
- **Localizations:** English plus Simplified Chinese (String Catalog), to catch MacCheck's audience.
- **Warranty:** "Check coverage" copies the serial to the clipboard and opens `https://checkcoverage.apple.com`. The serial never goes in a URL, and the CAPTCHA is not automated.

### Won't (v1)

- **Any bypass or removal of MDM or Activation Lock.** Never. The README says so.
- Network calls from the app (no telemetry, no update check); warranty scraping; a stolen-device lookup (no public source exists).
- Reading Parts & Service (no API). The app deep-links to System Settings › General › About instead.
- Intel firmware-password check (needs root); repair-price or resale-value estimates (a maintenance trap); JIS keyboard layout.
- A menu bar icon, a login item or anything in the background. It's used once per purchase, so it's a window app.
- A CLI, fleet/CSV mode, Windows, Sparkle.

### Permission model

- **No Full Disk Access, no root, no Accessibility, no Input Monitoring.** The keyboard test only listens inside Tirekick's own window, so some system-captured keys (Globe, ⌘-Tab) get a "press it, then tick it" fallback.
- Camera and microphone prompts appear only when the user starts those tests.
- Admin rights are only needed for the ABM check, and they're typed into **Terminal, never into Tirekick**. The app contains no privileged code. A `SMAppService` helper is a 1.1 option, and only if testers find the handoff too clunky.
- Not sandboxed (it has to run `system_profiler` and `profiles`). Hardened runtime, **Developer ID signed and notarized from the first public release**, because the app runs on strangers' Macs. The unsigned-beta workflow is for invited testers only.
- Deployment target **macOS 13** (not Whydunit's 15), so 2017–2019 Intel Macs, the ones being sold now, can run it. `ImageRenderer` needs 13. 2015–2016 Macs (which top out at macOS 12, like the Mac in the 1,061-point thread) can't run it, so the site's meetup guide lists the same commands to type by hand. It uses `ObservableObject`, not `@Observable`. Universal binary.

### Safety rules (enforced by review and a CI grep, like Whydunit's BUILD_PLAN §3)

1. **Read-only.** It never deletes, trashes, moves or writes anything except a report file the user saves through `NSSavePanel`. CI fails on `removeItem(`, `trashItem(`, `unlink(`, `rmdir(`.
2. **No shell.** `Process` only, with an absolute path and an argument array, through Whydunit's `ProcessRunner`. CI allowlists the executables: `/usr/sbin/system_profiler`, `/usr/bin/profiles` (argument `status` only), `/usr/sbin/ioreg`, `/usr/sbin/sysctl`, `/usr/bin/fdesetup` (argument `status` only).
3. **It never changes a setting,** never signs anyone out, never erases. Deep links only.
4. **Findings, not guarantees.** Every row expands to show the command it ran and the raw output. "Walk away" is reserved for hard facts: Activation Lock on, MDM or DEP enrolled, an ABM organization found, SMART failing. The report never says "certified".
5. **Redaction by default** on the share card (serial masked; no user, host or Apple ID). The report has a "What Tirekick can't tell you" section: stolen/blacklisted status, Intel firmware password, parts history, liquid damage.

### UI (Maccy/Rectangle/VoiceInk simplicity)

The app is a single fixed window, about 720×560, with no sidebar. It has four screens, like a small Setup Assistant:

1. **Welcome.** "I'm buying" or "I'm selling", plus a 3-line meetup tip: if the Mac is erased, finish Setup Assistant offline with a throwaway local account, then open Tirekick from a USB stick or a download.
2. **Checks** (5–10 s). Cards animate in. A verdict banner sits on top: **Clean** / **Check these** / **Walk away**. The ABM card has its Copy / Open Terminal / Paste flow inline.
3. **Tests.** A grid of tiles: Keyboard, Display, Speakers, Mic, Camera, Trackpad, plus Ports and Touch ID when they ship. Each opens a full-window guided test with Pass / Problem / Skip.
4. **Report.** Live card preview, a "Mask serial" toggle (on), and Save PNG / Save PDF / Copy.

It uses SF Symbols and system colors, supports light and dark, needs zero settings, and is a download of about 10 MB **[target]**.

### What reuses Whydunit

| Piece | Reuse |
|---|---|
| `Package.swift` split into `TirekickCore` (Foundation-only: parsers, verdict rules, `models.json`) and `TirekickMac` (collectors) | Same pattern. Core tests run on Linux in CI and on Windows through `tools/test_core_docker.sh`. |
| `Sources/WhydunitMac/Platform/ProcessRunner.swift`, `SystemInfo.swift` | Copied verbatim. Two files, so no shared package. |
| `App/DesignSystem` (Tokens, SeverityIcon) | Copied and adapted. |
| `ci.yml` | Reused: Linux core job, macOS `swift test`, safety grep (extended with the allowlist above). **New job:** dump the real `system_profiler`, `profiles status` and `ioreg` output from the arm64 runner and the Intel runner as fixtures. This is the no-Mac answer to "does it parse real output". |
| `beta.yml` | Reused as-is for tester builds (`vX.Y.Z-beta.N`). |
| `release.yml` | Reused: notarized DMG, arm64 and Intel launch smoke tests, GitHub Release notes from CHANGELOG. **Remove** the Sparkle and appcast steps. |
| `site.yml`, `tools/build_site.py`, `changelog.py`, `make_icon.py`, `make_og.py` | Reused for the GitHub Pages site plus SEO guide pages. |
| `tools/doctor.sh`, `AGENTS.md`, `CHANGELOG.md` single source, `docs/RELEASING.md`, `docs/GO_LIVE.md` | Reused, with the Sparkle checks dropped. |
| **Sparkle** (`Updater.swift`, `sparkle_keys.py`, appcast) | **Not reused.** The app is used once per purchase and promises "no network". The site's latest-DMG link is the update path. Add Sparkle only if people keep it installed. |
| Developer ID ($99/yr) | Buy it now. The same account unlocks Whydunit 1.0 notarized releases. |

### Schedule

| Week | Dates (2026) | Work |
|---|---|---|
| 0 | Sep 28–29 | Enrol in the Apple Developer Program (individual). Trademark knockout. Create the repo from Whydunit's CI, site and tools. |
| 1 | Sep 30–Oct 4 | Core: models.json (2017+ Intel, all Apple silicon), parsers and verdict rules with fixtures from the CI dump. Collectors. Report card. **beta.1** (auto checks plus report). |
| 2 | Oct 5–11 | Interactive tests, seller mode, zh-Hans. **beta.2** to 10–20 invited testers on real Macs (a mix of Intel 2017–2020 and M1–M5). Testers use "Copy raw data" (serial masked) to send fixtures. |
| 3 | Oct 12–18 | Fixes from tester fixtures. README, GIF, site, 4 guide pages. |
| 4 | Oct 19–25 | Notarized **1.0**, press pitches. Launch **Tue Oct 27** (fallback Tue Nov 3). Product Hunt one week later. |

---

## 4. Launch plan

**Principle: HN is not the channel.** Used-Mac posts get 13 points or fewer there. The channels are Reddit stories, press, Chinese communities, the seller loop, and GitHub Trending from stars packed into one 48-hour window. System Data Unpacked got to 803★ through trending aggregators such as Instagram "gittrend" and non-English reshares, not through HN.

1. **Launch day (Tue Oct 27), all within about 6 hours** to concentrate stars for Trending:
   - **r/mac** (the community behind the 1,061-point MDM story): a story-led post, "After the 'MDM screen after wiping' thread, I built a free, open-source checker", with the bad-news card and a GIF. Read the sub's self-promotion rules the week before.
   - **r/macbookpro** and **r/macbookair**: the same angle, different images.
   - **r/macapps**: its August 2026 rules push non-App-Store apps without Trust/Transparency standing into the monthly "App Pile" megathread. Ask the mods first whether open source plus notarized qualifies for a standalone post.
   - **Show HN**: "Show HN: Tirekick – check a used Mac for company locks before you pay (open source)". Low expectations. It's there for the record.
   - **Chinese**: a zh-Hans README, plus V2EX (the "分享创造" node), sspai (少数派) and Xiaohongshu. That's MacCheck's audience, and MacCheck hasn't been updated since July.
2. **The seller loop.** Modmail r/appleswap proposing report cards as optional listing proof (don't spam). Put a "Selling your Intel Mac after macOS 27" page on the site.
3. **Press, pitched Oct 20–26.** Hook: *"macOS 27 dropped every Intel Mac, a wave of used Macs is hitting the market, and here's a free way to check one."* Targets:
   - AppleInsider (its 2025-12-05 used-Mac buying guide walks through these checks by hand);
   - 9to5Mac and PetaPixel (both covered WhatCable);
   - MacRumors, OSXDaily, How-To Geek, Lifehacker, Six Colors;
   - heise and ifun.de (German).
4. **Product Hunt: Tue Nov 3.** A secondary channel. Tagline = the pitch.
5. **Long tail.** GitHub Pages guides built by `build_site.py`:
   - "How to check a used Mac for MDM";
   - "How to check Activation Lock";
   - a printable "Used-Mac meetup checklist";
   - "Selling an Intel Mac".

   Answer existing Reddit and Apple Community MDM threads only where the tool truly answers the question. Resend pitches for Black Friday (Nov 27) and for the January upgrade season.
6. **Homebrew cask** once the repo meets Homebrew's notability rules **[check current threshold]**.

### README and site

- The hero is the bad-news card, followed by a 15-second GIF: open → verdict → keyboard test → report.
- Install is a single notarized DMG. The Homebrew cask comes later.
- A **"What it checks"** table with the exact command behind each row. Transparency is the answer to Reddit's reflexive "slop" reply to new utilities.
- **"What it can't tell you"** and **"It will never help bypass MDM or Activation Lock."** Honesty sections earn trust with r/mac.
- **Privacy:** "Runs offline. Sends nothing. Reads nothing personal. Changes nothing."
- The site is a one-page landing plus the guides. The og image is the report card, rendered by `make_og.py`.

### What makes it star-worthy

1. It's the only English tool that answers the question behind a 1,000-plus-upvote horror story: "Will this Mac lock itself to a company after erase?"
2. The report card spreads itself through listings.
3. It's open, offline, notarized and read-only in a category of sketchy "MDM bypass" sites.
4. It launches bilingual, the language MacCheck proved.
5. It's small and fast, with one window and no setup.

---

## 5. Risks and how to kill them early

| Risk | Kill-it-early test | Deadline |
|---|---|---|
| Commands behave differently without root or on real hardware (`profiles status`, `SPConfigurationProfileDataType`, the Activation Lock key) | The CI fixture-dump job on the arm64 and Intel runners, plus `sudo -u nobody` variants on the runner. If `profiles status` needs root, redesign the lock checks in week 1, not week 4. | Oct 2 |
| The Terminal handoff for the ABM check confuses non-experts | 3 testers of mixed skill try it on beta.1. If 2 of 3 get stuck, build the `SMAppService` helper (needs signing) or make the check a guided "optional expert step". | Oct 9 |
| Developer ID not ready (launching unsigned means "damaged app" reports; Orrinix and Dustloft show how that goes) | Enrol today. **Never launch publicly unsigned.** If the account isn't approved by Oct 20, slip to Nov 3; testers stay on beta.yml builds. | Oct 20 |
| No Mac to test the interactive tests | Recruit 10–20 beta testers with different Macs (Whydunit beta list, r/macapps). "Copy raw data" gives real fixtures for Core tests on Linux. | Oct 11 |
| A wrong verdict (false "clean" or false alarm) brings public blame | "Walk away" only on hard facts; raw evidence shown on every row; findings phrased as findings; a "can't tell you" list. Test every verdict rule against fixtures in Core. | ongoing |
| Faked reports (edited PNG) | Card footer: "Only trust a check you run yourself." Timestamp and masked serial. No "certified" wording. | v1 |
| An erased Mac sits at Setup Assistant, where no app can run | The meetup guide: complete setup offline with a local account, or have the seller run it before erasing. Online Setup Assistant itself shows "Remote Management" for ABM Macs, and the guide says to walk away if you see it. | v1 |
| Episodic use means front-loaded stars | Accept it. Keep a long tail through SEO guides, the seller loop and the Black Friday and January pushes. | — |
| Someone translates MacCheck to English first | Ship by Oct 27. MacCheck has no licence, so a translated fork has no right to ship as a product (and we don't copy its code either). | Oct 27 |
| Apple absorbs it (Repair Assistant, Parts & Service, a future "Transfer or Sell" report) | Low odds within 12 months. Tirekick is cheap to maintain: `models.json` gets a row per Apple launch. | — |
| English demand is weaker than the Reddit numbers suggest | **Hard kill criteria, 14 days after launch (Nov 10):** ≥500★ (MacCheck's level) → keep building (1.1: helper, SSD wear, ports). 150–500★ → maintenance only, plus SEO. <150★ → stop feature work and move to the fallbacks in §1. Downloads counted from the GitHub Releases API. | Nov 10 |

**Two decisions before starting:**

1. Pay the $99/yr Apple Developer fee now. It's required for this app and also unlocks notarized Whydunit releases.
2. Confirm the name Tirekick. Dealbreaker is the backup.

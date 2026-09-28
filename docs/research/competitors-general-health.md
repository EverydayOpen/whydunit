# Competitor teardown: general Mac health / diagnostic / maintenance utilities

Research date: 2026-09-27 (macOS 27 "Golden Gate" shipped; macOS 26 Tahoe is the last Intel release).
Scope: business model and differentiation for a new paid, lifetime-licensed "explain what's wrong with my Mac" app.

Method note: vendor pages, GitHub, MacUpdate, the Mac App Store and MacRumors forums were fetched directly. Reddit blocks every fetcher available here, so Reddit evidence comes from search-engine result snippets (thread title, upvote/comment counts, first lines). Confidence for those is marked "likely". Forum comments are paraphrased; only one short direct quote is used.

---

## 1. TL;DR

1. **Nobody in the requested set explains causes.** Tools show readings (iStat Menus, Stats, Sensei, coconutBattery), clean things (CleanMyMac, OnyX, Mole), or map disks (DaisyDisk, GrandPerspective, OmniDiskSweeper). The only tool that states cause and fix in plain language is EtreCheckPro's paid "Solutions", and it does not cover battery drain, sleep/wake or dock faults.
2. **Battery-drain attribution:** none of the listed apps keep per-app drain history. iStat Menus, CleanMyMac's menu app and Mole show live "significant energy" or top-consumer lists. Two newer apps outside the list do keep history: **Juicy** (per-app energy over 24h/7d/30d; $14.99, or $24.99 lifetime) and **MacBookBatteryMonitor** (per-process watt estimates, per its own blog).
3. **Sleep/wake cause analysis:** **Sleep Aid** (Ohanaware, $25) is the only dedicated product. It has not been updated since 1.5 (8 Apr 2025), its site lists support only up to macOS 15 Sequoia, and users said it lists the culprits without explaining or fixing them. That makes it the weakest incumbent and the clearest opening.
4. **System Data explanation:** **DaisyDisk** ($9.99) claims a breakdown of "Other"/"System Data", admin scans for hidden space, and APFS snapshot management. Users still report tens to hundreds of GB of "hidden space" they cannot act on. No tool explains *why System Data grew* over time.
5. **Lifetime sweet spot:** successful one-time Mac utilities cluster at **$10 to $25** (DaisyDisk $9.99, iStat Menus $11.99, Macs Fan Control $14.95, Mole $19, EtreCheck $19.99, TG Pro $20 list, coconutBattery Lifetime $19.95, AlDente €23.99, Juicy Lifetime $24.99, Sleep Aid $25). Sensei ($59) and CleanMyMac ($119.95) are outliers. **Recommendation: $24.99 to $29.99 lifetime, $14.99 to $19.99 at launch, 3 Macs, and a written update policy.**
6. **Subscription backlash is real and recent**, and the CleanMyMac episode shows it also hits a "lifetime" label that turns out to cover only one major version. A lifetime licence is exploitable only if "lifetime" means lifetime updates, or the major-version limits are stated up front.
7. **New threats (2026):** **Noah** (AI agent: the user describes the problem and Noah diagnoses and fixes it; $8.99/month or $79/year, diagnosis free) targets the same "explain what's wrong" pitch as a subscription. **Mole** (59.2k-star open-source CLI plus a $19 lifetime native app) is taking the cleaner/monitor slot. Apple added a native **Charge Limit in macOS 26.4**, which weakens the AlDente and Battery Toolkit segment.

---

## 2. Competitor table

| App | Price (verified) | Model / history | Core features | Maintenance status | Review complaints |
|---|---|---|---|---|---|
| **EtreCheckPro** | Free; Power User package **$19.99** one-time, 6 computers | One-time IAP; FAQ states explicitly that it is not a subscription; no longer on Mac App Store (per MacUpdate/mac-forums users) | 70+ problem checks, anonymous text report for Apple Support Community, malware removal, storage use (Full Disk Access), analytics/insights charts; paid: computer-generated Solutions with step-by-step instructions, detailed displays | 6.8.12 adds macOS 26 Tahoe; no macOS 27 update seen | MacUpdate reviewer called it slow and useless (Apr 2023); a mac-forums user did not understand what "orphan files" meant (2021); MacRumors user unsure whether it was a subscription |
| **Sensei** (Cindori) | **$29/yr** or **$59** one-time, both up to 3 Macs | Both options since the 2020 launch; one-time covers v1 and v2, v3+ may be a paid upgrade | Menu-bar monitor, cleaner, uninstaller, S.M.A.R.T., battery health (cycles/capacity), thermals, disk benchmark, TRIM | Active | Reddit: feature creep and subscription; seen as expensive when Stats + OnyX + AppCleaner do most of it free |
| **CleanMyMac** (MacPaw) | Essential Trio **$23.95/yr**; All-in-One **$39.95/yr** (1 Mac); monthly $5.95 / $9.95; **one-time All-in-One $119.95** (1 Mac), $191.95 (2), $383.95 (5); also Setapp and MAS | One-time exists but covers **current major version only**; subscriptions include future majors | Cleanup, uninstaller, duplicates, Smart Care, Performance, malware Protection, Space Lens, Cloud Cleanup; Menu app shows battery health/cycles/temperature and lets you quit top consumers | 5.5.6 (10 Jul 2026) | Large Reddit backlash over "lifetime" meaning one version (686 upvotes/181 comments on r/MacOS); one-time licence reported to stop working; MacRumors Oct 2024 commenters calling it pointless or harmful |
| **iStat Menus 7** (Bjango) | **$11.99** single, **$14.99** family (5 people); upgrade $9.99/$12.99; MAS $11.99; Setapp | One-time; licences include 6 months of weather data (weather renewal price unverified) | CPU/GPU/mem/disk/network/sensors/fans; battery dropdown lists **processes using significant energy**, battery history graphs; purgeable-space setting | 7.5 (14 Sep 2026) | MacRumors: praised for being $12 and not a subscription; one user disliked the weather subscription; some prefer free Stats |
| **Stats** (exelban) | Free, MIT | Open source | CPU/GPU/RAM/disk/network/battery/sensors/Bluetooth/clock modules | v3.0.18 (27 Sep 2026); ~42.1k stars | README says Sensors and Bluetooth modules are inefficient; fan control is legacy/unmaintained; no per-app energy |
| **coconutBattery 4** | Free; Plus Standard **$12.95** (v4.x updates only); Plus **Lifetime $19.95** (seen at $17.95); unlimited devices | All Plus editions one-time; direct only (no app stores); v3 Plus buyers were upgraded to v4 Lifetime (Reddit snippet) | Battery health for Mac/iPhone/iPad; Plus: saved history, Battery Lifetime Analyzer (temp/voltage/charge-rate ranges), SSD stats, alerts | 4.4 (9 Sep 2026) adds macOS 27 | None substantive found |
| **AlDente** (AppHouseKitchen) | Free; Pro **€11.49/yr** or **€23.99 lifetime** (third parties quote $24.99); Setapp €9.99/mo | Subscription and lifetime side by side; 3 user accounts/MacBooks per key | Charge limiter, discharge, heat protection, sailing mode, MagSafe LED, calibration, Shortcuts | Supports macOS 12 to 26 | r/macapps thread framing Apple's native charge limit as the end for AlDente; one lifetime buyer said the app became "v2" after ~2 years (details unverified) |
| **Battery Toolkit** (mhaeuser) | Free, BSD-3 | Open source | Charge limits (max ≥50%, min ≥20%), disable adapter, Apple silicon only | **Archived 21 Mar 2026**; last release 1.8 (notes fix macOS 26 compatibility; date shown inconsistently, most likely Aug 2025) | Unmaintained |
| **TG Pro** (Tunabelly) | **$20** list, frequently **$10** sale; local-currency pricing | One-time; 3 Macs personal / 1 business; FAQ promises every 2.x update free | Temps per core, fan Auto Boost rules, SMART, battery health, CSV logging, alerts | M5-family support (Mar 2026); macOS 10.13 to 26 | Own FAQ admits fan control is inconsistent or unavailable on M3/M4 |
| **Macs Fan Control** (CrystalIDEA) | Free; Pro **$14.95** (macOS) / **$24.95** (macOS + Windows) | One-time, per-PC, volume discounts | Fan monitor/control, presets, SMART | Active | Not verified |
| **DaisyDisk** | **$9.99** one-time, up to 5 Macs, 30-day refund | Lifetime licence; minor updates included (major-upgrade policy not stated); direct + MAS | Visual disk map, scan as administrator (hidden space), breakdown of "Other" and **"System Data"**, **APFS snapshot** discovery/purge, cloud disks | Active | Users report large "hidden space" (e.g. 150 GB) they cannot act on; one saw DaisyDisk say System Data was vital and undeletable |
| **GrandPerspective** | Free (SourceForge) / **$2.99** MAS | One-time | Treemap, filters, hard-link aware | 3.8.1 (13 Sep 2026), macOS 14+ | n/a |
| **OmniDiskSweeper** | Free | Omni Labs freebie | Size-sorted file browser | 1.16 (17 Sep 2025, macOS 11+ per MacUpdate); Omni's own page still lists old builds | Minimal maintenance |
| **SilentKnight 3 / Mints / Ulbow / LogUI / Cirrus** (Eclectic Light) | Free | Free | SilentKnight: security-system checks (Apple silicon only; supports 15.6+, Tahoe, Golden Gate). Mints 1.22 (13 Jul 2026, Golden Gate): canned log windows for iCloud, TCC, Time Machine, DAS scheduling, Spotlight, App Store, Disk Mount, Boot. Ulbow 1.11 / LogUI 1.1: log browsers. Cirrus 1.16: iCloud diagnostics | Active | Built for advanced users; Mints must run from an admin account (`log show` limitation); **no sleep/wake or battery window** |
| **OnyX** (Titanium) | Free (donations) | Donationware; one build per macOS version | Maintenance scripts, cache deletion, index rebuilds, hidden settings | Tahoe build released 14 Sep 2026; **Golden Gate build requires Apple silicon** | Apple Community regular: it has done nothing useful for years |
| **Sleep Aid** (Ohanaware) | **$25** (launch intro was $10 in 2022); 14-day trial | One-time serial (upgrade policy not documented) | 2-week sleep history calendar, Sleep Check (settings/apps preventing sleep), wake-reason recognition, dark-wake handling, disable Wi-Fi/Bluetooth during sleep, Smart Power Nap control, pre/post-sleep scripts | **1.5 (8 Apr 2025)**; site lists 10.13 to 15 Sequoia, no Tahoe or 27 | MacRumors 2022: it names the processes keeping a Mac awake but does not help fix them; users asked what cryptic assertion names mean |
| **Amphetamine** | Free; no IAP, no Pro | Free gift | Keep-awake sessions and triggers, closed-display mode, Power Protect script | 5.3.2 (10 Nov 2023), no updates since | Own release notes list bugs where it made Macs sleep or drop displays/Wi-Fi. It is itself a source of sleep assertions |
| **Setapp** (bundle) | From **10 Jun 2026**: Mac **$14.99/mo**, Mac + iOS $18.99, Power User $22.99 (4 Macs); annual equivalents reported as $8.99/$11.24/$13.49; earlier members keep legacy price (previously $9.99) | Subscription; Family plan discontinued | 260 to 270+ apps including CleanMyMac, iStat Menus, AlDente Pro, Juicy | Active | Price rise tied to AI credits |

### New and adjacent entrants found during research (not on the original list but directly relevant)

| App | Price | Relevance |
|---|---|---|
| **Juicy** (getjuicy.app) | Pro **$14.99** one-time (1 year of updates, 2 Macs, optional $9.99 renewal) or **Lifetime $24.99** (2 Macs); 3-day trial, 14-day refund; direct, Setapp and MAS | **Per-app battery drain attribution with 24h/7d/30d history** plus callouts when an app misbehaves; alerts; charge limit. The closest battery-drain competitor. Only the direct/Setapp builds have unsandboxed features. macOS 15+ |
| **MacBookBatteryMonitor** | One-time licence (price unverified) | Per its own blog: per-process watt *estimates* derived from measured system power, history, CPU limits/E-core offload. Apple silicon, macOS 14.6+ |
| **Mac Power Monitor** (Bresink) | $15 single computer (secondary source) | Engineer-grade powermetrics GUI; process "Energy" is relative, not watts |
| **Noah** (onnoah.app) | Diagnosis free, first conversation free; **Monthly $8.99** or **Guardian $79/yr** | AI agent: the user describes the problem in words, it inspects the Mac, names the cause, fixes with approval. Covers battery drain, storage full, stuck iCloud/Dropbox sync. **Same "explain what's wrong" pitch, sold as a subscription.** Also on Windows |
| **Mole** (tw93) | CLI free (GPL-3.0, **59.2k stars**); **Mole for Mac $19** one-time ($9 early bird until 15 Jun 2026), lifetime updates, 2 Macs, 14-day refund | Clean/uninstall/optimize/analyze/status in one app. The status battery tile shows the most power-hungry app. "Doctor" detects 5 conditions. Positions itself explicitly against CleanMyMac's subscription |
| **XrayMac** | **$11.82** lifetime, all personal Macs | Storage treemap, cleaner, "APFS purgeable telemetry". Low-end price anchor; trust signals weak (curl-pipe-bash installer, right-click Gatekeeper instructions) |
| **DissectMac** | Free | Treemap claiming to reveal hidden System Data |

---

## 3. Who already does the three target jobs?

| Job | Does it well | Partial | Does not |
|---|---|---|---|
| **Battery-drain attribution** (which app/process drained the battery, over time) | **Juicy** (per-app 24h/7d/30d history, not in list); MacBookBatteryMonitor (vendor claim, not in list) | iStat Menus (live significant-energy process list + battery history graphs); CleanMyMac Menu (top consumers, quit); Mole Status (top drain app); **native Activity Monitor** (Energy Impact, 12 hr Power = 12-hour *average relative score*, "Preventing Sleep" column) | Sensei, coconutBattery (health only), AlDente, Battery Toolkit, TG Pro, Macs Fan Control, Stats, EtreCheck, Eclectic Light tools, OnyX, DaisyDisk, Amphetamine |
| **Sleep/wake cause analysis** (why did it wake or drain overnight, which assertion or device) | **Sleep Aid** only, but stale (Apr 2025), no Tahoe/27 listed, and it lists without explaining | Activity Monitor "Preventing Sleep"; Noah (generic battery-drain diagnosis); hobby "Power Patrol" (Go daemon parsing `pmset -g log` DarkWake reasons + `pmset -g assertions`, correlating battery % → drain/hour; planned open source) | Everything else. Mints has Boot and DAS windows but no sleep window. Amphetamine *creates* assertions |
| **System Data explanation** | **DaisyDisk** (System Data breakdown, admin hidden-space scan, APFS snapshots) | CleanMyMac Space Lens; EtreCheck storage view (FDA); Mole Analyze; iStat Menus purgeable space; DissectMac; XrayMac | GrandPerspective and OmniDiskSweeper (plain maps and lists); battery and fan tools |

**Native macOS baseline (the free floor to beat):**
- System Settings > Battery offers Battery Level and Screen On Usage (last 24 hours) and Energy Usage per day (last 10 days). There is **no per-app breakdown**. Charge Limit (80 to 100%) and a "Slow Charger" indicator arrived in **macOS 26.4**, along with a Shortcuts action, "Set Battery Charge Limit".
- Activity Monitor > Energy shows Energy Impact (relative) and 12 hr Power, which is the average Energy Impact, not watts.
- Diagnosis by hand: `pmset -g log` (Sleep/Wake/DarkWake entries with reasons, for example `DarkWake from Deep Idle [CDNP] : due to EC.ACDetach`), `pmset -g assertions` (current assertion holders such as `PreventUserIdleSystemSleep`, `BackgroundTask`).

**Gap statement:** every incumbent either measures (numbers, charts) or acts (clean, limit, kill). None produces an evidence-backed cause with a confidence level and one safe next step, across overnight drain, System Data growth and dock/monitor faults. Sleep Aid comes closest for sleep, but it is stalled. DaisyDisk comes closest for storage, but it shows a size, not a reason or a trend.

---

## 4. Lifetime-licence sweet spot (2025 to 2026 one-time prices)

| Price | App | Licence scope | Update promise |
|---|---|---|---|
| $2.99 | GrandPerspective (MAS) | MAS | Free updates |
| $9.99 | DaisyDisk | 5 Macs | Minor updates |
| $11.82 | XrayMac | All personal Macs | "Lifetime" |
| $11.99 | iStat Menus 7 | 1 (family $14.99 / 5 people) | v7; paid upgrades ~$9.99 |
| $12.95 / $19.95 | coconutBattery Plus Standard / Lifetime | Unlimited | v4.x only / all future |
| $14.95 | Macs Fan Control Pro | Per PC | Implied |
| $14.99 / $24.99 | Juicy Pro / Lifetime | 2 Macs | 1 year (+$9.99 renewal) / lifetime |
| $15 | Mac Power Monitor | 1 computer | (secondary source) |
| $19 | Mole for Mac | 2 Macs | Lifetime updates |
| $19.99 | EtreCheckPro Power User | 6 computers | Not stated |
| $20 ($10 sale) | TG Pro | 3 Macs | All 2.x |
| €23.99 (~$24.99) | AlDente Pro Lifetime | 3 accounts/Macs | Lifetime |
| $25 | Sleep Aid | Not stated | Not stated |
| $59 | Sensei Regular | 3 Macs | v1 and v2 only |
| $119.95 | CleanMyMac All-in-One | 1 Mac | Current major only |

**Reading:** the mode is **$10 to $25**. Single-purpose tools sit at $10 to $15. Multi-module "pro" utilities with a clear job sit at $19 to $25. Above $50, buyers compare against Setapp ($8.99 to $14.99/month for 260+ apps) and the free stack (Stats, OnyX, Activity Monitor). Common terms: 2 to 3 Macs, 14-day refunds (Juicy, Mole, Sensei) or 30-day (DaisyDisk, CleanMyMac), a trial or free scan, and local-currency pricing through a merchant of record (TG Pro via Paddle; Mole via Dodo Payments).

**Recommended for this app:** free scan that shows *what* was found. The paid licence unlocks the *why* and the guided tests, with the EtreCheck free/Power User split as precedent.
- **Lifetime $24.99 to $29.99**, launch price $14.99 to $19.99, 3 Macs, 14-day refund.
- Optional two-tier "Standard (1.x updates) / Lifetime (all updates)" in the style of coconutBattery or Juicy.
- Put the update policy in writing on the pricing page to avoid the CleanMyMac trap.

---

## 5. Is there subscription backlash a lifetime licence can exploit?

Yes, with a caveat about how "lifetime" is defined.

**Evidence (paraphrased; Reddit via search snippets):**
- r/MacOS, late 2024: a thread accusing MacPaw of a misleading "lifetime" CleanMyMac licence (one-time licences cover only one major version, then the old version was discontinued): **686 upvotes, 181 comments**. The r/mac cross-post had **282 upvotes, 263 comments**. https://www.reddit.com/r/MacOS/comments/1h3puft/ and https://www.reddit.com/r/mac/comments/1h3rpfv/
- r/MacOS, about 9 months ago: a follow-up thread calling the CleanMyMac lifetime licence a scam. https://www.reddit.com/r/MacOS/comments/1pmm709/
- r/mac, about 11 months ago: a CleanMyMac X one-time licence stopped working, with weeks of no support reply. https://www.reddit.com/r/mac/comments/1o0ok2o/
- MacRumors, iStat Menus 7 launch (31 Jul 2024): commenters praised the $12 single licence and the $13 family upgrade as fair, wished death on subscriptions, and said software you buy should be yours to keep. One objected to the weather subscription. https://forums.macrumors.com/threads/istat-menus-7-0-brings-comprehensive-redesign-and-new-features.2432615/
- MacRumors, Calendar 366 moves to subscription (30 Apr to 1 May 2026): several regulars refused to pay $20/year for a utility. jimw summed up the position: "I'm fine with subscriptions for services but not for tools." https://forums.macrumors.com/threads/calendar-366-has-had-a-major-upgrade-which-the-developer-is-calling-a-completely-new-app.2481751/
- MacRumors, Apple Creator Studio bundle at $129/year (Jan 2026): page after page of anti-subscription comments, including users who said they stopped accepting subscriptions years ago and others calling for an end to the subscription model. https://forums.macrumors.com/threads/apple-introduces-new-creator-studio-bundle-of-apps-for-129-per-year.2475972/page-10
- r/macapps: a 2023 comparison thread faulting Sensei for feature creep and for being a subscription (https://www.reddit.com/r/macapps/comments/10xvrct/). A community-built directory of 50+ one-time-purchase apps made to reduce subscription fatigue (https://www.reddit.com/r/macapps/comments/1qqbd53/). A "what did you pay for once and still use" thread whose author is cancelling subscriptions (https://www.reddit.com/r/macapps/comments/1qmbvks/).
- The market is moving too: Mole (Jun 2026), XrayMac and Juicy all advertise "no subscription" and name CleanMyMac as the foil.

**Counter-evidence and risks:**
- Price sensitivity exists even for one-time prices: an r/macapps thread complains that essential Mac apps cost $20 to $40 (https://www.reddit.com/r/macapps/comments/1kubxn2/).
- "Lifetime" is now distrusted. The CleanMyMac thread shows buyers punish lifetime licences that stop at the next major version; the AlDente "v2" comment suggests similar worry there (details unverified).
- Some MacRumors users note that one-time apps get fewer updates. Subscription vendors (Noah, CleanMyMac, Setapp) argue ongoing diagnosis needs ongoing updates, so the app must show it keeps up with each macOS release (Sleep Aid's stall is the cautionary example).
- Apple is shipping features into this space: Charge Limit in 26.4. An iPhone-style per-app battery view is absent from the macOS Battery settings on Apple's current support page. Watch for it in macOS 27.x.

---

## 6. Differentiation recommendations

1. **Sell explanations, not readings.** Every finding should carry four parts: the evidence (log lines, assertion holder, snapshot list), a plain-English cause, a confidence level, and one safe next step. The live-graph space (iStat Menus, Stats, Sensei, Mole) is saturated and partly free.
2. **Lead with overnight drain.** Sleep Aid is stalled, and Juicy and Activity Monitor are awake-time tools. An overnight report built from `pmset -g log` (DarkWake reasons), assertion history (`pmset -g assertions` sampled over time) and battery-percentage deltas per sleep session answers the question nobody answers well: "who woke my Mac and cost me 18% last night".
3. **System Data *growth* explainer.** Diff storage categories over time and name the grower (for example Time Machine local snapshots, which users repeatedly find behind 200 to 300 GB of System Data). DaisyDisk shows a size, not a trend or cause.
4. **Stay out of commoditised or Apple-absorbed features:** charge limiting (native since 26.4; Battery Toolkit archived), fan control (TG Pro and Macs Fan Control, with Apple silicon limits), junk cleaning (CleanMyMac/Mole, and a trust deficit: MacRumors and Apple Community regulars call cleaners harmful).
5. **Trust posture as a feature:** read-only by default, no background daemons, no "health score" scare tactics, notarized, local-only. This is the inverse of the CleanMyMac complaints, and Noah and Mole already market on it.
6. **Licence copy:** "Pay once. All 1.x and 2.x updates included. 3 Macs. 14-day refund." Consider a later Setapp listing for recurring revenue without selling a subscription directly (AlDente and Juicy do both).
7. **Platform:** macOS 27 tools are going Apple-silicon-only (OnyX's Golden Gate build, SilentKnight 3). Target Apple silicon first. Intel support is at most a Tahoe-only consideration.

---

## 7. Open questions / unverified

- Sleep Aid: upgrade policy; whether 1.5 works on Tahoe/27 (site lists only up to Sequoia).
- Juicy's attribution method (how per-app energy is computed) and sales traction.
- MacBookBatteryMonitor's price; Mac Power Monitor's $15 comes from a secondary source.
- coconutBattery exact prices ($12.95 / $19.95 / $17.95 sale) come from a search snippet of the official page; the live page renders prices via JS.
- iStat Menus weather renewal price.
- Whether macOS 27 adds per-app battery usage to System Settings (an iPhone-style per-app battery view).
- EtreCheckPro macOS 27 support status.
- AlDente "v2" lifetime complaint: whether lifetime holders had to pay.
- CleanMyMac auto-renew/refund complaint counts (search summary mentions 50+ complaints; primary source not identified).
- Battery Toolkit 1.8 release date (GitHub page rendered 2024, but the notes reference macOS 26).

## 8. Sources

- EtreCheck FAQ https://etrecheck.com/en/faq.html · Features https://etrecheck.com/en/features.html · MacUpdate https://etrecheckpro.macupdate.com/ · mac-forums https://www.mac-forums.com/threads/etrecheck-pro-any-good.364198/ · MacRumors https://forums.macrumors.com/threads/using-etrecheck.2466988/
- Sensei https://cindori.com/sensei · store https://cindori.com/store/sensei · Reddit launch https://www.reddit.com/r/macapps/comments/ep6u9x/ · https://www.reddit.com/r/MacOS/comments/12hi56s/
- CleanMyMac store https://macpaw.com/store/cleanmymac · purchase options https://macpaw.com/support/cleanmymac/knowledgebase/purchase-options · battery apps article https://macpaw.com/reviews/macbook-battery-life-apps · MacRumors https://forums.macrumors.com/threads/macpaw-releases-redesigned-cleanmymac-with-new-features.2440216/
- iStat Menus https://bjango.com/mac/istatmenus/ · version history https://bjango.com/mac/istatmenus/versionhistory/ · MacRumors article https://www.macrumors.com/2024/07/31/istat-menus-7-0-brings-new-features/
- Stats https://github.com/exelban/stats · releases https://github.com/exelban/stats/releases
- coconutBattery https://www.coconut-flavour.com/coconutbattery/
- AlDente pricing https://apphousekitchen.com/aldente-overview/pricing/ · https://www.reddit.com/r/macapps/comments/1r6xz29/
- Battery Toolkit https://github.com/mhaeuser/Battery-Toolkit · releases https://github.com/mhaeuser/Battery-Toolkit/releases
- TG Pro https://www.tunabellysoftware.com/tgpro/ · FAQ https://www.tunabellysoftware.com/support/faq/
- Macs Fan Control https://crystalidea.com/macs-fan-control · buy https://crystalidea.com/macs-fan-control/buy
- DaisyDisk https://daisydiskapp.com/ · pricing https://daisydiskapp.com/support/pricing/ · Reddit https://www.reddit.com/r/mac/comments/1qml4fo/ · https://www.reddit.com/r/MacOS/comments/11sgteb/
- GrandPerspective https://grandperspectiv.sourceforge.net/ · OmniDiskSweeper https://www.omnigroup.com/more · https://omnidisksweeper.macupdate.com/
- Eclectic Light downloads https://eclecticlight.co/downloads/ · Mints https://eclecticlight.co/mints-a-multifunction-utility/ · Sleep Aid review https://eclecticlight.co/2022/06/23/putting-the-insomniac-mac-to-sleep-help-is-at-hand/
- OnyX https://www.titanium-software.fr/en/onyx.html · Apple Community https://discussions.apple.com/thread/253926612
- Sleep Aid https://ohanaware.com/sleepaid/ · version history https://ohanaware.com/sleepaid/versionHistory.html · MacUpdate https://sleep-aid.macupdate.com/ · MacRumors https://forums.macrumors.com/threads/sleep-aid-new-app-to-troubleshoot-mac-waking-up-from-sleep.2349216/
- Amphetamine https://apps.apple.com/us/app/amphetamine/id937984704?mt=12
- Setapp pricing https://setapp.com/pricing · price-change note https://support.setapp.com/hc/en-us/articles/8936786965148-Why-is-my-price-different · https://josephnilo.com/blog/setapp-pricing/
- Juicy https://getjuicy.app/ · MacBookBatteryMonitor comparison (vendor blog) https://macbookbatterymonitor.com/blog/best-mac-power-monitor-apps
- Noah https://onnoah.app/ · Mole https://github.com/tw93/Mole · https://mole.fit/ · XrayMac https://xraymac.com/ · DissectMac https://dissectmac.com/
- Apple Battery settings https://support.apple.com/guide/mac-help/change-battery-settings-mchlfc3b7879/mac · macOS 26.4 battery features https://9to5mac.com/2026/04/03/macos-26-4-adds-three-new-battery-features-on-mac-heres-how-to-use-them/ · Power Patrol write-up https://www.ksred.com/building-a-macos-power-monitor-in-go-solving-the-sleep-drain-mystery/
- Backlash threads: https://www.reddit.com/r/MacOS/comments/1h3puft/ · https://www.reddit.com/r/mac/comments/1h3rpfv/ · https://www.reddit.com/r/MacOS/comments/1pmm709/ · https://www.reddit.com/r/mac/comments/1o0ok2o/ · https://www.reddit.com/r/macapps/comments/10xvrct/ · https://www.reddit.com/r/macapps/comments/1qqbd53/ · https://www.reddit.com/r/macapps/comments/1qmbvks/ · https://www.reddit.com/r/macapps/comments/1kubxn2/ · https://forums.macrumors.com/threads/istat-menus-7-0-brings-comprehensive-redesign-and-new-features.2432615/ · https://forums.macrumors.com/threads/calendar-366-has-had-a-major-upgrade-which-the-developer-is-calling-a-completely-new-app.2481751/ · https://forums.macrumors.com/threads/apple-introduces-new-creator-studio-bundle-of-apps-for-129-per-year.2475972/page-10

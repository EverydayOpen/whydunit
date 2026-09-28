> **Superseded in part: the app is free ([BUILD_PLAN §10](BUILD_PLAN.md)); pricing/licensing/paywall/Dodo items are historical.** Where this document and BUILD_PLAN disagree, BUILD_PLAN wins.

=== CRITIQUE 0 ===
 Adversarial market review of `D:\apple\docs\DECISIONS.md` (business lens). I checked competitor sites and docs on 2026-09-27. Items are ordered by severity.

1. **The claim that no competitor names a cause is now wrong in three places.**
   - Noah says it "names the actual cause", and its free first conversation includes fixes. Its homepage lists "Files won't sync: iCloud, Dropbox, OneDrive stuck" (https://onnoah.app/).
   - WhatBattery Pro (£9.99, from the WhatPort developer) gives "Recognised wake reasons … plain-English labels" (https://www.whatbattery.app/).
   - EtreCheck's paid tier sells "Computer-generated Solutions" (https://etrecheck.com/en/features.html).
   - **Change:** narrow the claim to what is unique: *controlled A/B tests with a scored verdict*, and *a verified copy of files before any fix*. Rewrite decision #1 and the positioning table.

2. **v1.1 Sleep Detective is not an open gap.** The doc says Sleep Aid (stalled at 1.5) is the only competitor. In fact WhatBattery Pro already ships overnight-drain "Sleep insights" (charge lost, sleep duration, wake reasons) and app power for £9.99 one-time on 2 Macs. It comes from a developer with press from The Verge, 9to5Mac and Lifehacker (https://www.whatbattery.app/).
   - **Change:** remove Sleep Detective as a named module. Either fold sleep evidence into Dock Detective (E6 already does this), or ship it only as an A/B verdict, e.g. "turning off Power Nap saved X% per night". WhatBattery does not claim verdicts; it offers "useful clues to investigate".

3. **"Pay once" is not cheaper than Noah for a buyer with one incident.**
   - Noah's diagnosis is "always free", and the whole first conversation, fixes included, is free.
   - After that it costs $8.99 for one month, with a 7-day trial (https://onnoah.app/). Someone stuck on iCloud once pays $0–$8.99 there, against $29 here.
   - **Change:** stop leading with price against Noah. Lead with what an LLM agent does not promise: "copies the N files that exist only on this Mac, checks each copy by SHA-256, then unsticks them one at a time overnight". Make the batch move-out/move-back ladder (L6b) the paid headline feature. Nobody does that by hand for 400 files.

4. **The paywall contradicts itself: the free tier already gives away the "why".** Free users see finding titles, and the titles are the verdicts (I1 "Your iCloud storage is full", I10, I16, P1–P12). EtreCheck's free tier deliberately includes an "anonymous text report for easy posting"; only Solutions are paid.
   - **Change:** give the diagnosis away and charge for the *doing*: safety copy, the fix ladder, the A/B wizard, the vendor/Apple packet, and ongoing watch (item 12). Replace "pay to see the why" in §2.5 and decision #10.

5. **Dock Detective's statistics cannot deliver "names which part to replace" in a reasonable time.**
   - At the 5-session minimum, "Proven" needs at least 4 of 5 baseline sessions failing and 0 of 5 variant sessions failing. Two-sided Fisher p = 10/210 = 0.048. A fault that fails 80% of sessions is not intermittent.
   - At a 1-in-3 failure rate you need about 15 sessions per arm (5/15 vs 0/15 gives p ≈ 0.042).
   - At about one failure a day, with 2-hour sessions, each arm takes weeks. The 14-day refund window will close before a verdict, so expect "Couldn't reproduce" plus chargebacks. Dodo charges $30 per dispute.
   - **Change:**
     - Replace the 14-day refund with an outcome guarantee: "No verdict within 30 days → full refund."
     - Change the marketing line to "narrows it to cable / port / dock / device / macOS, with how sure it is".
     - Rename "Proven" to "Strong evidence".
     - At "Likely", always recommend the cheapest reversible step first (cable before dock).

6. **The "Direct" arm is a request most dock users will refuse.** People buy docks because they need the ports and displays. Going without one for at least 24 hours and 5 sessions per arm kills completion.
   - **Change:** default arms move only the *target device* (e.g. plug just the SSD in directly) while the rest of the dock stays in use. Keep full bypass as an optional arm.

7. **Most of the free dock preflight overlaps with WhatPort's own features, which are mostly free.**
   - WhatPort Free already shows negotiated speed (P5/P6), "a flag when macOS has blocked" a connection (P4), liquid detection (P11) and over-current port statistics (P7).
   - WhatPort Pro adds port health, PD reliability counters (P12) and alerts (https://www.whatport.app/, https://github.com/darrylmorley/whatport/releases).
   - The developer shipped v1.7 to v1.10 in six days and now sells three cross-promoted apps.
   - **Change:** keep preflight free. It is table stakes, not a selling point. Put all differentiation and all paid value in:
     - the wizard and verdict,
     - unified-log cause strings,
     - DiskArbitration graceful-vs-surprise ejects,
     - CoreGraphics display flaps,
     - the macOS known-issue KB.

     Replace Risk #4's mitigation, "move fast", with this narrower moat.

8. **Time to first revenue is too long, and the schedule ignores its own slack.**
   - Week 17 is about late January 2027. Risk #1 adds 30–50%, which moves launch to roughly March–April 2027.
   - That leaves about 2–3 months before the planned v2.0 beta at WWDC, and misses the macOS 27.x wave of iCloud and dock breakage.
   - **Change:** ship iCloud Rescue alone as paid v1.0 at about week 9–10, moving licensing and the paywall from week 13 to week 7. Price it at $19. Deliver Dock Detective as a free 1.x update and raise the price to $29 when it lands. That gives a real reason for the launch discount and makes "all 1.x updates included" tangible.

9. **There is no demand gate before the most expensive module.** Dock Detective is 6 weeks plus dock gear, for a market OWC estimates at about 1 in 100 users.
   - **Change:** publish the per-problem landing pages in week 1 with email capture. Build Dock Detective only if both of these hold:
     - the dock page's waitlist reaches a set threshold (for example 300 signups; pick your own number), and
     - iCloud paid conversion is at least X%.

     Measure downloads with the GitHub Releases API (`assets[].download_count`) against Dodo sales. With no telemetry there is no other funnel signal.

10. **The beta recruiting plan breaks Apple Community rules.** The Apple Support Communities Use Agreement §7, "No advertising", bans URLs that don't directly answer the question and links that benefit the poster. It even gives "This post created by …" as an example of a banned reference (https://discussions.apple.com/terms).
    - **Change:** recruit through your own SEO pages and waitlist, r/macapps and MacRumors. I have not checked those forums' self-promotion rules. Any report text users paste into Apple Community must carry no promotional footer or link.

11. **The technician tier cannot be sold, because the token is not bound to a machine.** One $29 token works on unlimited client Macs, so "3 Macs" and a future $99 tier are honour-only.
    - **Change:** stamp "Licensed to <name>" on every report and support packet in the standard tier. Offer the Technician tier ($99) at v1.0 with a licence token field such as `tier:"tech"` plus the business name, which gives white-label reports and per-client case folders. Consultants and MSPs are the only *repeat* buyers of an episodic troubleshooter.

12. **Value is episodic, which invites refunds and resentment.** Rosetta Check reviews show this even at $6.99: one reviewer resents paying for a tool "only gonna be useful for the next operating system" (https://apps.apple.com/us/app/rosetta-check/id6759349750?mt=12).
    - **Change:** add an ongoing paid feature that justifies "lifetime". After every macOS update, and weekly, automatically re-scan iCloud and re-run dock preflight, then notify: "sync stalled again / new local-only files / link trained below spec". The recorder already exists.

13. **The pricing page promises named future modules.** The doc says 2.x "covers v1.1 Sleep Detective and v2.0 Upgrade Rehearsal", which creates refund and credibility exposure if they slip or get cut (see item 2).
    - **Change:** promise "all 1.x and 2.x updates" only. Never name unreleased modules on checkout.

14. **Upgrade Rehearsal (v2.0) walks into an entrenched, cheaper competitor with an unfunded curation cost.**
    - Rosetta Check is $6.99, shipped v3.3 today, scans apps, components and command-line tools, has a 30k-app database, and is adding native-version finding.
    - Apple's Settings list is free.
    - A curated vendor `compat.json` is recurring labour that lifetime revenue won't fund.
    - **Change:** scope v2.0 to the before/after diff plus fixes (Rosetta removed, "Open using Rosetta" reset, lost plug-ins) using local data and Homebrew data only. Drop the hand-curated vendor database unless a data partner appears.

15. **Regional pricing is marked unverified, but Dodo now supports it.**
    - Purchasing Power Parity (preset: India pays 30%) and Localized Pricing are documented, but they require Adaptive Currency. Its 2–4% FX fee is added to the customer's price by default, and absorbed by you when a localized price rule applies (https://docs.dodopayments.com/features/purchasing-power-parity, https://docs.dodopayments.com/features/adaptive-currency).
    - **Change:** mark this as verified in §4.4. Leave it off at launch unless the data shows price-driven drop-off, because the FX fee and support overhead cut into $19–29 sales.

16. **No break-even is stated, and hardware cost is "not researched".**
    - MacBook Air M5 in India: from ₹149,900. MacBook Neo: from ₹79,900 (https://www.apple.com/in/macbook-air/, https://www.apple.com/in/macbook-neo/). I have not verified whether the Neo supports Thunderbolt or multiple displays, so don't buy it as the dock test rig until you check.
    - Net per sale on Dodo with an international card: about $27.00 at $29 and about $17.55 at $19, before the $5 fee on payouts under $1,000.
    - The Air alone is about 63 sales at $29 or about 97 at $19, assuming about ₹88/USD (my assumption, not verified), before dock gear, the $99/yr developer fee and 4–6 months of time.
    - **Change:** add a one-paragraph unit-economics and kill-criteria section to §5. Ship iCloud first (item 8) so the hardware pays for itself sooner.

17. **The two unrelated jobs are sold under one brand that says neither.** "Whydunit" does not match what people search for ("waiting to upload", "disk not ejected properly"), and a general "troubleshooter" framing invites comparison with Noah and EtreCheck.
    - **Change:** keep one binary and one licence, but market two named products ("Whydunit iCloud Rescue" and "Whydunit Dock Detective"), each with its own landing page, screenshots and price anchor. Mention the bundle only at checkout. 

=== CRITIQUE 1 ===
 **Whydunit DECISIONS.md: technical review (macOS 14–27, Apple silicon, non-sandboxed, non-root Developer ID app)**

I re-checked 7 claims against sources: 3 held up and 4 turned out wrong or incomplete. Findings are ordered by severity. Tags: [V] means verified in this pass, [L] means likely, [U] means unverified.

**What I re-checked**

| Claim | Result |
|---|---|
| macOS 26 sync-control API names (§2.2 L6/L7/I9) | **Correct.** Swift keeps the ObjC type names: `NSFileManagerUploadLocalVersionConflictPolicy.conflictPolicyFailOnConflict`, `NSFileManagerResumeSyncBehavior.preserveLocalChanges`, `NSFileManagerSupportedSyncControls.failUploadOnConflict`/`.pauseSync`. `URLResourceValues.ubiquitousItemSupportedSyncControls` has type `NSFileManagerSupportedSyncControls?`. All macOS 26.0, and all have async variants. [V] (Apple docs JSON under developer.apple.com/tutorials/data/documentation/foundation/…) |
| Dodo activate response fields | **Correct.** The response has `customer.email`, `customer.name`, `license_key_id`, and `id` (`lki_…`). `product` is documented as "Present if the license key is tied to a product", so `a.product?.product_id` in the Worker is right. [V] https://docs.dodopayments.com/api-reference/licenses/activate-license |
| PKCS#8 key import in the Worker | **Correct choice.** Cloudflare says it "will not support raw import of private keys", so PKCS#8 is the path to use. PKCS#8 support itself is still [L] until the round-trip test runs. https://developers.cloudflare.com/workers/runtime-apis/web-crypto/ |
| "No prompt" for reading CloudDocs (§3.5) | **Wrong.** See item 1. |
| Sleep acknowledgement (only WillSleep) | **Incomplete.** See item 2. |
| P5 bcdUSB rule | **Wrong.** See item 3. |
| P12 `NotChargingReason` rule | **Wrong.** See item 4. |

**Problems and the change for each**

1. **§3.5 / §2.2: reading iCloud Drive is behind a TCC prompt.**
   - The prompt is `kTCCServiceFileProviderDomain` ("…wants to access files managed by 'iCloud Drive'"). It was seen on Darwin 25.5 (macOS 26.5): a public GitHub issue report. The research also says Cirrus needs iCloud Drive consent under Files & Folders.
   - Forum thread 727902 only shows the sandbox is not the blocker; it says nothing about TCC.
   - **Change:**
     - Add `NSFileProviderDomainUsageDescription` to Info.plist. The key exists for macOS 10.15+ [V: Apple Information Property List docs].
     - Start the scan only from a user click. Treat `EPERM` on the CloudDocs root as "permission denied" and send the user to Settings.
     - Make sure the login-item recorder never touches CloudDocs, so no prompt fires at login.
     - Add to the §6 checklist: whether writing the probe prompts separately.

2. **§2.3 sleep/wake: the doc only acknowledges WillSleep.**
   - Apple QA1340 says `kIOMessageCanSystemSleep` must also get `IOAllowPowerChange` or `IOCancelPowerChange`: "If you don't acknowledge… the system will wait 30 seconds then go to sleep." [V] https://developer.apple.com/library/archive/qa/qa1340/_index.html
   - A recorder that delays sleep changes the sleep-linked faults it is trying to measure.
   - **Change:** acknowledge both messages immediately in the callback. Take the counter snapshot after acknowledging, or on `NSWorkspace.willSleepNotification`.

3. **P5 (USB2-only cable) will almost never fire.**
   - A SuperSpeed-capable device that enumerates at high speed reports `bcdUSB` 0x0210, not 0x03xx. Microchip UFX7000 and LAN7801 databooks say "When operating in USB 2.0 mode the default value is 0210h". An Infineon FX3 thread reports 0x0210 on a USB 2.0 cable. [V] https://community.infineon.com/t5/USB-superspeed-peripherals/Control-requests-fail-after-device-suspend-and-resume/td-p/355582
   - **Change:** detect a USB2-only link using any of these:
     - the HPM node's `TransportsActive` contains `USB2` but not `USB3`/`CIO`, while `TransportsSupported` includes them;
     - the same VID/PID/serial was seen earlier at `Device Speed` ≥ 3 and is now at 2.
   - Keep `bcdUSB == 0x0210` only as a weak hint, because it also covers USB 2.1 devices.

4. **P12 will fire on normal Macs.**
   - `NotChargingReason` is a bitfield that is non-zero in normal states. WattMate measured 128 (bit 7) on battery and 16777216 (bit 24) at a charge limit. macOS 26.4's built-in Charge Limit makes the second case common. The keys sit inside `ChargerData`; reading them at the top level returns nothing. [L] https://wattmateapp.com/mac-not-charging-past-80
   - **Change:**
     - Drop the "`NotChargingReason` ≠ 0" trigger. Mask bits 7 and 24 and keep the raw value only as evidence.
     - Base P12 on increases in `ChargerResetCounter` or `PortControllerHardResetCount` during hands-off windows on AC power.

5. **I10/I11/L2: the probe can send a healthy Mac to the daemon ladder.**
   - The probe relies on `ubiquitousItemIsUploadedKey`, which the doc itself says may be nil for a non-entitled app. If it is nil, every probe "fails", I11 fires, and L3–L5 kill daemons for no reason.
   - **Change:**
     - Make the probe three-state: uploaded, not uploaded, unknown.
     - I11 and L3–L5 need an explicit `false` for at least 120 s, plus a second signal: a cloudd log match (admin) or `brctl status` not idle.
     - "Unknown" should never start the daemon ladder.
     - Put this probe check at the top of the §6 checklist.

6. **Scanning with materialization turned off.**
   - With the policy off, dataless *folders* cannot be listed; the call returns `EDEADLK` (TN3150).
   - **Changes:**
     - Use `enumerator(at:includingPropertiesForKeys:options:errorHandler:)` and have the error handler return `true`. Record each such folder as "dataless folder, contents not listed".
     - Show I13 (storage debt) as "at least X GB".
     - `setiopolicy_np` applies per thread, so `RescueCopier` and the `NSFileCoordinator` reads must run on a different thread from the scanner.

7. **L6(a) and I9 use the sync-control APIs outside what Apple documents.**
   - Apple describes `uploadLocalVersionOfUbiquitousItem` as the call to make "Once your app pauses a sync for an item".
   - `resumeSync…` "fails with featureUnsupported if url isn't currently paused".
   - A pause is independent of the calling app's lifecycle. [V]
   - **Change:**
     - Make L6(a): `pauseSync…`, then `uploadLocalVersion…(.conflictPolicyFailOnConflict)`, then `resumeSync…(.preserveLocalChanges)`.
     - Write a pause journal *before* pausing, and resume anything left in it on the next launch. This was the tech report's own recommendation and was dropped.
     - On `localVersionConflictingWithServer`, stop; do not retry.
     - I9: resume only when `ubiquitousItemIsSyncPaused == true` and the user confirms the app that paused it is closed. There is no known API for finding which app owns the pause [U].

8. **L6(b), move out and back: the cross-device effect is not stated.**
   - Moving an item out of CloudDocs removes it from iCloud on the user's other devices until it is moved back. If another device edited the server copy meanwhile, that edit can be lost. [L]
   - **Change:** require a verified L0 first, and spell this out in the consent sheet. Prefer L6(b) only for items that have never been uploaded (`isUploaded == false`). Use a staging folder on the same volume so the move is a rename.

9. **`ci.yml` will fail on PRs.**
   - `project.yml` pins `CODE_SIGN_STYLE: Manual` and `CODE_SIGN_IDENTITY: "Developer ID Application"`, and PR jobs have no certificate. [L]
   - **Change:** add `CODE_SIGNING_ALLOWED=NO` to the `xcodebuild build` line in `ci.yml`.

10. **§3.3 Process runners: timeouts and a pipe deadlock.**
    - A single 10 s timeout is too short for `log show` over archives [U on exact times].
    - Calling `waitUntilExit()` before reading a `Pipe` deadlocks once output passes about 64 KB, and ndjson windows exceed that easily. [L]
    - **Change:**
      - Drain stdout on a background thread, or with `readabilityHandler`, until EOF.
      - Use per-tool timeouts, for example 60 s for `log show` and 30 s for `system_profiler`, and cap output size.
      - Fetch log cause strings asynchronously after an episode closes, never on the recorder queue.

11. **E1/E2 root-vs-hub logic assumes USB is tunneled to the Mac's own controller.**
    - TB3 docks carry their own PCIe USB controller, so their devices are behind neither a `usb-drdN` root port nor an `AppleUSB*HubPort`. A dock drop then shows up as a Thunderbolt switch plus controller termination.
    - TB4/USB4 docks do tunnel USB to the Mac's own controller. [L; class names U]
    - **Change:** classify the dock type during preflight and branch the E1 rules. Add a TB3 dock to the test hardware and capture fixtures from it.

12. **"Sleep blocked" arm.**
    - `kIOPMAssertionTypePreventUserIdleSystemSleep` only blocks *idle* sleep. Lid close with no external display, Apple menu > Sleep and low-battery sleep still happen. Display sleep also still happens. [L]
    - **Change:** check each session against `pmset -g log` and discard it if it contains a Sleep entry. If you test display sleep, make it a separate arm (`…PreventUserIdleDisplaySleep`) so each arm still changes only one variable.

13. **DiskArbitration approval callback.**
    - DA waits for the client's reply on every unmount system-wide. If the recorder's queue is busy, every Finder eject stalls. [L]
    - **Change:** call `DASessionSetDispatchQueue` with a dedicated queue. In the callback, only record the BSD name and a timestamp, then return nil immediately.
    - Add forced unmount (`diskutil unmount force`) to §6 item 6; whether it triggers the approval callback is [U].

14. **Login item.**
    - `SMAppService.mainApp.register()` can leave the item in `.requiresApproval`, and the user can switch it off in Login Items. When that happens the recorder silently stops.
    - **Change:** check `SMAppService.mainApp.status` at every launch and show "Recorder not running at login" when it is not `.enabled`. Ask before registering at first run.

15. **Swift on Windows (§3.2).**
    - `winget install Swift.Toolchain` alone is not enough; swift.org's Windows setup also needs the Visual Studio C++ build tools and the Windows SDK. [L]
    - **Change:** add that step to §3.2. 

=== CRITIQUE 2 ===
 **Verdict:** v1 is too big for one person to ship. It is two products plus a platform: 13 collector layers, a signed KB channel, a licence server, and a statistics engine. The 16–17 weeks has none of the 30–50% slack that risk #1 asks for, so the realistic launch is February–March 2027. Cut v1 to iCloud Rescue alone. Everything else ships later as a 1.x update.

## Problems and changes (most severe first)

1. **Two modules in v1, with no slack.**
   - Change: ship iCloud Rescue alone as v1.0 at $19. Dock Detective becomes a free 1.x update, and the price moves to $29 when it ships. Early buyers are already covered by "all 1.x and 2.x included".
   - Why iCloud goes first:
     - It needs only one Mac and one Apple ID.
     - It can be tested in 15+ VMs [V: https://developer.apple.com/documentation/virtualization/using-icloud-with-macos-virtual-machines].
     - A stuck-iCloud user gets an answer in one session, which fits the 14-day refund window.
     - Dock verdicts take weeks (see #3), and the developer's own dock will not reproduce anyone's fault.

2. **The Dock A/B wizard cannot reach "Proven" in a realistic time.** I computed two-sided Fisher p-values where the variant arm has 0 failures:
   - 3 failures of n baseline sessions gives p ≥ 0.1667 for every n.
   - 4/10 gives 0.0867.
   - 5/10 gives 0.0325, but 5/30 gives 0.0522.
   - So "Proven" needs about 5–6 baseline failures. The minimum rule ("≥3 baseline failures") can only ever produce "Likely".
   - For a fault that happens twice a week, that is about 2.5 weeks per arm, so 6+ weeks for baseline plus 2 arms. That is far past the refund window.
   - The "Sleep blocked" arm does not work on a laptop. `kIOPMAssertionTypePreventUserIdleSystemSleep` still allows sleep "for lid close, Apple menu, low battery" [V: https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep].
   - Change: Dock 1.x should ship the recorder, single-episode classification, preflight checks and the support packet.
     - Single-episode classification means E1–E5 using the kernel reason: root port vs hub port, physical vs link. This localizes the fault from the first episode, with no multi-day test.
     - The wizard comes later, reports plain counts ("Docked: 4 drops in 3 days, Direct: 0 in 3 days") and shows how many sessions are still needed instead of a p-value.
     - Replace the "Sleep blocked" arm with a "disk sleep off" arm (`pmset`).

3. **The v1.1 Sleep Detective premise is false.** WhatBattery Pro (£9.99 once, 2 Macs, MIT free tier) already shows per-sleep charge lost, wake count, wake reasons with plain-English labels, the current assertions, and per-app watts. It is by the same developer as WhatCable and WhatPort [V: https://www.whatbattery.app/features/sleep/ , https://github.com/darrylmorley/whatbattery]. Juicy covers drain history too.
   - Change: drop Sleep Detective from the roadmap, the pricing page and the justification for $29.
   - Widen risk #4: that developer has now shipped three apps (cable, port, battery).

4. **Develop on the Mac, not Windows.** The Windows plan outlives its premise: the Mac is mandatory before week 2, so Windows portability buys about one week. What it costs:
   - two packages
   - a Core limited to Foundation
   - `PropertyListSerialization` on Windows [U]
   - a CI round trip for every SwiftUI change, with no previews
   - Change:
     - Use one package with Core and Mac targets, and develop in Xcode on the Mac.
     - Keep the pure-function fixture tests.
     - Drop the Windows build and the `winget` step.
     - CI stays for compile checks and signed releases.
     - Sign local builds with an Apple Development certificate, because ad-hoc signing resets TCC grants on each rebuild [L].

5. **The licensing stack is overbuilt.** Today it is a Worker, a PKCS#8 import [L], a third Ed25519 key, `issue_license.py`, `revokedLicenses` in the KB, `maxMajor`, and a CI round-trip test.
   - Dodo's `/licenses/activate` needs no API key. It returns 403 for an inactive key and 422 at the activation limit, and `refund.succeeded` disables the key automatically [V: https://docs.dodopayments.com/features/license-keys].
   - Change:
     - The app calls Dodo's activate endpoint directly, once. It checks `product.product_id` against a constant, stores the response, and never checks again.
     - Delete `worker/`, `LICENSE_KEY_PKCS8_B64`, `issue_license.py`, `revokedLicenses` and `maxMajor`.
     - The sunset pledge still covers Dodo disappearing.
     - Add a Worker only if Dodo actually fails.

6. **The signed remote KB is a second update channel.** Sparkle already ships signed updates, and a release run costs under $1.
   - Change: bundle `kb.json` in the app and ship KB changes as point releases.
   - This deletes `KBUpdater`, `kb.json.sig`, `KB_SIGNING_KEY`, `sign_kb.py`, and one network endpoint.

7. **The iCloud rules and fix ladder carry dead or unverified work.**
   - **I3** (26.2 bug, fixed in 26.3) and **I12/L5** (26.4.1 stall) target point releases that will be superseded before a 2027 launch. Keep them as KB text only, with no code.
   - **L5 contradicts the doc's own marketing.** The marketing tells users not to run `killall nsurlsessiond`, but L5 runs `pkill -U <uid> nsurlsessiond`. A non-root `killall` can only signal the user's own processes anyway [L], so it is the same act. Cut L5.
   - **L4, L6(a), L7 and I9** depend on unverified behaviour [U]. Leave them out unless the week-1 hardware check passes.
   - **I17** is a help article, not code.
   - **I5** should show copyable `chflags` commands for all flags, so there is one code path.

8. **The materialization guard is fragile.** Setting the policy on one dedicated scan thread leaves any other thread free to trigger a download.
   - TN3150 allows `IOPOL_SCOPE_PROCESS` [V: https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files]. The app never needs to download content.
   - Change: call `setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)` once at launch, delete the dedicated thread, and treat `EDEADLK` as "dataless".

9. **The rescue copy location is a data-loss risk.** Uninstallers such as AppCleaner and CleanMyMac remove `~/Library/Application Support/<App>` along with the app [L], and non-technical users cannot find it there.
   - Change: default to a visible folder outside iCloud, `~/Whydunit Rescue/<date>/`.

10. **The free/paid split doubles the copy and leaks anyway.** A free title like "Your iCloud storage is full" already is the cause.
    - Change: put one gate at the action layer.
      - Free: the full diagnosis, the local-only warning and the CSV.
      - Paid: the safety copy, the fix buttons and the report.
    - This follows the EtreCheck precedent: free report, paid Solutions.

11. **macOS 14 cannot be tested.** A new Mac cannot install a macOS older than the one it shipped with [V: https://support.apple.com/en-us/102662], and iCloud in a VM needs 15+ on both host and guest. macOS 14 also forces the old root-port class names and the path for missing `UsbIOPort`.
    - Change: set the minimum to macOS 15.0.

12. **The week-1 gates are in the wrong order.**
    - Apple enrolment in India needs the Apple Developer app on an Apple device [V]. Notarized builds therefore wait for approval.
    - Dodo live verification needs a live site with pricing, terms, privacy, refund and contact pages. "Still under development" is a listed rejection reason, and you get only one appeal [V: https://docs.dodopayments.com/miscellaneous/verification-process , https://docs.dodopayments.com/miscellaneous/faq].
    - Change:
      - Open a Dodo test-mode account in week 1.
      - Submit verification about 2 weeks before launch, once the landing page is live.
      - For the name, run free knockout searches on USPTO, EUIPO and IP India. Skip paid clearance before there is revenue.

13. **The beta recruitment plan breaks Apple Community rules.** The rules forbid advertising and forbid links to your own sites or links that benefit you [V: https://discussions.apple.com/terms].
    - Change: recruit through your own SEO pages and write them early.
    - Beta 1 should be read-only. Enable the fix ladder in beta 2.

14. **v1 carries dock-only baggage.** `MenuBarExtra`, the always-on recorder, the `SMAppService` login item, and the HTML report with its redactor are only needed for Dock.
    - Change: iCloud v1 is a plain `WindowGroup` app with a "Copy diagnosis" text export, where the home path is replaced by `~`.

15. **Dock Detective rewrites what already exists.** WhatCable (MIT) has `Sources/WhatCableDarwinBackend` watchers and a pure `WhatCableCore` [V: https://github.com/darrylmorley/whatcable].
    - Change: vendor those watchers with attribution. Spend the time on what nobody else does: DiskArbitration graceful-vs-surprise detection, display flaps, log reasons and verdicts.

16. **The hardware spec is loose.**
    - Buy a MacBook Air 13" M5, 16 GB / 512 GB: ₹149,900 MRP [V: apple.com/in]. 256 GB cannot hold 15 and 26 VMs plus their IPSWs.
    - Defer the dock gear until Dock work starts.

## Minimum lovable product and build order

**MLP (iCloud Rescue):**
- **Scan:** a free scan using rules I1, I2, I4, I5 (commands only), I6, I7, I8, I10, I11, I13, I15 and I16, plus the probe, the storage-debt check and the "only on this Mac" list.
- **Paid:** L0 safety copy with a SHA-256 manifest, then L3, then L6(b) one item at a time, plus the audit log.
- **Licensing:** Dodo direct activation behind a single gate.

**Order:**
- **Week 0, on Windows:**
  - Order the Mac.
  - Open the Dodo test-mode account.
  - Run the name knockout search and buy the domain.
  - Generate the Sparkle key.
  - Set up a CI skeleton that makes an unsigned `macos-26` build.
  - Write the classifier against synthetic records.
- **Week 1, Mac arrives:**
  - Enrol in the Developer Program.
  - Run a 2–3 day spike on §6 items 1, 2 and 4, and time a scan of 100k items (whether per-item ubiquity reads are fast enough is [U]).
  - Build the 15 and 26 VMs.
- **Weeks 2–4:** build the free scan and diagnosis UI.
- **Week 4:** landing page plus two SEO articles, then the read-only beta.
- **Weeks 5–6:** safety copy, L3, L6(b) and the audit log.
- **Week 7:** paywall and activation. Submit Dodo verification. Beta 2 includes the fix ladder.
- **Weeks 8–9:** hardening, then launch.
- **With 30% slack:** about 12 weeks, so late December 2026.
- **After launch:**
  - Dock 1.1: recorder, episode classifier, preflight rules P1/P3/P4/P5/P6/P7/P10, and the HTML packet. Price moves to $29.
  - Build the wizard only if 1.1 users get stuck at "Possible". 

=== OPEN QUESTIONS ===
- competitors-ports-displays: Does WhatPort's Flight Recorder internally log system sleep/wake or display reconfiguration events (not advertised)? Is its developer planning a guided diagnosis feature?
- competitors-ports-displays: What is Porta's (porta.uwucocoa.moe) price and launch date?
- competitors-ports-displays: Which IORegistry property does WhatPort read to flag that macOS has blocked a connection (accessory security)?
- competitors-ports-displays: Do `pmset -g log` and `log show` work without admin on macOS 27? Which log predicates reliably capture Thunderbolt/PCIe reconfiguration before disk ejects (OWC mentions PCI configuration changes a second or two earlier)?
- competitors-ports-displays: Is 'Put hard disks to sleep when possible' still exposed in System Settings on macOS 27 laptops and desktops, or only via pmset?
- competitors-ports-displays: Do read-only IORegistry queries and spawning system_profiler/pmset work inside the App Sandbox (USB Connection Information suggests the reads do)?
- competitors-ports-displays: Can `pmset sleepnow` or a similar non-root API force sleep cycles for automated A/B arms? How many cycles per arm are needed for a statistically meaningful verdict on intermittent faults?
- competitors-ports-displays: Which merchant of record (Paddle, Lemon Squeezy, Stripe) works best for an India-based solo developer selling one-time licences globally? This was not researched here.
- competitors-ports-displays: Is the DriveDx licence one-time or a subscription (the store page does not say)?
- competitors-ports-displays: Are the JSON key names in `system_profiler SPThunderboltDataType -json` (current_speed_key, link_status_key, receptacle_status_key) stable on macOS 26/27? Verify on real hardware.
- competitors-icloud: Which brctl subcommands (status, download, evict) exist and behave reliably on macOS 26.x and 27.0? Sources conflict on whether download and evict were removed in Sonoma.
- competitors-icloud: Can a third-party, non-sandboxed app call pauseSyncForUbiquitousItem, resumeSyncForUbiquitousItem or uploadLocalVersionOfUbiquitousItem on arbitrary com~apple~CloudDocs items it did not open? Is ubiquitousItemUploadingErrorKey filled in for them?
- competitors-icloud: Where are the Desktop & Documents and Optimize Mac Storage states stored, and can a third-party app read them safely? The key names are unverified.
- competitors-icloud: Does Cirrus 1.16 already list every not-uploaded item with its error? Install it on a real Mac to position against it honestly.
- competitors-icloud: Did macOS 27 Golden Gate change iCloud Drive status UI or FileProvider behaviour? No authoritative source was found.
- competitors-icloud: What are the Mac-side filename rules for iCloud Drive (colon, NFD/NFC normalization, length)? No Apple source was found.
- competitors-icloud: Which TCC service and prompt apply when a non-sandboxed app reads ~/Library/Mobile Documents, and does the macOS 26.x access-loss regression affect non-sandboxed apps?
- competitors-icloud: Can GitHub Actions macOS runners sign in to iCloud at all? Assume not.
- competitors-icloud: Carbon Copy Cloner's current price, and Stellar's vendor-listed price (only a Reddit mention of $70 was found).
- competitors-upgrade: Does the macOS 26.6 final release (not just 26.6b3) include Apple's fix for installing the macOS 27 IPSW via VZMacOSInstaller? What will the macOS 27 host / macOS 28 IPSW situation be in 2027?
- competitors-upgrade: On a macOS 26 host, does VZMacOSRestoreImage.fetchLatestSupported return the macOS 27 image, or only the newest image the host supports?
- competitors-upgrade: What exact string values does arch_kind take in system_profiler -json SPApplicationsDataType, and is the SPLegacySoftwareDataType schema stable across 27.x?
- competitors-upgrade: What is the exact macOS 27 Settings path to the Intel-apps list (General > About > Intel-based apps > Details vs General > About > macOS > Details), and does it show launch counts?
- competitors-upgrade: Does RoaringApps offer any API or data licence, and how many Golden Gate reports exist per popular app?
- competitors-upgrade: Is Rosetta Check's '500+ Mac App Store ratings' claim accurate (the US store shows too few ratings)? What is its sales rank?
- competitors-upgrade: What are the exact current Parallels Desktop 26 prices (one-time Standard, Pro, Business) in USD and INR?
- competitors-upgrade: Do Iru (Kandji) or Mosyle ship any built-in Intel-app or OS-readiness report?
- competitors-upgrade: Does the macOS EULA's 'personal, non-commercial use' VM clause cover prosumers testing paid professional workflows? This needs legal review.
- competitors-upgrade: What are the per-vendor licence activation limits (iLok, Native Access, Adobe) when reinstalling apps inside a VM?
- competitors-upgrade: What is the exact size of the macOS 27 IPSW, and what is the minimum practical RAM and disk for a usable macOS 27 guest?
- competitors-upgrade: Reddit VPN breakage threads on macOS 27 could not be fetched. Which VPN clients and configurations were actually affected in the GA release?
- competitors-general-health: Does Sleep Aid 1.5 still work on macOS 26 Tahoe / 27 Golden Gate, and what is its upgrade policy?
- competitors-general-health: How does Juicy compute per-app energy history (method and accuracy), and how much traction does it have?
- competitors-general-health: What does MacBookBatteryMonitor cost? Mac Power Monitor's $15 comes only from a secondary source.
- competitors-general-health: What are coconutBattery Plus's exact current prices? The official page renders them via JS, so $12.95/$19.95/$17.95 comes from a search snippet.
- competitors-general-health: What does the iStat Menus weather renewal cost?
- competitors-general-health: Will macOS 27.x add an iPhone-style per-app battery usage view to System Settings? That would erode the battery-attribution opportunity.
- competitors-general-health: Is EtreCheckPro supported on macOS 27? MacUpdate shows only 6.8.12 with Tahoe support.
- competitors-general-health: Did AlDente lifetime licence holders have to pay for v2 (Reddit comment, unverified)?
- competitors-general-health: Where do the CleanMyMac auto-renew/refund complaint counts come from? No primary source was found.
- competitors-general-health: When was Battery Toolkit 1.8 released? The GitHub page rendered 2024, but the notes reference macOS 26.
- competitors-general-health: Reddit threads could not be fetched directly (blocked); vote and comment counts come from search snippets and should be spot-checked in a browser.
- tech-ports-displays: Does OSLogStore's NSPredicate accept process/sender keys on macOS 14–27, and is OSLogStore fast enough over hours of history, or is spawning 'log show --style ndjson' better?
- tech-ports-displays: What are the exact kernel log messages (and sender names) for Thunderbolt/USB4 link drops and DisplayPort link-training failures on Apple silicon?
- tech-ports-displays: Which DP LinkRate codes does IOPortTransportStateDisplayPort use for UHBR10/13.5/20?
- tech-ports-displays: What JSON keys does system_profiler SPUSBHostDataType use, and does it reliably list devices (not only controllers) on every 26.x/27.x build?
- tech-ports-displays: Does the DiskArbitration surprise-removal heuristic hold across Finder eject, diskutil eject, a cable pull, a drive firmware reset and sleep/wake?
- tech-ports-displays: What do NotChargingReason, SlowChargingReason, ChargerInhibitReason and the TRM_State codes mean?
- tech-ports-displays: Can standard (non-admin) users run pmset -g log and system_profiler on macOS 26/27, and what is the best UX for non-admin users who lack log access?
- tech-ports-displays: Are there any IOKit class or key changes in macOS 27 ('Golden Gate') beyond what WhatCable's 27.0 corpus shows?
- tech-ports-displays: What is the current wording of the over-current alert on macOS 26/27 ('USB Devices Disabled' vs 'Accessories Need Power')?
- tech-ports-displays: Which class carries 'link-error-count' in ioreg, and is kPortStatEOF2ViolationCount a meaningful link-error metric?
- tech-icloud: Does ubiquitousItemDownloadingStatus / ubiquitousItemIsUploaded / ubiquitousItemUploadingError return nil on macOS 26/27 when read from a Developer ID .app bundle, and not only from a CLI or launchd agent? Do they populate correctly for genuinely stuck files?
- tech-icloud: Do FileManager.pauseSyncForUbiquitousItem and uploadLocalVersionOfUbiquitousItem (macOS 26+) work on iCloud Drive items when called by a non-entitled, non-sandboxed app?
- tech-icloud: Does reading CloudDocs/Desktop or CloudDocs/Documents (with Desktop & Documents in iCloud enabled) trigger the Desktop/Documents TCC prompt? When does kTCCServiceFileProviderDomain prompt?
- tech-icloud: Which brctl subcommands (download, evict, diagnose, dump, quota) exist on macOS 15, 26 and 27, and which need sudo?
- tech-icloud: Is ~/Library/Application Support/CloudDocs or FileProvider on macOS 27's new com.apple.macl-protected Application Support list?
- tech-icloud: Do NSFileVersion local versions survive a same-volume move out of and back into iCloud Drive?
- tech-icloud: Are file-name characters, path length, symlinks, or files held open by apps actual documented causes of stuck uploads under FileProvider? No primary source was found.
- tech-icloud: What is the raw numeric value of NSFileProviderError.Code.excludedFromSync, and does iCloud Drive surface it through ubiquitousItemUploadingError?
- tech-icloud: Does renaming in place reliably re-trigger an upload under FileProvider? It is a community-reported workaround only.
- tech-upgrade: Does a macOS 26.6.x host need any extra component (Device Support / MobileDevice) to install the macOS 27.0 release IPSW? And does VZMacOSRestoreImage.latestSupported on a 26.x host return 27.0?
- tech-upgrade: Can Rosetta be installed and used inside a macOS 27 guest VM, so Intel apps can be test-driven there?
- tech-upgrade: Do `kmutil showloaded` and `systemextensionsctl list` run without root on macOS 14–27?
- tech-upgrade: What is the current IncompatibleAppsList.plist schema, and where does it sit inside the macOS 27 installer or IPSW, so the target OS's list can be read before upgrading?
- tech-upgrade: What exactly does the macOS 27 Golden Gate SLA say about virtualization? (Only the Tahoe SLA was verified.)
- tech-upgrade: Is MacStadium/Scaleway/AWS bare-metal Mac rental pricing viable for a solo developer in India? Not researched.
- tech-upgrade: Would RoaringApps license its compatibility data, and on what terms?
- tech-upgrade: Is the MacRumors claim true that macOS 27 automatically removes a previously installed Rosetta?
- tech-upgrade: Does Swift's `import MachO` expose CPU_TYPE_X86_64 and FAT_MAGIC_64 directly? (Moot if you define the constants yourself.)
- distribution-licensing: What is the exact INR amount for the Apple Developer Program in India in 2026? (~₹9,500 from a third-party source is unverified.)
- distribution-licensing: Which App Store Connect API key role is the minimum needed for notarytool? (Third parties say Developer; Apple doesn't say.)
- distribution-licensing: Does Xcode 27 still build x86_64 slices? This determines whether Intel Macs on macOS 26 and earlier can receive builds made with Xcode 27.
- distribution-licensing: Does Dodo Payments' manual fulfillment endpoint (POST /grants/{id}/license-key) accept ~200-character self-signed Ed25519 tokens as the license key value?
- distribution-licensing: What are FastSpring's and PayPro Global's actual fees, and do they pay out to Indian individuals?
- distribution-licensing: What GST registration threshold, LUT filing and FIRA/FIRC documentation applies to an Indian individual receiving USD payouts from a foreign MoR?
- distribution-licensing: How exactly do pmset -g log, log show, system_profiler and brctl behave when launched from a sandboxed app? This matters only for a possible future Mac App Store 'lite' SKU.
- distribution-licensing: Is WhatPort sandboxed despite reading IOKit/SMC? That would indicate how much IOKit reading is possible under App Sandbox.

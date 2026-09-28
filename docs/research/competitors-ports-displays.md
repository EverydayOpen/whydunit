# Competitor teardown: Mac USB-C / Thunderbolt / dock / display / external-drive diagnostics (Need 3)

Research date: 2026-09-27. Scope: the "Dock & Display Doctor" idea, a tool that finds the cause of intermittent dock, monitor and external-drive failures instead of only recording disconnects.
Confidence tags: **[V]** verified against the cited primary source. **[L]** likely: from a secondary source or a standard API that was not re-fetched. **[U]** unverified.

---

## 0. TL;DR

1. **The information layer is crowded and cheap.** WhatPort (free and MIT-licensed; Pro is £9.99 one-time for 2 Macs), WhatCable (free and MIT; Pro $9.99 one-time), USB Connection Information ($9.99 one-time, on the Mac App Store), Display Connection Information ($5.99) and Apple's own System Information all show what is connected and what speed or power was negotiated. None of them says why a failure happened. [V]
2. **WhatPort Pro is the closest competitor.** Its "Flight Recorder" keeps a persistent history of connection and power events, port-health and PD-reliability counters, alerts, and CSV/JSON export. It says outright that a timeline event does not by itself prove which cable or device caused a fault. It has no guided test. It only suggests comparing readings after you change a cable, dock or port. [V] https://www.whatport.app/
3. **Display utilities control displays. They do not diagnose them.** BetterDisplay ($21.99 / €19.99, perpetual licence with at least 1 year of updates) has the deepest diagnostics: connection, bandwidth, DSC, EDID, DPCD, disconnect/reconnect, and per-display commands on sleep/wake. It keeps no fault history and gives no verdict. Lunar ($23), DisplayBuddy ($24.99 and up) and MonitorControl (free) are about DDC brightness. [V]
4. **Drive tools only look at SMART.** DriveDx and Disk Drill say nothing about whether an eject came from sleep, the dock or a cable. On Apple Silicon, reading SMART from an external USB drive needs the third-party SAT SMART Driver kext, and that needs Reduced Security. [V]
5. **Eject-before-sleep tools hide the symptom.** Jettison ($6.95) and Ejectify (€6.99) unmount drives before sleep so the warning never appears. [V]
6. **Dock vendor utilities are free and tied to one brand.** CalDigit, OWC Dock Ejector, Anker Dock Manager, Belkin Dock Utility and Plugable offer eject, firmware or status features. None runs a diagnosis across vendors. [V]
7. **No product was found that runs a guided A/B protocol and ends with an evidence-based verdict.** Vendor knowledge-base articles from OWC, CalDigit and Plugable already describe that protocol step by step for the user to do by hand: go direct instead of docked, try one port at a time, swap the cable, power-cycle the dock, disable sleep for a few days. **Automating and scoring that protocol is the gap.** [V for the KB content; "none exists" is based on searches that returned nothing, see §8]

---

## 1. Competitor matrix

| Product | URL | Price | Licence model | What it does | Guided A/B test? | Root-cause verdict? |
|---|---|---|---|---|---|---|
| **WhatPort** | https://www.whatport.app/ | Free; **Pro £9.99** | Free is open source (MIT). Pro is **one-time, 2 Macs**, with a 14-day money-back guarantee and 50% off for students | Live per-port protocol, speed, lanes and power. Pro adds the Flight Recorder (event history, device tree, power graphs, port health, PD reliability counters, alerts, CSV/JSON export) | **No.** Manual "compare after changing cable/dock/port" | **No.** It disclaims causation |
| **WhatCable** | https://www.whatcable.uk/ , https://github.com/darrylmorley/whatcable | Free; **Pro $9.99** (listed as £9.99 on its site) | MIT. Pro is one-time, 2 Macs | Cable e-marker decode, "trust signals", negotiation and display bottleneck diagnostics, CLI (`--json`, `--watch`). Pro adds cable history, power metering, port health and a cable-resistance estimate | No | Partial: it names the bottleneck (cable vs port vs device) for one connection, not for intermittent faults |
| **USB Connection Information** | https://usbconnectioninformation.com/ | **$9.99** | One-time. Mac App Store and Setapp. Suite bundle $19.99 | Negotiated USB speed, charger PD profile, Finder speed badges, widgets, "slow connection" alerts | No | No |
| **Display Connection Information** | https://usbconnectioninformation.com/display-connection-info-mac-app/ | **$5.99** | One-time, App Store (rated 4.2) | Resolution, refresh rate, bit depth, HDR, HiDPI scale | No | No |
| **Porta** | https://porta.uwucocoa.moe/ | Not published ("Coming Soon") | Unknown | Port → cable → tunnel → hub → device topology, "conservative" alerts, remote agent (macOS and Linux) | Not advertised | Not advertised |
| **macOS System Information / `system_profiler`** | built in | Free | n/a | USB, Thunderbolt/USB4 and Graphics/Displays trees; shows the dock's firmware version | No | No |
| **BetterDisplay** | https://betterdisplay.pro , https://github.com/waydabber/BetterDisplay | Free; **Pro $21.99 / €19.99** | **Perpetual**, including at least 1 year of updates. v5 is free only for purchases made on or after 2025-01-01 | HiDPI, DDC, EDID override, virtual screens, disconnect/reconnect, "configuration protection", per-display commands on connect/disconnect/sleep/wake, connection/bandwidth/DSC/EDID/DPCD diagnostics, CLI | No | No |
| **Lunar** | https://lunar.fyi/ | **$23** | Lifetime. Its EULA allows 5 Macs and free updates "indefinitely", but also says a major upgrade may cost extra. 14-day trial | DDC brightness/volume/input, XDR brightness, BlackOut (turn a display off), sync, sensor | No | No |
| **DisplayBuddy** | https://displaybuddy.app/pricing | **$24.99** (1 Mac), **$29.99** (2), **$49.99** (5) | One-time, lifetime updates, 7-day money-back guarantee | DDC brightness, contrast, volume, input, presets, schedules | No | No |
| **MonitorControl** | https://github.com/MonitorControl/MonitorControl | Free | MIT, about 34.3k stars | DDC and gamma brightness/volume. v4.4.0+ needed for macOS 27 | No | No |
| **CalDigit Docking Station Utility** | https://www.caldigit.com/caldigit-docking-station-utility-update/ | Free | Vendor | Eject USB and Thunderbolt drives on CalDigit docks, individually or all at once | No | No |
| **OWC Dock Ejector 2.1** | https://www.owc.com/solutions/dock-ejector | Free | Vendor | One-click eject for any dock or hub, remount, SoftRAID-aware, enables high-power TB dock ports without Reduced Security. Does not work with the OWC TB3 Pro Dock | No | No |
| **Anker Dock Manager** | https://www.anker.com/dockmanager-download | Free | Vendor. macOS 10.14+ | Firmware OTA, charging info, HDMI/DP details, network status, FAQ and support links. Supports 3 Anker Prime docks | No | No |
| **Belkin Dock Utility** | https://www.belkin.com/business/belkin-dock-utility/ | Free | Vendor | MAC-address pass-through and reset, Wi-Fi auto-switch, "device connection monitoring" | No | No |
| **Plugable** | https://plugable.com/pages/support | Free | Vendor | PlugDebug log collector for support, plus KB decision trees | No | No |
| **DriveDx** | https://binaryfruit.com/drivedx , https://binaryfruit.com/store | Personal (3 computers) **$19.99** on sale from $24.99; Family (6) $39.99; Business from $49.99 for 2 | Store page does not say whether it is one-time or a subscription | SMART health, self-tests, SSD wear, email reports. Supports macOS 10.9 to 26 | No | Drive health only |
| **Disk Drill** (SMART monitoring) | https://www.cleverfiles.com/help/monitor-smart-status-disk-health/ | SMART monitoring is free. **PRO is $89/yr or $149 lifetime** (3 devices) | Freemium, recovery-focused | Menu-bar SMART, alerts every 2 min, uses smartmontools | No | Drive health only |
| **Jettison** | https://www.stclairsoft.com/Jettison/ | **$6.95** ($5.95 each for 2+) | One-time, 15-day trial, macOS 10.13 to 27 | Eject before sleep or display-off, remount after wake, shows which processes block an eject | No | No |
| **Ejectify** | https://ejectify.app/ | **€6.99** | One-time, open source, direct sale only | Per-volume unmount before sleep, display-off, lock or screensaver; remount; force unmount; mute the warning; diagnostics report | No | No |

---

## 2. Detailed teardowns

### 2.1 WhatPort (main competitor)

- **Who and what:** a menu-bar or windowed app by Darryl Morley, the author of WhatCable. It is signed, notarised and MIT-licensed, installable by `.zip` from GitHub Releases or `brew install --cask darrylmorley/whatport/whatport`. It needs macOS 14+ and gives full detail only on Apple Silicon. Intel Macs get reduced detail: no per-port PD contracts, pin configuration or port health, because Intel Macs do not publish `AppleTypeCPhy` and `IOPortTransportStateCC`. [V] https://www.whatport.app/
- **Free tier:** live USB-C and Thunderbolt port status; protocol and negotiated speed; device and dock names; reported power and charging status; lane and display readings where supported. [V]
- **Pro tier (£9.99 one-time, 2 Macs):**
  - connection and power event history that survives app restarts
  - a device tree for each port and dock
  - per-port power graphs over time
  - port-health scores and PD reliability counters
  - alerts for disconnects, link errors, overcurrent and "other port events"
  - session recording with CSV/JSON export [V]
- **Other features:**
  - connection lifecycle states (Detecting, then Negotiating)
  - display link rate (HBR2/HBR3), lanes, native vs Thunderbolt-tunnelled, HDMI converter detection
  - lifetime connection counts and error counts per port (overcurrent, link errors, enumeration failures)
  - cable active/passive status and PD revision from the e-marker
  - **a flag when macOS has blocked a connection** (the accessory-security case)
  - charger identification, charging-hold reason, liquid detection on M3 and later [V]
- **Data sources it names:** `AppleTypeCPhy` (lane state), `IOThunderboltPort` (TB link speed, width, generation, socket ID), and SMC + USB-PD (per-port power). It reads without root, System Extension or daemon. Connection events come from IOKit interest notifications. [V] https://github.com/darrylmorley/whatport
- **Traction:** about 60 GitHub stars. Recent releases were all in August:
  - v1.10.0 (Aug 10): Intel universal build and per-port energy
  - v1.9.0 (Aug 8): PD reliability counters for hard resets and role-swap failures
  - v1.8.0 (Aug 8): full device tree behind docks
  - v1.7.0 (Aug 5): Flight Recorder accuracy and "fewer false disconnect counts" [V] https://github.com/darrylmorley/whatport/releases
- **Gaps relevant to us:**
  - **No guided A/B protocol.**
  - **No verdict.** It disclaims causation.
  - No correlation with display reconfiguration events, volume unmount/disappear events or system sleep/wake. The events it records are "connection and power events"; nothing else is advertised. [V for what it advertises; whether it records other events is U]
  - No knowledge base of known issues by macOS version and dock model.
  - No vendor-ready evidence report beyond CSV/JSON.
- **Competitive risk:** the same developer's WhatCable got heavy press and about 8.8k GitHub stars (see §2.2). He clearly has distribution. Adding a "diagnose" wizard would be a natural next step for him. **Treat this as the main threat.**

### 2.2 WhatCable (same developer)

- It reads `AppleHPMInterfaceType10/11/12`, `AppleTCControllerType10/11`, `IOPortFeaturePowerSource`, `IOPortTransportComponentCCUSBPDSOP` / `...SOPp` / `...SOPpp` (cable e-marker and device identity), and the XHCI subtree. It needs no entitlements or private APIs. [V] https://github.com/darrylmorley/whatcable
- CLI:
  - `whatcable`, `--json`, `--watch`, `--raw`, `--report`, `--test-kit`, `--no-usb-probe`
  - Pro only: `--dashboard`, `--monitor` [V]
- Limitations:
  - Apple Silicon only, macOS 14+.
  - It cannot check the physical wiring inside a cable.
  - Unmarked cables under 60 W show no e-marker data.
  - Front USB-C ports on desktop Macs lack cable and power detail. [V]
- Press: The Verge and PetaPixel (both 2026-07-13), SlashGear (2026-08-05), Indian Express (2026-06-17). It launched in May 2026 and has about 8.8k stars. [V] https://petapixel.com/2026/07/13/free-mac-app-unravels-all-your-annoying-usb-c-cable-mysteries/

### 2.3 USB Connection Information and Display Connection Information (Daniel Gauthier)

- **USB Connection Information**
  - $9.99 one-time on the Mac App Store (app id 6747853674) and on Setapp. It also has Windows and Linux versions, and an iOS version is included with the Mac purchase. [V] https://usbconnectioninformation.com/
  - Features: negotiated speed, PD profiles, Finder speed badges, widgets, and "speed alerts" for slow links.
  - It says Thunderbolt-only devices that do not expose a USB interface may not appear. [V]
  - Its developer said on Reddit that it had been in the top 100 paid utilities for about half the time since release. [V] https://www.reddit.com/r/UsbCHardware/comments/1n21qjo/
- **User requests in that thread** show what users want beyond raw data: sorting by physical port, a detachable window, and columns instead of a long list. The developer said it cannot read passive-cable e-markers, and that the OS does not expose TB speeds above 40 Gb/s. [V]
- **Display Connection Information** ($5.99, rated 4.2) covers resolution, refresh rate, bit depth, HDR and HiDPI scale. The suite of 4 apps costs $19.99. [V] https://usbconnectioninformation.com/suite/
- **Implication:** this suite runs inside the App Store sandbox. That suggests read-only IORegistry and CoreGraphics queries work when sandboxed. [L, inferred from its App Store presence]

### 2.4 macOS System Information / CLI (the free baseline)

- **Tahoe regression:** `system_profiler SPUSBDataType` was removed in macOS 26. `SPUSBHostDataType` returns only host controllers, not the attached devices. Apple Community users noted they could no longer correlate a USB drive with its mounted volume. [V] https://discussions.apple.com/thread/256180514
  - A balena PR notes that `system_profiler` silently ignores unknown data types (exit 0). The workaround is to query both types. [L] https://github.com/balena-os/iot-gate-imx8plus-flashtools/pull/22
- **Thunderbolt:** `system_profiler SPThunderboltDataType -json` exposes keys like `current_speed_key` (for example "Up to 40 Gb/s x1"), `link_status_key` (0x2 means OK, 0x100 means nothing connected) and `receptacle_status_key`. [L, from secondary sources]
- **Dock firmware:** CalDigit tells users to check the TS4 firmware version under System Information → Thunderbolt/USB4. [V] https://www.caldigit.com/ts4-macos-firmware-update-procedures/
- **Displays:** System Settings → Displays; hold **Option** to show **Detect Displays**. [V] https://support.apple.com/en-us/102501
- **Gaps:** no history, no alerting, no port-to-physical-socket mapping for non-experts, and SPUSBDataType is gone on Tahoe and later.

### 2.5 BetterDisplay

- Pro is $21.99 / €19.99. The licence is perpetual with at least 1 year of free updates, including major versions released in that year. BetterDisplay 5 is free for Pro purchases made on or after 2025-01-01. Older buyers must buy again. [V] https://github.com/waydabber/BetterDisplay (README and the licence FAQ in discussion #5632)
- Current versions: v5.0.6 for macOS 27/26 and v4.3.7 for Sequoia/Sonoma/Ventura. [V]
- Troubleshooting-relevant features:
  - disconnect and reconnect displays without unplugging them
  - "configuration protection" that preserves layout, resolution, refresh rate and colour profile
  - per-display commands on connect, disconnect, sleep and wake
  - EDID override on Apple Silicon and Intel
  - inspection of connection, bandwidth, compression and tiling, plus EDID, DPCD, DSC, HDMI-CEC and Apple brightness reports
  - CLI [V]
- **Complaints and limits:**
  - Admin rights are needed to create custom resolutions, which blocks it on many corporate Macs. [L] https://www.reddit.com/r/MacOS/comments/1u8o7xu/
  - macOS 26.3 limited it to software XDR upscaling. [L] https://www.reddit.com/r/MacOS/comments/1r3swyz/
  - A GitHub report ties a hang to colorsyncd when virtual screens are in use. [L] https://github.com/waydabber/BetterDisplay/discussions/5357
- **Used as a fix by forum users:** its **"Reinitialize External Displays"** command made a second monitor light up on an M4 Air. [L] https://www.reddit.com/r/CalDigit/comments/1qmnx5e/
- **Gap:** it is a strong toolbox for power users, but it has no event correlation, no A/B protocol and no plain-language verdict.

### 2.6 Lunar

- $23 lifetime licence and a 14-day trial. [V] https://lunar.fyi/
- Its EULA covers 5 personal computers and free updates "indefinitely", but also says a major upgrade may need an extra fee. [V] https://lunar.fyi/eula
- The FAQ documents a set of DDC failure modes:
  - Hubs often block DDC, or forward it to only one monitor.
  - DisplayLink does not provide DDC on macOS.
  - The HDMI port on M1-era Macs blocks DDC; a Thunderbolt port fixes it.
  - Controls lock after wake when the DDC port disappears from the IORegistry. [V] https://lunar.fyi/faq
- **Gap:** it offers nothing for connection faults.

### 2.7 DisplayBuddy and MonitorControl

- **DisplayBuddy:** $24.99 for 1 Mac, $29.99 for 2, $49.99 for 5. One-time, lifetime updates, 7-day money-back guarantee. Separate user accounts need separate licences. [V] https://displaybuddy.app/pricing
- **MonitorControl:** free and MIT. Its README states that:
  - DDC is not supported over the built-in HDMI port of M1 Macs, the entry-level M2 Mac mini, or the 2018 Intel mini
  - DisplayLink allows only software dimming [V] https://github.com/MonitorControl/MonitorControl
- Neither app diagnoses anything.

### 2.8 Dock-vendor utilities

- **CalDigit**
  - The Docking Station Utility ejects USB and TB drives, individually or all at once, on every current CalDigit dock except the TB3 Mini Dock. The February 2025 update added the Element 5 Hub. [V] https://www.caldigit.com/caldigit-docking-station-utility-update/
  - Firmware ships as a macOS package (`CalDigit_Thunderbolt_Firmware_Updater_v2.9.pkg`). macOS then flashes the dock itself after an "Options → Update" prompt. The latest TS4 firmware is **45.1** (updated 2026-01-27).
  - The procedure asks users to temporarily set **Privacy & Security → Accessories → "Ask for new accessories"**. [V] https://www.caldigit.com/ts4-macos-firmware-update-procedures/
  - A CalDigit rep on Reddit (January 2026) said they were tracking **new Tahoe bugs**, and recommended:
    - power-cycling the dock (30–45 s off wall power)
    - trying another Thunderbolt cable
    - trying another host port [V] https://www.reddit.com/r/CalDigit/comments/1qmnx5e/
- **OWC Dock Ejector 2.1:** free; works with any dock or hub; SoftRAID/Apple RAID aware; remounts volumes; enables high-power TB ports without Recovery Mode or Reduced Security. Not compatible with the OWC TB3 Pro Dock. [V] https://www.owc.com/solutions/dock-ejector
- **Anker Dock Manager:** free; macOS 10.14+; firmware OTA, charging info, HDMI/DP details, network status and support links. It supports the Prime Charging dock ($269.99), Prime TB5 ($399.99) and Prime DL7400 DisplayLink ($299.99). [V] https://www.anker.com/dockmanager-download
- **Belkin Dock Utility:** free; MAC pass-through and reset, Wi-Fi auto-switch and "device connection monitoring". It is aimed at IT and BYOD. [V] https://www.belkin.com/business/belkin-dock-utility/
- **Plugable**
  - It has no Mac diagnostic app. PlugDebug collects logs for support. [L]
  - Its KB articles are useful decision trees (see §3). [V]

### 2.9 Drive health

- **DriveDx**
  - Personal licence is $19.99 on sale from $24.99, for 3 computers, non-commercial.
  - Only the Consultant licence ($49.99+) may be used on drives owned by third parties. [V] https://binaryfruit.com/store
  - External SMART needs the **SAT SMART Driver kext**. Some enclosures do not support SCSI/ATA Translation at all. [V] https://binaryfruit.com/drivedx/usb-drive-support
  - A MacRumors user (September 2025) found DriveDx and Disk Drill giving **contradictory verdicts** on the same drives. [V] https://forums.macrumors.com/threads/best-drive-monitoring-software-for-macos-drivedx-drive-scope-smart-utility-or-external-usb-drives.2464787/
- **Disk Drill**
  - SMART monitoring is free and uses smartmontools. It is off by default and covers only the internal disk out of the box.
  - For external drives on Apple Silicon, users must boot into Recovery, set **Reduced Security**, and install SAT SMART Driver.
  - CleverFiles itself says the driver is "not recommended" since Big Sur, and warns it can cause kernel panics with failing disks. [V] https://www.cleverfiles.com/help/monitor-smart-status-disk-health/
  - PRO is $89/yr or $149 lifetime. [V] https://www.cleverfiles.com/help/what-are-the-differences-between-disk-drill-basic-pro-expert-and-enterprise/
- **Implication:** do **not** build SMART reading into the product. A kext and Reduced Security are unacceptable for non-technical users. Report the eject pattern instead (see §4).

### 2.10 Eject-on-sleep utilities

- **Jettison:** $6.95, 15-day trial, v1.9.7 on macOS 10.13 to 27. When an eject fails, it tells you which processes block it. [V] https://www.stclairsoft.com/Jettison/
- **Ejectify 2.1:** €6.99, open source, and not on the App Store because of sandbox limits on disk mount/unmount and its privileged helper. [V] https://ejectify.app/
  - Features: per-volume rules; triggers on sleep, display-off, lock or screensaver; force unmount; "force mute notifications" (an undocumented macOS setting); a diagnostics report.
  - Its log command: `log stream --style compact --info --predicate 'subsystem == "nl.nielsmouthaan.Ejectify" OR subsystem == "nl.nielsmouthaan.Ejectify.PrivilegedHelper"'`
  - It surfaces DiskArbitration errors such as `kDAReturnBusy`, `kDAReturnNotPermitted`, `kDAReturnNotPrivileged` and `kDAReturnNotFound`. [V]
  - A user complaint: Ejectify gives no failure notice when an eject fails. [V] https://www.reddit.com/r/macapps/comments/1toppzg/

### 2.11 DisplayLink (infrastructure, not a competitor)

- **DisplayLink Manager 16.2** (July 2026) added **beta support for macOS 27**. [V] https://www.displaylink.org/forum/showthread.php?t=69938
- Plugable's KB lists the usual failure causes:
  - the Manager app is not running after an update or reboot
  - "Screen & System Audio Recording" permission is missing
  - the accessory was not allowed to connect
  - on macOS 15+, streaming stops when disk space falls below a threshold [V] https://kb.plugable.com/docking-stations-and-video/why-did-my-displays-stop-working-after-my-mac-updated-or-rebooted
- DisplayLink does not support HDCP on macOS. [L] https://www.displaylink.org/forum/showthread.php?p=96264
- **All of these are machine-checkable.** That makes them cheap wins for a diagnostic tool.

---

## 3. What users complained about in 2025–2026, and what actually fixed it

Ranked by visible engagement.

### #1. External display not detected / black after a macOS 26 (Tahoe) update, or after wake
- **Evidence:**
  - Apple Community thread 256135940: M4 MBP, USB-C, macOS 26.0. **279 "Me Too".** [V] https://discussions.apple.com/thread/256135940
  - Thread 256306559: displays not detected after **26.5 / 26.5.1 / 26.5.2**, M4 Max and M5 Max, docks, DisplayLink hubs and native ports. **64+ "Me Too".** [V] https://discussions.apple.com/thread/256306559
  - Also 256145576 (HDMI after the Tahoe update) and 256317969 (MBA M2 after 26.5.1).
- **What worked, per repliers:**
  - Delete the WindowServer display prefs and restart. This was the most-cited fix: `rm -f ~/Library/Preferences/ByHost/com.apple.windowserver.displays*.plist` and `sudo rm -f /Library/Preferences/com.apple.windowserver*.plist`.
  - Switch to a proper **Thunderbolt 4 cable**.
  - Toggle the monitor's HDMI mode (2.x to 1.4 and back).
  - Reboot the dock.
  - Option-click **Detect Displays** repeatedly, then replug.
  - Use a certified Premium/Ultra High Speed HDMI cable.
  - Some users found no fix at all. [V, as summarised from the threads]
- **Apple's official checklist:**
  - Connect the display directly, not through a hub or dock.
  - Sleep/wake the Mac, or close the lid for a few seconds.
  - Option → Detect Displays.
  - Allow the accessory to connect.
  - Check the Mac model's display-count and resolution limits.
  - Update the display firmware. [V] https://support.apple.com/en-us/102501

### #2. External drives ejecting while the Mac sleeps ("Disk Not Ejected Properly")
- **Evidence:**
  - Apple Community 255879325: Mac mini M4, OWC Express 1M2 connected directly over TB4. **28 "Me Too"**, 31 replies. [V] https://discussions.apple.com/thread/255879325
  - SoftRAID forum thread: 23 posts, **4,277 views**. SoftRAID support blames a macOS "Energy Star" sleep bug: sleeping Macs power disks up for about 5 minutes roughly every 45 minutes. Their only workarounds are to unmount drives at night or disable sleep. [V] https://forums.softraid.com/softraid-8-known-issues/softraid-constantly-ejecting-drive-when-mac-goes-to-sleep/
  - AppleInsider "Help us figure out macOS Tahoe external drive mounting issues" (Feb–Jun 2026): drives fail to mount or run at a few MB/s on 26.3; unmounts continue on 26.3.1, 26.4, 26.4.1 and 26.5.
  - Apple's 26.4 beta release notes listed **HFS external media might fail to mount automatically**, with the workaround of mounting via `diskutil`. [V] https://forums.appleinsider.com/discussion/243469/help-us-figure-out-macos-tahoe-external-drive-mounting-issues
- **What worked:**
  1. **Disable sleep, or disable disk sleep.**
     - OWC says turning sleep settings to Never solves it "for the majority of users". [V]
     - Apple's path is Battery → Options → "Put hard disks to sleep when possible", or Energy on desktops. [V] https://support.apple.com/guide/mac-help/change-battery-settings-mchlfc3b7879/mac
     - CLI: `sudo pmset -a disksleep 0`. [L]
     - One Reddit user could not find the checkbox on Sequoia 15.7.3. [V] https://www.reddit.com/r/MacOS/comments/1pw1msz/
  2. **Eject before sleep** with Jettison or Ejectify. This helped in some cases but not all. [V]
  3. **Find the device that wakes the Mac.** One user's repeated sleep/wake cycles came from the **USB cable of an Eaton UPS**; switching to an APC unit stopped the notifications. [V] (thread 255879325)
  4. **Topology swap, in both directions.**
     - OWC: bypass the Thunderbolt dock and connect directly "for a few days", and move cables one port at a time. On Apple Silicon each TB port is its own bus.
     - Counter-example: one AppleInsider staffer's Terramaster DAS dismounted when connected directly but was stable through a Thunderbolt dock. [V]
  5. **What did not help:** in the Apple thread, another enclosure and an uncertified cable. [V]
- **Vendor estimate:** OWC puts it at about **1 in 100 users**, at a frequency between once every 6 hours and once a year. OWC also notes that the system log shows PCI configuration changes a second or two before the disks disappear. [V] https://software.owc.com/knowledge-base/disks-ejecting-while-in-use/

### #3. Dock loses USB, storage or Ethernet after wake (display often survives)
- **Evidence:**
  - CalDigit TS4 on Tahoe 26.2: storage and audio interface lost after wake; replugging did not help; a Mac restart did. Several confirmations.
  - Belkin INC013 plus a Realtek Ethernet adapter drops after 4–6 hours asleep. [V] https://www.reddit.com/r/UsbCHardware/comments/1uw7925/
  - Acasis TB dock not recognised at all after the macOS 27 update. [V] https://www.reddit.com/r/Thunderbolt/comments/1wgn91b/
- **What worked:**
  - **Power-cycle the dock** for 30–45 s (CalDigit).
  - **Toggle the accessory security setting:** set "Ask for new accessories", restart, approve the dock, then set "Always allow". One TS5 Plus user reported this worked until the next update.
  - **Reinstall CalDigit's firmware/drivers.**
  - **A later Tahoe point release fixed it** for the original poster. [V] https://www.reddit.com/r/CalDigit/comments/1qmnx5e/
  - **Plugable's reset sequence:** unplug the dock and its power; shut down the Mac; wait 60–90 s; boot; wait 30–60 s after login; connect dock power first, then the cable. This applies to specific Plugable models (original UD-ULTCDL / UD-ULTC4K and UD-3900PDZ), and Plugable says it still gets occasional reports as of macOS 26.3. [V] https://kb.plugable.com/usb-c-docks/my-ud-ultc4k-is-not-detected-when-i-restart-my-m1-mac-computer
  - **Accessory security has timing rules.** A Mac locked for **3 or more days** may need unlocking before a previously allowed accessory works again. With the lid closed, the display, mouse and keyboard must be approved first. [V] https://support.apple.com/en-us/102282

### #4. Mac appears dead after sleep: monitors show "No Signal", keyboard does nothing
- **Evidence:**
  - Mac mini M4, dual monitors, started after **Tahoe 26.6**, needs a forced restart (MacRumors, 2026-07-31). [V] https://forums.macrumors.com/threads/mac-mini-m4-coming-out-of-sleep-problem.2486246/
  - MBA M4 in clamshell mode through an HDMI hub: "No Signal" until the hub is replugged. The reply suggested a Thunderbolt dock and waking from an external keyboard. [V] https://www.reddit.com/r/macbookair/comments/1qzvp7b/
- **Fix pattern:** mostly unresolved. People move to a TB dock or a direct connection, or run BetterDisplay's reinitialise command.

### #5. macOS 27 (Golden Gate) regressions, first two weeks
- **Evidence:** video playback stalls or crashes when **audio is routed to an HDMI/DP monitor**. Reported on M2 mini, M4 MBP and "MacBook Neo".
- **Workarounds:**
  - Disable HDR, play once, then re-enable it.
  - Match refresh rates across displays (for example 75 Hz to 60 Hz).
  - Set the output to 2 ch 16-bit in Audio MIDI Setup.
  - Route audio to the built-in output.
  - (Source: https://www.reddit.com/r/MacOS/comments/1whcjgf/)
- macOS 27 also added native ultrawide support up to 5K/120 Hz and HDR in the UI. [V, from the Ars Technica review text] https://arstechnica.com/gadgets/2026/09/macos-27-golden-gate-the-ars-technica-review/

### #6. Misunderstood multi-display limits (DisplayLink vs DP Alt Mode vs Thunderbolt, MST)
- **MST:**
  - macOS does not support MST for extended displays; MST outputs mirror. [V] https://kb.plugable.com/understanding-mst-multi-display-setups-with-windows-macos-and-displayport
  - CalDigit said the same about its TS3 docks. [V] https://www.caldigit.com/can-ts3-and-ts3-plus-support-displayport-multi-stream-transport-mst-feature/
  - A practitioner write-up describes a Dell WD19TB where the third display only mirrors. [V] https://dev.to/oculus42/mac-headaches-external-monitors-1ni7
- **Per-chip limits (Apple):**
  - MBA M4/M5: up to 2 external displays; closing the lid does not add more.
  - M3 MBP and MBA: 2 external displays with the lid closed.
  - M4/M5 Max: up to 4.
  - A hub or daisy chain can carry 2 displays over one TB port but **does not raise** the maximum. [V] https://support.apple.com/en-us/122212 , https://support.apple.com/en-us/101571
- **DisplayLink:** a software path. It needs DisplayLink Manager running and the recording permission, and has no HDCP or DDC (see §2.11).

**Takeaway for product design:** every "fix that worked" above is a variable to isolate, and each can be tested in a sequence:
- topology (direct or docked)
- physical port or bus
- cable
- dock power state and firmware
- sleep and disk-sleep settings
- accessory-security state
- display prefs cache
- refresh-rate or HDR mismatch
- DisplayLink app and permission state
- the macOS point release
- a device that triggers wakes (such as a UPS)

---

## 4. What a "Dock & Display Doctor" must do that none of them do

### 4.1 Differentiators (the gap)

1. **One cross-layer timeline**, not just a port log. Correlate, with millisecond timestamps:
   - system sleep and wake
   - display add/remove and mode changes
   - USB and TB device attach/detach
   - volume disappear and unmount
   - network path changes
   - power-source changes

   WhatPort records only port connection and power events. System Information records nothing.
2. **A guided A/B protocol with a scored verdict.** A wizard walks the user through arms and runs the reproduction for each one. Typical arms: direct vs dock; port A vs port B, where each Apple Silicon TB port is its own bus per OWC; cable 1 vs cable 2; sleep allowed vs sleep blocked; dock power-cycled vs not; accessory setting changed vs not.
   - Reproduction is N forced or natural sleep/wake cycles, or a timed soak.
   - For each arm it counts failures and compares arms, for example with Fisher's exact test on failure counts.
   - It prints a verdict with a confidence level and the evidence behind it. Example: "Failures followed the dock: 5 of 6 sleeps through the dock failed, 0 of 6 when connected directly. Likely dock or dock firmware. Next: update TS4 firmware to 45.1, or contact vendor." Nobody ships this.
3. **Preflight "impossible configuration" checks**, which catch problems before any testing:
   - display count and resolution vs Apple's per-chip table (§3 #6)
   - an MST dock on a Mac, detected as mirrored outputs or the same display ID
   - a DisplayLink display with the Manager not running or without the Screen & System Audio Recording permission
   - "Allow accessories to connect" set to *Always ask*, or a blocked connection (WhatPort already flags this)
   - a USB 2.0-only cable on a dock that expects USB3/TB
   - a known-bad macOS point release, such as 26.4 beta HFS auto-mount or 27.0 HDMI audio
4. **A known-issue knowledge base** keyed on macOS build × Mac chip × dock/controller (vendor/product ID, firmware version from System Information) × display transport. It ships as a signed JSON file that updates without an app release.
5. **Safe remediations with one click and undo**, each explained:
   - back up and reset the WindowServer display prefs
   - generate the exact `pmset` command for the user to paste, since it needs admin
   - an auto-eject rule for volumes shown to be implicated (eject before sleep, like Ejectify, but scoped by evidence)
   - a dock power-cycle prompt with a timer
   - links to the vendor firmware for the detected dock
6. **A vendor or Apple support packet:** one PDF/HTML with the Mac, OS build, dock model and firmware, cable identity, timeline excerpt, test arms and results. CalDigit asks for exactly this (product, serial, OS, steps already tried).
7. **Language for non-technical users.** Every competitor except WhatCable and USB Connection Information assumes expert users. The verdict must be one sentence, with "why we think so" underneath.

### 4.2 MVP scope (built in the ponytail way: the smallest thing that gives a verdict)

- **Keep:**
  - the event recorder (§5.1 APIs)
  - a 3-arm wizard: direct vs docked, port swap, sleep blocked
  - Fisher-exact scoring
  - 10–15 preflight rules
  - an HTML report export
- **Skip for v1:**
  - SMART (needs a kext)
  - EDID/DPCD parsing (BetterDisplay already does it)
  - cable e-marker decoding (WhatCable already does it; link to it)
  - remote agents
  - Intel support. macOS 27 is Apple-silicon-only [V] https://www.scoringnotes.com/news/music-notation-software-and-macos-27-golden-gate/ , and Intel Macs lack the Type-C PHY services [V]. **Add Intel in reduced mode only if customers ask.**

---

## 5. Implementation notes for the Swift/SwiftUI build

### 5.1 APIs (checked against Apple's developer documentation JSON unless marked)

| Need | API | Notes |
|---|---|---|
| Sleep/wake with timing | `IORegisterForSystemPower` → `kIOMessageSystemWillSleep` (must ack with `IOAllowPowerChange`), `kIOMessageSystemWillPowerOn`, `kIOMessageSystemHasPoweredOn` (arrives 1–5+ s after wake) | [V] https://developer.apple.com/documentation/iokit/1557114-ioregisterforsystempower |
| Simple sleep/wake | `NSWorkspace.didWakeNotification`, `NSWorkspace.screensDidWakeNotification` (and the `willSleep` / `screensDidSleep` counterparts) | [V] didWake and screensDidWake. The counterparts are [L] |
| Display add/remove/mode | `CGDisplayRegisterReconfigurationCallback(_:_:)` with `CGDisplayChangeSummaryFlags` `.addFlag`, `.removeFlag`, `.setModeFlag`, `.enabledFlag`, `.disabledFlag`, `.mirrorFlag`, `.unMirrorFlag`, `.movedFlag`, `.setMainFlag`, `.desktopShapeChangedFlag`, `.beginConfigurationFlag` | [V] The callback fires before and after each reconfiguration |
| Volume vanish | `DARegisterDiskDisappearedCallback(_:_:_:_:)` (DiskArbitration); `NSWorkspace.didUnmountNotification` | [V] A disappear without a preceding unmount is "not ejected properly" |
| USB device attach/detach | `IOServiceAddMatchingNotification` on `IOUSBHostDevice` with `kIOFirstMatchNotification` / `kIOTerminatedNotification` | [V] for the class and constant; the function is standard IOKit [L] |
| Port-level USB-C/TB state | IORegistry classes `AppleTypeCPhy`, `IOThunderboltPort`, `AppleHPMInterfaceType10/11/12`, `AppleTCControllerType10/11`, `IOPortFeaturePowerSource`, `IOPortTransportComponentCCUSBPDSOP*`, `IOPortTransportStateCC` | [V] as named by WhatPort and WhatCable. Property keys are not documented by Apple [U]; learn them from the MIT-licensed sources |
| Network drop (dock Ethernet) | `NWPathMonitor` | [V] |
| Sleep-blocked test arm | `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventSystemSleep` | [V] for the function; the constant is [L] |
| Retroactive system log | `OSLogStore.local()` | [V] It **requires an admin account and the `com.apple.logging.local-store` entitlement**, so do not rely on it. The recorder must already be running when the fault happens. As a fallback, give the user a `log show --last 24h --predicate ...` command to run [U: exact predicates need testing] |
| Background launch | `SMAppService` (login item) | [V] |

### 5.2 CLI evidence to collect (run by the app or pasted by the user)

- `system_profiler SPThunderboltDataType SPDisplaysDataType SPUSBHostDataType -json`. `SPUSBDataType` no longer exists on 26+. [V, per the Apple Community thread]
- `pmset -g log` for sleep/wake/DarkWake history and wake reasons. It has been seen used without sudo. [L]
- `pmset -g assertions` [L]
- `ioreg -a -l -w0` (XML) for fixture capture [L]
- `diskutil list -plist`; `diskutil mount <id>` for the 26.4 HFS workaround [V for the workaround]

### 5.3 Distribution and platform constraints

- **App Store vs direct sale:**
  - Ejectify is sold directly because the sandbox restricts disk mount/unmount and privileged helpers. [V]
  - WhatPort is sold directly (Stripe, 2 activations). [V]
  - USB Connection Information is in the App Store, so read-only IORegistry work fits inside the sandbox. [L]
  - **Recommendation:** ship directly first (Developer ID + notarization + a merchant of record), keeping the option of a sandboxed "lite" app on the App Store later.
- **Windows-only development with GitHub Actions:**
  - CI runners can build, sign and notarize. They **cannot** simulate Thunderbolt or DisplayPort hotplug.
  - Structure the code as a pure-Swift core that takes snapshots and events and returns a verdict, plus a thin IOKit adapter, so the core runs under `swift test` on CI against fixtures.
  - Collect fixtures with a `--report` flow, as WhatCable does.
  - **You still need physical hardware:** at minimum one Apple Silicon MacBook, one TB4 dock and one USB-C DP-Alt hub, or paid beta testers. [L, engineering judgement]

---

## 6. Positioning and pricing (for a one-time lifetime licence)

- **Price ladder observed for one-time licences:**
  - $5.99 Display Connection Info
  - €6.99 Ejectify / $6.95 Jettison
  - £9.99 WhatPort Pro / $9.99 WhatCable Pro / $9.99 USB Connection Info
  - $19.99–24.99 DriveDx, $21.99 BetterDisplay, $23 Lunar, $24.99 DisplayBuddy
- **Diagnosis is worth more than information.** The alternatives are hours of forum trial and error, or buying a new dock (Anker Prime TB5 $399.99). A **$19–29 one-time** price fits between the information apps and the display-control apps.
- **Honesty is a selling point.** WhatPort's disclaimer about causation is exactly the promise our product makes. Market the product as "the missing step after WhatPort": it records the events and also tells you which part to replace.

---

## 7. Risks

- **WhatPort/WhatCable could add a wizard.** Same developer, strong press momentum, and the Flight Recorder already exists.
- **Many root causes are macOS bugs** (Tahoe 26.2–26.6, macOS 27.0). A verdict of "it's macOS, here is the workaround" must be a first-class outcome, not a failure.
- **Tests take time.** Intermittent faults need days of soak. The UX must support multi-day arms, as OWC says: "for a few days".
- **Private IORegistry keys can change between macOS releases.** Mitigate with the updatable rules JSON and fixture tests.

---

## 8. Things I could not verify

- Whether WhatPort's Flight Recorder also logs system sleep/wake or display reconfiguration internally (not advertised).
- Porta's price and launch date.
- The exact IORegistry property key WhatPort reads for "macOS has blocked a connection".
- Whether `pmset -g log` and `log show` need admin on macOS 27.
- Whether "Put hard disks to sleep when possible" is still visible in the UI on macOS 27.
- The DriveDx licence type (one-time vs subscription).
- Whether any closed-source or enterprise tool offers guided A/B dock diagnosis. None was found; the searches were Firecrawl/TinyFish/WebSearch queries for "guided troubleshooting dock monitor root cause Mac app".
- JSON key names in `SPThunderboltDataType` (from secondary sources only).

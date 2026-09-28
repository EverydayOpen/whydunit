# Technical feasibility: will a workflow survive a macOS upgrade, plus an optional VM test-drive

Topic: tech-upgrade. Research date: 2026-09-27. Target app: native Swift/SwiftUI, macOS 14–27, built on GitHub Actions (the developer has no local Mac).

Confidence labels used below:
- **[V] verified**: checked against a primary source during this research (Apple docs JSON, Apple OSS headers, Apple SLA PDF, vendor or GitHub source, HTTP HEAD).
- **[L] likely**: comes from a reputable secondary source, or several sources agree.
- **[U] unverified**: I could not confirm it. Do not rely on it without testing.

Quotations are kept to a minimum. Everything else is paraphrased, and the URL is given so you can read the exact wording.

---

## 0. Bottom line

1. **The upgrade cliff is macOS 28, not macOS 27.** macOS 27 still ships full Rosetta. From macOS 28 on, only a subset for older games remains (section 1). An "Intel-only binary" scan therefore does not predict what breaks going 26 to 27. It is a **macOS 28 readiness** report, and its selling window runs from now to fall 2027, peaking when the macOS 28 beta ships at WWDC 2027. Breakage on the 26 to 27 step has to come from *compatibility data* (Apple's on-device IncompatibleAppsList, vendor pages, crowd data), not from the Mach-O architecture.
2. **The scanner is cheap and low-risk.** It is pure file reading plus a few CLIs. Estimate: about 6–9 weeks for one developer to reach a sellable MVP, plus 30–50% because there is no Mac to test on.
3. **The scanner is already partly a commodity.** The RoaringApps Mac app is free, scans installed apps and says it supports macOS 27. Rosetta Check is a free Mac App Store app that tracks about 30.5k Intel-only apps. To stand apart, cover the places those tools skip (plug-ins, audio/HAL drivers, printer drivers, kexts, system extensions, launchd items, CLI tools), show what is running under Rosetta right now, and turn the results into a guided per-workflow checklist.
4. **The VM test-drive works technically but is heavily limited.**
   - The great majority of Mac App Store apps do not run in macOS VMs.
   - Apple's SLA only permits VM use for development, testing during development, macOS Server, or personal non-commercial use.
   - A macOS 27 IPSW is 26.6 GB, and a comfortable VM needs about 8–16 GB of RAM.
   - The macOS 27 guest-provisioning and USB-passthrough APIs need a macOS 27 host.
   - Nothing VM-related can run in GitHub Actions, because nested virtualization is unsupported.

   Effort: +6–10 weeks, and a physical Apple silicon Mac is required. **Recommendation:** ship the scanner and checklist first. Make the VM a later module, or first a guided hand-off to free tools (UTM / VirtualBuddy).

---

## 1. Apple's official Rosetta phase-out [V]

- **Apple Developer documentation**, "About the Rosetta translation environment": https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment (verified via the docs JSON at https://developer.apple.com/tutorials/data/documentation/apple-silicon/about-the-rosetta-translation-environment.json). Apple says Rosetta "will be available through macOS 27 — as a general-purpose tool for Intel apps". After that, Apple will keep a subset of Rosetta aimed at older, unmaintained games that rely on Intel-based frameworks.
- **Apple Support** "If you need to install Rosetta on your Mac": https://support.apple.com/en-us/102527. Rosetta is available on Apple silicon Macs running macOS 27 or earlier. Starting with macOS 28, it will be available only for certain older, unmaintained games that rely on Intel-based frameworks. To install: `softwareupdate --install-rosetta`. The man page also documents `[--agree-to-license]` for unattended installs [V: https://keith.github.io/xcode-man-pages/softwareupdate.8.html].
- **Announced at WWDC 2025** (Platforms State of the Union) [L: https://www.macrumors.com/2025/06/10/apple-to-phase-out-rosetta-2/, https://appleinsider.com/articles/25/06/10/macos-27-will-be-the-last-operating-system-to-fully-support-rosetta-2].
- **What Rosetta never translates** (same Apple doc) [V]:
  - kernel extensions;
  - VM apps that virtualize x86_64 platforms;
  - AVX512 instructions (AVX and AVX2 are supported).
- **Reported but not confirmed with Apple:** macOS 26.4/26.5 show Rosetta sunset alerts, and macOS 27 Golden Gate removes a previously installed Rosetta, so users must reinstall it [L: https://www.macrumors.com/2026/06/10/macos-golden-gate-last-to-support-intel-apps/]. macOS 27 was released 2026-09-14 [L: Wikipedia].
- **Checking whether your own process is translated:** `sysctlbyname("sysctl.proc_translated", ...)` returns 1 if translated, 0 if native. ENOENT means native [V: same Apple doc].

---

## 2. Detecting Intel-only (x86_64-only) code

### 2.1 Constants (from Apple's open-source headers) [V]

Sources:
- https://github.com/apple-oss-distributions/cctools/blob/main/include/mach-o/fat.h
- xnu `EXTERNAL_HEADERS/mach-o/loader.h`
- xnu `osfmk/mach/machine.h`

| Name | Value | Note |
|---|---|---|
| `FAT_MAGIC` / `FAT_CIGAM` | `0xcafebabe` / `0xbebafeca` | Fat headers are **always big-endian on disk** (fat.h comment). |
| `FAT_MAGIC_64` / `FAT_CIGAM_64` | `0xcafebabf` / `0xbfbafeca` | `struct fat_arch_64` = cputype, cpusubtype (int32), offset, size (uint64), align, reserved (uint32). That is 32 bytes. `struct fat_arch` is 20 bytes. |
| `MH_MAGIC` / `MH_CIGAM` | `0xfeedface` / `0xcefaedfe` | 32-bit thin binary |
| `MH_MAGIC_64` / `MH_CIGAM_64` | `0xfeedfacf` / `0xcffaedfe` | 64-bit thin binary. On-disk bytes for arm64/x86_64 are `cf fa ed fe`. |
| `CPU_ARCH_ABI64` | `0x01000000` | |
| `CPU_TYPE_X86` (= `CPU_TYPE_I386`) | `7` | |
| `CPU_TYPE_X86_64` | `7 \| 0x01000000` = `0x01000007` | |
| `CPU_TYPE_ARM64` | `12 \| 0x01000000` = `0x0100000c` | arm64e is the same cputype with `CPU_SUBTYPE_ARM64E` = 2 |
| `CPU_TYPE_POWERPC` | `18` | |
| `MH_EXECUTE` / `MH_DYLIB` / `MH_BUNDLE` / `MH_KEXT_BUNDLE` | `0x2` / `0x6` / `0x8` / `0xb` | |
| `LC_BUILD_VERSION` / `LC_VERSION_MIN_MACOSX` | `0x32` / `0x24` | Minimum OS the binary was built for |

**Gotcha:** Java `.class` files also start with `0xcafebabe`. Bound `nfat_arch` to a small number (see the code below).

Swift may import these as `MachO` module constants, but that is [U]. Defining the handful of values yourself is simpler and avoids the question.

### 2.2 Lazy path for bundles [V]

- `Bundle(url:)?.executableURL` resolves the bundle's `CFBundleExecutable`.
- `Bundle.executableArchitectures: [NSNumber]?` (macOS 10.5+) scans the Mach-O. It returns nil if the bundle has no Mach-O executable. Compare against `NSBundleExecutableArchitectureX86_64` / `NSBundleExecutableArchitectureARM64`.
- Docs: https://developer.apple.com/documentation/foundation/bundle/executablearchitectures

This covers `.app`, `.component`, `.vst`, `.vst3`, `.clap`, `.aaxplugin`, `.kext`, `.prefPane`, `.plugin`, `.saver`, `.mdimporter` and `.qlgenerator`, because all of them are CFBundles.

You still need a raw parser for loose binaries: launchd `ProgramArguments[0]`, `/usr/local/bin`, and helper tools inside bundles. So use one parser for everything.

### 2.3 Parser (about 35 lines, no dependencies)

```swift
import Foundation

enum Arch: Hashable { case x86_64, arm64, i386, ppc, other(Int32) }

/// Architectures in a Mach-O file (thin or fat). nil = not Mach-O / unreadable.
func machOArchs(at url: URL) -> Set<Arch>? {
    guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? fh.close() }
    guard let h = try? fh.read(upToCount: 4096), h.count >= 8 else { return nil }
    func be32(_ o: Int) -> UInt32 { h[o..<o+4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
    func arch(_ t: UInt32) -> Arch {
        switch Int32(bitPattern: t) {
        case 0x0100_0007: return .x86_64      // CPU_TYPE_X86_64
        case 0x0100_000C: return .arm64       // CPU_TYPE_ARM64 (incl. arm64e)
        case 7:           return .i386
        case 18, 0x0100_0012: return .ppc
        case let v:       return .other(v)
        }
    }
    switch be32(0) {
    case 0xCAFE_BABE, 0xCAFE_BABF:            // FAT_MAGIC / FAT_MAGIC_64, big-endian on disk
        let stride = be32(0) == 0xCAFE_BABF ? 32 : 20
        let n = Int(be32(4))
        // ponytail: n < 20 filters Java .class files (same magic); raise if a real fat file ever has more slices
        guard n > 0, n < 20, 8 + n * stride <= h.count else { return nil }
        return Set((0..<n).map { arch(be32(8 + $0 * stride)) })
    case 0xCFFA_EDFE, 0xCEFA_EDFE:            // MH_MAGIC_64 / MH_MAGIC stored little-endian
        return [arch(be32(4).byteSwapped)]
    case 0xFEED_FACF, 0xFEED_FACE:            // big-endian thin (PowerPC)
        return [arch(be32(4))]
    default:
        return nil
    }
}

func isIntelOnly(_ a: Set<Arch>) -> Bool { !a.contains(.arm64) && (a.contains(.x86_64) || a.contains(.i386)) }
// Usage for a bundle: Bundle(url: u)?.executableURL.flatMap(machOArchs)
```

- **CI check:** in a GitHub Actions macOS job, build fixtures with `clang -arch x86_64 …`, `clang -arch arm64 …` and `lipo -create a b -output fat`. Then assert that the parser output matches `lipo -archs` [V: `lipo -archs` in https://keith.github.io/xcode-man-pages/lipo.1.html].
- **A universal app is not automatically safe.** Also scan `Contents/MacOS/*`, `Contents/Library/LoginItems/*.app`, `Contents/PlugIns/*.appex` and `Contents/Helpers`. A universal host can still ship Intel-only helpers.

### 2.4 CLI cross-checks (for debugging only; shelling out is slower)

- `lipo -archs <file>` and `lipo -info <file>` [V man page]
- `vtool -show-build <file>` shows the `LC_BUILD_VERSION` platform/minos [V: https://keith.github.io/xcode-man-pages/vtool.1.html]
- `system_profiler -json SPApplicationsDataType` gives, per app: `_name`, `path`, `version`, `obtained_from`, `signed_by`, `lastModified`, `arch_kind`.
  - `arch_kind` values: `arch_i64` (Intel), `arch_arm_i64` (Universal), `arch_arm` (Apple Silicon), `arch_ios`, `arch_web`, `arch_other` [L: https://pbs.bartificer.net/tidbit7].
  - Some native Electron apps show as `arch_ios` because of `CFBundleSupportedPlatforms` [L: https://github.com/signalapp/Signal-Desktop/issues/7449].
  - It is slow and apps-only, so don't use it as the main scanner.

### 2.5 "What is running under Rosetta right now" (a strong differentiator)

`sysctl.proc_translated` only reports on the calling process. For all processes, read `kinfo_proc.kp_proc.p_flag` and test `P_TRANSLATED = 0x00020000`. The constant is verified [V: xnu `bsd/sys/proc.h`]. Using it for Rosetta detection is [L]: it has not been run on a machine here.

```swift
import Darwin

func translatedProcesses() -> [(pid: pid_t, path: String)] {
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
    var size = 0
    guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0 else { return [] }
    var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 32)
    size = procs.count * MemoryLayout<kinfo_proc>.stride
    guard sysctl(&mib, u_int(mib.count), &procs, &size, nil, 0) == 0 else { return [] }
    return procs.prefix(size / MemoryLayout<kinfo_proc>.stride)
        .filter { $0.kp_proc.p_flag & 0x0002_0000 != 0 }             // P_TRANSLATED
        .map { p in
            var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))  // PROC_PIDPATHINFO_MAXSIZE
            _ = proc_pidpath(p.kp_proc.p_pid, &buf, UInt32(buf.count))   // may fail for root-owned pids
            return (p.kp_proc.p_pid, String(cString: buf))
        }
}
```

Run this periodically over a week, for example from a login-item agent. It catches Intel helpers and daemons that a static scan misses. This code has not been compiled here, so compile it in CI.

### 2.6 Other Rosetta signals

- **"Open using Rosetta" per-app choice:** stored in `~/Library/Preferences/com.apple.LaunchServices/com.apple.LaunchServices.plist` under the key `Architectures for arm64`, keyed by bundle ID [L: https://git-cola.github.io/share/doc/git-cola/html/git-cola.html]. The format is undocumented. These are universal apps (often DAWs or browsers) that the user forces into Rosetta to load Intel plug-ins. They will break on macOS 28 even though the app itself is "universal".
- **Is Rosetta installed?** No documented API [U]. A common probe is `arch -x86_64 /usr/bin/true` (non-zero exit means no Rosetta) [U].

---

## 3. Where to look: scan catalog

| Category | Paths (system then user) | Bundle / file | Confidence and notes |
|---|---|---|---|
| Apps | `/Applications`, `/Applications/Utilities`, `~/Applications` | `.app` | Also scan nested `Contents/PlugIns/*.appex` (AUv3, FxPlug 4, QuickLook/Spotlight extensions), `Contents/Library/LoginItems/*.app`, `Contents/Library/LaunchAgents`, `Contents/Library/LaunchDaemons` [V: Apple ServiceManagement doc] |
| Audio Units v2 | `/Library/Audio/Plug-Ins/Components`, `~/Library/Audio/Plug-Ins/Components` | `.component` | [L] many vendor docs, e.g. https://support.spitfireaudio.com/en/articles/11815335-where-are-the-au-vst-aax-plugins-on-mac |
| VST2 | `/Library/Audio/Plug-Ins/VST`, `~/Library/Audio/Plug-Ins/VST` | `.vst` | [L] |
| VST3 | `/Library/Audio/Plug-Ins/VST3`, `~/Library/Audio/Plug-Ins/VST3`, `/Network/Library/Audio/Plug-Ins/VST3` | `.vst3` | [V] https://steinbergmedia.github.io/vst3_dev_portal/pages/Technical+Documentation/Locations+Format/Plugin+Locations.html |
| CLAP | `/Library/Audio/Plug-Ins/CLAP`, `~/Library/Audio/Plug-Ins/CLAP`, plus the `CLAP_PATH` env var | `.clap` | [V] https://github.com/free-audio/clap/blob/main/include/clap/entry.h |
| AAX (Pro Tools) | `/Library/Application Support/Avid/Audio/Plug-Ins` | `.aaxplugin` | [L] https://www.sweetwater.com/sweetcare/articles/where-are-my-pro-tools-plugins-stored/ |
| CoreAudio HAL drivers (Loopback, BlackHole, interface drivers) | `/Library/Audio/Plug-Ins/HAL` | `.driver` | [L] seen in Apple Community EtreCheck logs; loaded by `coreaudiod` |
| MIDI drivers | `/Library/Audio/MIDI Drivers` | `.plugin` | [U] |
| Adobe (After Effects / Premiere / AME / Audition) | `/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore` | `.plugin`, `.bundle` | [V] https://ae-plugins.docsforadobe.dev/intro/where-installers-should-put-plug-ins/ ("7.0" is fixed for all CC versions) |
| Adobe CEP panels | `/Library/Application Support/Adobe/CEP/extensions`, `~/Library/Application Support/Adobe/CEP/extensions` | folders (HTML/JS, sometimes native helpers) | [L] |
| Photoshop plug-ins | `/Applications/Adobe Photoshop <year>/Plug-ins` | `.plugin` | [L] |
| Final Cut Pro / Motion | `/Library/Plug-Ins/FxPlug` (legacy FxPlug 3). FxPlug 4 ships as app extensions inside apps. | `.fxplug`, `.appex` | [V] Apple: plug-ins must be FxPlug 4 to work with FCP on Apple silicon (https://support.apple.com/en-us/101831). [L] FCP 10.6.6+/Motion 5.6.4+ dropped FxPlug 3. Motion templates (`~/Movies/Motion Templates.localized`) are architecture-neutral. |
| QuickLook generators | `/Library/QuickLook`, `~/Library/QuickLook` | `.qlgenerator` | [V] already dead since macOS 15.0. Flag as "already broken", not a Rosetta issue (https://mjtsai.com/blog/2024/11/05/sequoia-no-longer-supports-quicklook-generator-plug-ins/) |
| Spotlight importers | `/Library/Spotlight`, `~/Library/Spotlight` | `.mdimporter` | [L] |
| Internet plug-ins | `/Library/Internet Plug-Ins`, `~/Library/Internet Plug-Ins` | `.plugin`, `.webplugin` | [L] legacy. Report as dead weight. |
| Printers and scanners | `/Library/Printers/<Vendor>/…` (filters, PDEs, utilities), PPDs in `/Library/Printers/PPDs/Contents/Resources`; `/Library/Image Capture/Devices`, `/Library/Image Capture/TWAIN Data Sources` | mixed | [L] printers / [U] Image Capture paths. Scan every Mach-O under these folders recursively. |
| Preference panes | `/Library/PreferencePanes`, `~/Library/PreferencePanes` | `.prefPane` | [L] |
| Screen savers | `/Library/Screen Savers`, `~/Library/Screen Savers` | `.saver` | [L] |
| Kernel extensions | `/Library/Extensions` | `.kext` | [V] never translated by Rosetta. Loaded third-party kexts: `kmutil showloaded --collection aux --list-only`. Options `--show loaded\|unloaded\|all`, `--collection boot\|sys\|aux\|codeless`, `--arch-info` [V: https://keith.github.io/xcode-man-pages/kmutil.8.html]. Whether it needs root is [U]; `print-diagnostics` partly needs root. |
| System extensions | Binaries under `/Library/SystemExtensions/` [L] | `.systemextension`, `.dext` | `systemextensionsctl list` [V man page]. Output is grouped by category (e.g. `com.apple.system_extension.network_extension`) with columns `enabled active teamID bundleID (version) name [state]`. States include `[activated enabled]`, `[activated waiting for user]`, `[activated disabled]` [V/L: https://keith.github.io/xcode-man-pages/systemextensionsctl.8.html, https://www.junian.dev/blog/macos-system-extension-management/] |
| Launch agents and daemons | `/Library/LaunchAgents`, `/Library/LaunchDaemons`, `~/Library/LaunchAgents` | `.plist` | Resolve the executable from `Program`, then `ProgramArguments[0]`, then `BundleProgram` (a path relative to the owning app bundle, used by SMAppService) [V: https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos] |
| Login and background items (BTM) | `/private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v*.btm` | binary plist | [V] No public API enumerates other apps' items; `SMAppService` only manages the caller's own bundle (https://developer.apple.com/documentation/servicemanagement/smappservice). `sudo sfltool dumpbtm` needs root [V: https://eclecticlight.co/2023/02/15/controlling-login-and-background-items-in-ventura/]. Reading the `.btm` file needs Full Disk Access. objective-see/DumpBTM parses it but is **GPL-3.0**, so don't link it into a closed-source app [V: https://github.com/objective-see/DumpBTM]. Lazy route: scan launchd folders and in-bundle `Contents/Library/*`, and optionally ask the user to paste `sudo sfltool dumpbtm` output. |
| Command-line tools and dev stacks | `/usr/local/bin`, `/usr/local/Cellar` (Intel Homebrew prefix) vs `/opt/homebrew`; `/Library/Java/JavaVirtualMachines/*` | Mach-O | [L] An Intel Homebrew prefix on an Apple silicon Mac is a strong macOS 28 risk signal. Homebrew moves Intel macOS to Tier 3 in Sep 2026 and removes it in Sep 2027 [V: https://brew.sh/2026/06/11/homebrew-6.0.0/] |

**Permissions (TCC):** reading `/Library/...` and your own `~/Library/Audio` is fine. The BTM database needs Full Disk Access. Running `kmutil` and `systemextensionsctl` or reading the whole disk is not practical from the App Sandbox. So **ship outside the Mac App Store**: Developer ID, hardened runtime, notarized. The Mac App Store competitor (Rosetta Check) is sandboxed, which is your coverage advantage.

---

## 4. Machine-readable compatibility data and reuse licensing

| Source | What it gives | Machine-readable? | Reuse terms | Verdict |
|---|---|---|---|---|
| **RoaringApps** (roaringapps.com) | Crowd-sourced per-app, per-macOS status. Free Mac app v2.x (needs macOS 14.6+) says it supports macOS 27 and can upload your app list. | No public API documented [V: help/terms pages have none] | ToS prohibits reproducing, copying, reselling or otherwise exploiting any part of the service without express written permission [V: https://roaringapps.com/legal/terms] | Needs a **written licence deal**. It is also a free competitor. |
| **Rosetta Check** (rosettacheck.com) | Community DB that reports tracking 30,544 Intel-only apps across 7,136 Macs. Free Mac App Store app. | No API or licence mentioned [V: homepage] | Unknown | Competitor. Not a data source unless you negotiate. |
| **Does It ARM** (github.com/ThatGuySam/doesitarm) | Apple-silicon-native status per app. Not per-macOS-version. | README list in GitHub. The old `/api/app/index.json` URL returns 404 [V]. | List under **CC BY 4.0**, code Apache-2.0 [V: README "License" section]. Repo last pushed 2026-09-07. | Usable with attribution. Limited to native/Rosetta status. |
| **Homebrew casks** (formulae.brew.sh/api/cask.json) | 7,764 casks (fetched 2026-09-27). **772 have `caveats_rosetta: true`**. `depends_on.arch` (e.g. `[{"type":"intel","bits":64}]`), `depends_on.macos` (e.g. `{">=":["12"]}`). `variations` keyed by macOS codename, including `golden_gate` and `arm64_golden_gate`. `artifacts[].app` holds `.app` names for matching installed apps. | Yes, JSON [V] | homebrew-cask repo licence is BSD-2-Clause style [V: LICENSE] | **Best free structured Rosetta signal.** Bundle a nightly-trimmed copy. |
| **Apple IncompatibleAppsList** | Apple's own list of known-incompatible third-party versions. `/Library/Apple/Library/Bundles/IncompatibleAppsList.bundle/.../IncompatibleAppsList.plist`, version 260.200 on Tahoe [V: https://eclecticlight.co/2025/09/19/silently-updated-security-data-files-in-tahoe/]. Structure as of 2019: top key `IncompatiblePaths`, a list of dicts with `Application Name`, `Path`/`Paths`, `MaximumBundleVersion`, `Blurb` [L: https://gist.github.com/stevemoser/a4388df17633beae5bc3fb07d38373e2]. The current schema is [U]. | Yes, plist on every Mac | Apple's data. **Read it locally; don't redistribute.** | To see the *target* OS's list, extract it from the macOS 27 installer or a macOS 27 VM [U: path inside the installer]. |
| **MacUpdater** (CoreCode) | Update and version DB | — | Development ended 2026-01-01. The DB server stays up until 2026-12-31. The technology is offered for sale or licence [L: https://tidbits.com/2026/01/09/macupdater-shuts-down-leaving-users-searching-for-alternatives/, https://www.corecode.io/macupdater/sale-and-licensing.html] | Dead end, unless you buy it. |
| Vendor pages and Apple's FCP plug-in pages | Authoritative per-vendor status | HTML only | Each site's ToS | Curate by hand into your own JSON. This is the ongoing cost. |

**Recommended data strategy:**
1. Local facts first: architecture, plug-in type, kext/system-extension state, the on-device IncompatibleAppsList.
2. Homebrew cask data (BSD).
3. Your own curated `compat.json` (vendor URL plus status) for the top ~300 pro plug-ins and drivers. Update it from a GitHub repo, not by republishing the app.
4. Optional licensing talks with RoaringApps.

---

## 5. VM test-drive with Virtualization.framework (Apple silicon hosts only)

### 5.1 Facts and limits

- **Entitlement:** `com.apple.security.virtualization` (Boolean, macOS 11+) [V: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.virtualization]. The Apple page mentions no special request. Tart's dev script ad-hoc-signs (`codesign --sign -`) with it [V: cirruslabs/tart `scripts/run-signed.sh`, `Resources/tart-dev.entitlements`]. Bridged networking needs `com.apple.vm.networking`; Tart ships an embedded provisioning profile for it, so treat it as restricted [L]. Loading a restore image also requires the virtualization entitlement [V: VZMacOSRestoreImage doc].
- **Two concurrent macOS VMs, at most:**
  - The framework enforces it with `VZError.Code.virtualMachineLimitExceeded` (macOS 12+), which Apple describes as being unable to create an additional VM [V].
  - Apple's SLA §2B(iii) allows up to two additional copies or instances in virtual OS environments on each Apple-branded computer already running the software, only for (a) software development, (b) testing during software development, (c) macOS Server, or (d) personal, non-commercial use [V: https://www.apple.com/legal/sla/docs/macOSTahoe.pdf, text extracted from the PDF].
  - **Legal risk:** a business user test-driving their paid workflow may not fit (a)–(d). Put this in your terms, and position the feature as "personal / pre-upgrade testing". The macOS 27 SLA text itself is [U]; the Tahoe SLA is quoted here.
- **Host/guest versions:**
  - An Apple engineer said a macOS 27 guest should run on a macOS 26.6 host. There was a late `VZMacOSInstaller`-versus-macOS-27-IPSW bug. DTS said macOS **26.6b3 (25G5052e)** contains the OS-level fix (r. 179068335), and an Xcode-side mitigation was pending [V: https://developer.apple.com/forums/thread/830118].
  - On older 26.x hosts the install fails at about 77–78%, with the restore failing with result 11 in the logs [V: https://github.com/utmapp/UTM/issues/7746].
  - Workarounds: build the VM on a 27 host and copy it back, or install 26.x and upgrade inside the guest [V: https://osxdaily.com/2026/06/12/macos-golden-gate-27-beta-wont-install-in-a-virtual-machine-its-a-known-issue/, https://motionbug.com/virtualising-macos-27/].
  - Earlier precedent: a Sequoia 15.5 host ran a Tahoe guest only after installing Apple's "Device Support" / Xcode beta enabler [V: https://eclecticlight.co/2025/06/11/virtualising-macos-26-tahoe/].
  - Whether a 26.6.x host needs any extra component for the 27.0 release IPSW is **[U]**, and so is whether `VZMacOSRestoreImage.latestSupported` on a 26.x host returns 27.0. Handle both with explicit UI: "Your Mac must run macOS 26.6 or later". Use `restoreImage.isSupported` and `mostFeaturefulSupportedConfiguration != nil` as the gate.
- **M4 Macs** cannot virtualise macOS older than 13.4 [V: https://eclecticlight.co/2024/11/14/m4-macs-cant-virtualise-older-macos/]. This doesn't matter for forward testing.
- **App Store apps: the biggest product limit.**
  - Oakley (Tahoe, 2025): a VM still won't run the great majority of App Store apps [V].
  - Parallels KB: even on 15+, signing into the Mac App Store inside a VM is not supported [V: https://kb.parallels.com/en/131160].
  - Nothing was announced for macOS 27 [V: https://eclecticlight.co/2026/06/12/macos-virtualisation-is-leaping-forward-in-golden-gate/].
  - So Final Cut Pro, Logic and most App Store utilities **cannot be test-driven**. Licence dongles (iLok) and activation-limited apps are further practical blockers [L].
- **iCloud / Apple Account:** works only when host and guest run macOS 15+ and the VM was created from a 15+ IPSW, with `VZMacHardwareModel` taken from `VZMacOSRestoreImage`. The identity is derived from the host's Secure Enclave. Moving or cloning the VM forces re-authentication. Upgrading an older VM with a 15 installer does not enable iCloud [V: https://developer.apple.com/documentation/virtualization/using-icloud-with-macos-virtual-machines].
- **Shared folders:** `VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)` (class var, macOS 13+). Guests on macOS 13+ auto-mount it at `/Volumes/My Shared Files` [V]. Share with `VZSingleDirectoryShare(directory: VZSharedDirectory(url:readOnly:))`, or `VZMultipleDirectoryShare`, via `VZVirtualMachineConfiguration.directorySharingDevices` [V]. **There is no `VZMacOSAutomountDirectoryShare` class**; the docs URL returns 404 [V].
- **New in macOS 27 (host macOS 27 required)** [V: WWDC26 session 224 https://developer.apple.com/videos/play/wwdc2026/224/, docs JSON]:
  - `VZMacGuestProvisioningOptions` (`fullName`, `username`, `password`, `logsInAutomatically`, `enablesRemoteLogin`), passed with `VZMacOSVirtualMachineStartOptions.setGuestProvisioning(_:)`. Only takes effect on first boot, and the guest must be macOS 27. This removes the Setup Assistant step, which helps non-technical users a lot.
  - USB passthrough: `VZUSBPassthroughDeviceConfiguration(device: AAUSBAccessory)` via the AccessoryAccess framework (`AAUSBAccessoryManager`). Needs the Xcode capability "Claim USB Accessory". Oakley says host and guest must both be 27.
  - DiskImageKit `DiskImage` layers (base, cache, overlay; ASIF is sparse), attached with `VZDiskImageStorageDeviceAttachment(diskImage:cachingMode:synchronizationMode:)`. Good for a "disposable test VM" that resets to a clean base.
  - `VZCustomVirtioDeviceConfiguration` [L, from the session summary].
- **Sizes and time:**
  - macOS 27.0 IPSW (`UniversalMac_27.0_26A428_Restore.ipsw`) is **26,626,436,228 bytes** [V: HTTP HEAD on updates.cdn-apple.com]. macOS 26.x IPSWs are about 19.8 GB [V: api.ipsw.me].
  - Apple's sample creates a **128 GB** disk image [V]. Oakley suggests a 50–100 GB sparse disk (about 50 GB actually used) and 16 GB RAM for reliable iCloud [V: Tahoe article].
  - Install time once the IPSW is local: Oakley reports building a VM in under 15 minutes [L: https://eclecticlight.co/2023/09/07/how-to-build-a-custom-macos-vm-on-apple-silicon/]. Downloading 26.6 GB takes about 36 minutes at 100 Mbit/s or about 71 minutes at 50 Mbit/s (arithmetic).
  - **Plan on about 60–80 GB of free disk and 16 GB or more of host RAM.** Many base 8/16 GB MacBooks will struggle.
- **IPSW sources:**
  - `VZMacOSRestoreImage.latestSupported` / `fetchLatestSupported(completionHandler:)` (network) [V].
  - Apple's catalog `https://mesu.apple.com/assets/macos/com_apple_macOSIPSW/com_apple_macOSIPSW.xml` currently lists 27.0 26A428 [V].
  - Third-party `https://api.ipsw.me/v4/device/VirtualMac2,1?type=ipsw` has the full history [V].
  - For in-guest upgrades: `softwareupdate --fetch-full-installer --full-installer-version 27.0` (admin authentication required) [V man page].
- **Other VM limits:** writing to the VM disk is the main performance cost. Resizing a VM after creation was not supported (2023). The ISO keyboard's extra key doesn't work, and there is no Diagnostics mode [L: https://eclecticlight.co/2023/09/14/current-limitations-on-macos-virtual-machines-running-on-apple-silicon-macs/]. Whether Rosetta works inside a macOS guest, which you need to test Intel apps on 27, is [U]; test it on real hardware.
- **CI:** GitHub-hosted arm64 macOS runners state that nested virtualization is not supported, due to a limitation of Apple's Virtualization Framework [V: https://docs.github.com/en/actions/reference/runners/github-hosted-runners]. VM code will compile in CI but can **never run** there. You need a real Apple silicon Mac, owned or a rented bare-metal Mac (pricing not researched).

### 5.2 Minimal Swift (macOS 13+; install once, then boot with an auto-mounted share)

```swift
import Virtualization

@MainActor   // a VZVirtualMachine created without a queue must be used on the main queue
func installMacOS(ipsw: URL, bundle: URL, diskGB: UInt64 = 64) async throws -> VZVirtualMachine {
    let image = try await VZMacOSRestoreImage.image(from: ipsw)          // local .ipsw
    guard let req = image.mostFeaturefulSupportedConfiguration, req.hardwareModel.isSupported
    else { throw CocoaError(.featureUnsupported) }                       // host can't run this macOS

    let fm = FileManager.default
    try fm.createDirectory(at: bundle.appending(path: "Shared"), withIntermediateDirectories: true)
    let disk = bundle.appending(path: "Disk.img")                        // sparse raw file on APFS
    fm.createFile(atPath: disk.path, contents: nil)
    try FileHandle(forWritingTo: disk).truncate(atOffset: diskGB << 30)

    let platform = VZMacPlatformConfiguration()
    platform.hardwareModel = req.hardwareModel
    platform.machineIdentifier = VZMacMachineIdentifier()
    platform.auxiliaryStorage = try VZMacAuxiliaryStorage(
        creatingStorageAt: bundle.appending(path: "AuxiliaryStorage"), hardwareModel: req.hardwareModel)
    // Persist both, or the VM can't be rebuilt for the next boot (and loses its iCloud identity).
    try req.hardwareModel.dataRepresentation.write(to: bundle.appending(path: "HardwareModel"))
    try platform.machineIdentifier.dataRepresentation.write(to: bundle.appending(path: "MachineIdentifier"))

    let c = VZVirtualMachineConfiguration()
    c.platform = platform
    c.bootLoader = VZMacOSBootLoader()
    c.cpuCount = max(req.minimumSupportedCPUCount, min(4, VZVirtualMachineConfiguration.maximumAllowedCPUCount))
    c.memorySize = min(max(req.minimumSupportedMemorySize, 8 << 30), ProcessInfo.processInfo.physicalMemory / 2)
    let gfx = VZMacGraphicsDeviceConfiguration()
    gfx.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 80)]
    c.graphicsDevices = [gfx]
    c.storageDevices = [VZVirtioBlockDeviceConfiguration(
        attachment: try VZDiskImageStorageDeviceAttachment(url: disk, readOnly: false))]
    let net = VZVirtioNetworkDeviceConfiguration(); net.attachment = VZNATNetworkDeviceAttachment()
    c.networkDevices = [net]
    c.pointingDevices = [VZMacTrackpadConfiguration()]
    c.keyboards = [VZUSBKeyboardConfiguration()]
    let fs = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)
    fs.share = VZSingleDirectoryShare(directory: VZSharedDirectory(url: bundle.appending(path: "Shared"), readOnly: true))
    c.directorySharingDevices = [fs]                                     // guest: /Volumes/My Shared Files
    try c.validate()

    let vm = VZVirtualMachine(configuration: c)
    let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: ipsw)
    try await installer.install()          // bind installer.progress.fractionCompleted to a ProgressView
    return vm
}

@MainActor
func firstBoot(_ vm: VZVirtualMachine, user: String, password: String) async throws {
    let opts = VZMacOSVirtualMachineStartOptions()                       // macOS 13+
    if #available(macOS 27, *) {                                         // host AND guest must be 27
        let p = VZMacGuestProvisioningOptions()
        p.fullName = user; p.username = user; p.password = password
        p.logsInAutomatically = true
        try opts.setGuestProvisioning(p)
    }
    try await vm.start(options: opts)      // show it in a VZVirtualMachineView (wrap in NSViewRepresentable)
}
```

Every API name above is checked against Apple's docs JSON. The code has not been compiled here, so compile it in CI with the Xcode 27 SDK (the `xcode-27` runner label). Things deliberately left out: saving and restoring state (`saveMachineStateTo(url:)`, macOS 14+), audio, clipboard, and USB passthrough. Add them once the basics work on real hardware.

### 5.3 Open-source references

| Project | Licence (checked in the repo) | Use it for |
|---|---|---|
| Apple sample "Running macOS in a virtual machine on Apple silicon" | Apple sample-code licence | The canonical flow. The current version targets macOS 27 and Xcode 27 and adds guest provisioning, USB passthrough and a shared-base-image sample. https://developer.apple.com/documentation/virtualization/running-macos-in-a-virtual-machine-on-apple-silicon |
| VirtualBuddy (insidegui) | BSD-2-Clause [V] | The best UI reference and code you can borrow with attribution. v2.2 beta 2 reportedly worked around the 26 to 27 install bug [L] |
| UTM | Apache-2.0 [V] | Apple backend; macOS 27 USB passthrough PR #7877 and DiskImageKit "disposable mode" PR #7880 [L: PR titles] |
| Tart | **FSL-1.1-ALv2**; the LICENSE header reads "Copyright 2022-2026 OpenAI" [V] | CLI and CI VMs. FSL forbids competing commercial use until each version converts to Apache-2.0. Read it, don't copy it. |
| macosvm (s-u) | GPL-2/3 [V] | Small readable reference. Don't copy into closed-source code. |

---

## 6. Build and CI specifics (Windows developer, GitHub Actions)

- **Runner labels** [V: https://docs.github.com/en/actions/reference/runners/github-hosted-runners, https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/]:
  - arm64: `macos-14`, `macos-15`, `macos-26` (GA), `macos-latest`
  - Intel: `macos-15-intel`, `macos-26-intel`
  - `xcode-27` / `xcode-27-xlarge`: public preview, arm64, now running macOS 27. You need it to compile against the macOS 27 APIs (`VZMacGuestProvisioningOptions`, AccessoryAccess, DiskImageKit). Guard them with `if #available(macOS 27, *)` and keep the deployment target at 14.
- **Test the scanner in CI:** generate thin and fat fixtures with `clang -arch` and `lipo -create`. Build fake bundle trees (`Contents/Info.plist` with `CFBundleExecutable`) inside the test. Run on both `macos-26` and `macos-26-intel` to catch endianness or arch bugs.
- **Release:** Developer ID Application certificate, hardened runtime, entitlements (`com.apple.security.virtualization` only if the VM module ships), `xcrun notarytool submit <dmg> --wait`, then `xcrun stapler staple`. Store the certificate, key and API key in GitHub secrets. No App Sandbox, because the Mac App Store is not viable (section 3).

---

## 7. Effort estimate (solo developer, full-time, no local Mac)

| Work item | Estimate |
|---|---|
| Mach-O parser, bundle resolver and tests | 2–3 days |
| Scan catalog (section 3), launchd plist resolution, `kmutil` / `systemextensionsctl` parsing, Homebrew prefix | 5–7 days |
| Running-under-Rosetta sampler (login-item agent over N days) | 2–3 days |
| Compatibility layer: IncompatibleAppsList reader, Homebrew cask matcher, curated `compat.json` plus updater | 6–10 days, plus ongoing curation |
| SwiftUI report: risk grouping (breaks on 27 / breaks on 28 / already dead / unknown), per-workflow checklist, PDF/Markdown export | 8–12 days |
| Packaging: signing, notarization, Sparkle, licence-key check (lifetime licence) | 4–6 days |
| **Scanner MVP subtotal** | **about 6–9 weeks, plus 30–50% because there is no Mac for real-world testing** |
| VM module: download with resume and IPSW cache, install, boot view, shared folder, disk/RAM preflight | 3–4 weeks |
| VM robustness: host-version gating (26.6+), the 2-VM limit, 27-only provisioning and USB, disposable DiskImageKit overlays, error UX | 2–3 weeks |
| VM "bring my workflow into the VM" (copy apps and plug-ins through the share; explain App Store and iLok limits) | 1–3 weeks, fundamentally limited |
| **VM subtotal** | **about 6–10 weeks. A physical Apple silicon Mac with 16 GB+ RAM is mandatory.** |

---

## 8. Risks and unknowns

- A scanner's value for the 26 to 27 upgrade is modest, because Rosetta still works. Its real payoff comes with macOS 28 (fall 2027). Market it as "macOS 28 / Rosetta-end readiness" and time the launch for about WWDC 2027.
- Free competitors on basic app scanning: RoaringApps and Rosetta Check.
- The VM feature is capped by Apple: App Store apps won't run, and the SLA purpose limits apply. Many users lack the disk space or RAM.
- There is no official, licensable compatibility API. Curating the data is a permanent operating cost.
- Not verified here: whether `kmutil showloaded` and `systemextensionsctl list` run without root; whether Rosetta installs inside a macOS 27 guest; whether a 26.6.x host needs extra components for the 27.0 release IPSW; the current IncompatibleAppsList schema; and the macOS 27 SLA wording.

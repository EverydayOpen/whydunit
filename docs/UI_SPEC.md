# AppName: UI Design Spec (v1)

> **Superseded in part: the app is free ([BUILD_PLAN §10](BUILD_PLAN.md)); pricing/licensing/paywall/Dodo items are historical.** Where this document and BUILD_PLAN disagree, BUILD_PLAN wins.

> **Status:** ready for implementation · 27 Sep 2026
> **Platform:** macOS 14.0 deployment target. Build with **Xcode 26 or later**, because the macOS 26 SDK is what switches standard controls to Liquid Glass on macOS 26 and 27. The same binary keeps the classic look on 14 and 15.
> **Name:** `AppName` is a placeholder. Replace it everywhere.
> **Code:** every Swift block in this document is labelled **PROPOSAL**. It is our own code written for this spec, not copied from any studied repo. Mole (GPL-3.0), Recordly (AGPL-3.0), VoiceInk (GPL-3.0) and MaCursor (GPL-3.0) were used for ideas only. Maccy, Rectangle, WhatCable, WhatPort and Stats are MIT; see §6.2.

**Contents:** §0 Rules · §1 App structure · §2 Design tokens · §3 Components · §4 Wireframes · §5 Copy · §6 Packages and licenses · §7 QA and acceptance · Appendix A: pattern sources

---

## 0. Ten rules that settle every design argument

1. **Use system parts first.** That means NavigationSplitView, toolbar, `.inspector`, `Form(.grouped)`, `Table`, the `Settings` scene, `MenuBarExtra`, `ContentUnavailableView`, sheets and `confirmationDialog`. MaCursor looks fully native on Tahoe without a single `glassEffect` call: it is stock SwiftUI built on a `macos-26` CI runner (its `screenshot.png`, `.github/workflows/release.yml`). Maccy and Rectangle take the same approach.
2. **Glass is for chrome, never for content.** The app has exactly **one** custom glass surface, the floating ScanCapsule (§3.8). Cards, tables and reports sit on plain fills. This follows the HIG Materials page ("avoid glass on glass"). WhatPort also had to put `.thickMaterial` behind its Tahoe popover because text on the glass was hard to read (`Sources/WhatPort/Views/PortListView.swift` L46-50).
3. **Lead with the verdict, then evidence, then raw data.** Each surface opens with one headline, picked by a fixed priority order (§3.2). Findings come next, then evidence behind a disclosure, and raw IORegistry and log data behind a second "Technical details" disclosure. Sources: Mole `cmd/status/diagnosis.go`; WhatCable `Views/ContentView.swift`.
4. **Never use color alone.** Every status carries a symbol shape, a system color and a word.
5. **Use one tint and one prominent button per screen.** The accent is the user's system accent (the AccentColor asset is empty, as in Maccy and VoiceInk). Severity colors are the only other color in the UI.
6. **Report numbers honestly.** Show "At least 2.3 GB", or "Unknown" with the reason. Never show `0` or `N/A` for something we couldn't measure. Progress stops at 99% until the work actually finishes (Mole `cmd/analyze/format.go`, `analyze/view.go`).
7. **Be safe by default.** Diagnosis is read-only. Anything that changes the Mac must do four things first: show exactly what will change, make a backup copy, use the Trash, and re-check each item just before acting. "Uncertain" means "don't touch". Sources: Mole `lib/core/file_ops.sh` and the purge re-check; DaisyDisk's Collector.
8. **Keep healthy states quiet.** Passed checks collapse into "All checks (24)". No confetti and no "Great job!".
9. **Design every state.** That covers loading skeletons that match the final layout, empty, error, partial and success. No blank frames and no "coming soon" (Recordly `docs/ui-redundancy-audit.md`).
10. **Ship accessibility in v1.** VoiceOver, Full Keyboard Access, Reduce Motion, Increase Contrast, Reduce Transparency and Differentiate Without Color must all work in the first release.

---

## 1. App structure

### 1.1 Scenes

| Scene | SwiftUI type | Purpose | Notes |
|---|---|---|---|
| Main | `Window("AppName", id: "main")` | Onboarding on first run, then the split-view app | One window only. Set `NSWindow.allowsAutomaticWindowTabbing = false` to drop the Tab menu items (MaCursor). |
| Settings | `Settings { }` | Opened with ⌘, only | 5 tabs, §1.5 |
| Status | `MenuBarExtra(isInserted:content:label:)` + `.menuBarExtraStyle(.window)` | Live glance and quick actions | Opt-in toggle, on by default, offered during onboarding (HIG: let people choose) |
| Dock menu | `applicationDockMenu(_:)` in the AppDelegate | Scan Again, Open Timeline | HIG: menu bar extra actions should also appear in the Dock menu |

We use `Window` rather than `WindowGroup` because a diagnostics app has one state, and a second window would only duplicate it. We use `MenuBarExtra(.window)` rather than Maccy's `NSStatusItem` + `NSPanel` because we don't need control over focus, window level, or right-click menus, and Settings and Quit live inside the panel. §1.4 describes the upgrade path if that changes.

```swift
// PROPOSAL: App/AppNameApp.swift
@main
struct AppNameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore()                         // the single @Observable source of truth
    @AppStorage("menuBar.enabled") private var menuBarEnabled = true

    var body: some Scene {
        Window("AppName", id: "main") {
            RootView().environment(store)
        }
        .windowResizability(.contentSize)        // onboarding is fixed-size; MainView supplies min/ideal
        .defaultSize(width: 1120, height: 760)
        .commands { AppCommands(store: store) }

        Settings {
            SettingsView().environment(store)
        }

        MenuBarExtra(isInserted: $menuBarEnabled) {
            MenuBarPanel().environment(store)
        } label: {
            Image(store.needsAttention ? "menubar.alert" : "menubar.normal")   // custom template symbols
                .accessibilityLabel(store.menuBarAccessibilityLabel)            // "AppName, 1 needs attention"
        }
        .menuBarExtraStyle(.window)
    }
}

struct RootView: View {
    @AppStorage("onboarding.stage") private var stage: OnboardingStage = .welcome

    var body: some View {
        if stage == .complete {
            MainView()
                .frame(minWidth: 900, idealWidth: 1120, maxWidth: .infinity,
                       minHeight: 600, idealHeight: 760, maxHeight: .infinity)
        } else {
            OnboardingView(stage: $stage)
                .frame(width: 720, height: 560)
        }
    }
}

struct MainView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView(selection: $store.route)                 // Binding<Route?>
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            DetailView(route: store.route)
                .overlay(alignment: .bottom) { ScanCapsuleHost() } // §3.8, visible only while scanning
        }
        .inspector(isPresented: $store.inspectorShown) {
            InspectorView()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    // Keep running for the menu bar extra; quit with the last window otherwise.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(UserDefaults.standard.object(forKey: "menuBar.enabled") as? Bool ?? true)
    }
}
```

When onboarding completes, the window grows to MainView's minimum size. If it stays at 900×600 instead of the 1120×760 ideal size, set the frame once from `MainView.onAppear` on first run. Verify this on 14 and 26.

### 1.2 Sidebar and routes

```swift
// PROPOSAL
enum Module: String, CaseIterable, Identifiable { case dockDisplay, icloud, upgrade; var id: Self { self } }
enum Route: Hashable { case overview, module(Module), reports }
```

| Route | Sidebar label | SF Symbol | Window title | Shortcut | Badge |
|---|---|---|---|---|---|
| `.overview` | Overview | `gauge.with.dots.needle.67percent` | Overview | ⌘1 | none |
| **Checks** section | | | | | |
| `.module(.dockDisplay)` | Dock & Display | `cable.connector` | Dock & Display | ⌘2 | count of findings ≥ warning |
| `.module(.icloud)` | iCloud Rescue | `icloud` | iCloud Rescue | ⌘3 | same |
| `.module(.upgrade)` | Upgrade Readiness | `arrow.up.circle` | Upgrade Readiness | ⌘4 | same |
| **History** section | | | | | |
| `.reports` | Reports | `doc.text.magnifyingglass` | Reports | ⌘5 | none |

- Build the sidebar as `List(selection:)` with `.listStyle(.sidebar)`. Use plain SF Symbols, which the system tints, and give rows no custom background. On macOS 26 the sidebar floats as inset glass; on 27 it runs to the window edges and the selected row turns semibold. We get both for free.
- Don't use colored icon tiles in the sidebar. VoiceInk's System Settings-style tiles (`App/Navigation/AppSidebar.swift`) look good, but they fight the 27 edge-to-edge sidebar. We use tiles only on the Overview module cards and in onboarding (`IconTile`, §3.10).
- Sidebar badges use `.badge(n)` and show nothing at 0. The "Dock & Display" badge also counts critical drive findings.
- The bottom inset (`.safeAreaInset(edge: .bottom)`) holds two optional items:
  - `LicenseBadge` (§3.9), during the trial or after it ends. It is not shown once the app is licensed.
  - An "Update Available" chip, only when Sparkle has found an update (§6).
- **Settings does not go in the sidebar.** The HIG says Settings opens from the app menu with ⌘,. The license lives in Settings › License and in a sheet (§4.6).
- Show/Hide Sidebar lives in the View menu (`SidebarCommands()`). The sidebar is never hidden by default.

### 1.3 Main window chrome

- **Size:** minimum 900×600, default 1120×760. Content padding is 20 pt, so nothing sits in Tahoe's larger window corners.
- **Title:** set with `.navigationTitle` per route. Never use the app name as the title.
- **Toolbar:** at most 3 groups plus one primary action. Use icon-only symbols without outlines, and don't mix text and symbols in one group. Mirror every toolbar command in a menu (HIG Toolbars).

| Screen | Center / leading content | Trailing groups | The one prominent action |
|---|---|---|---|
| Overview | none | Share ▾ · Inspector | **Scan Again** (toolbar). While the hero shows "Run First Scan", the toolbar button is plain. |
| Dock & Display | Segmented `Devices / Timeline / Guided Test` (`.principal`) | Share ▾ · Inspector | **Scan Again** on Devices and Timeline. On Guided Test the stepper owns the prominent button (**I've Done This**, then **Done**), and the toolbar has no Scan button. |
| iCloud Rescue | `.searchable` field · Show filter menu | Share ▾ · Inspector · Scan Again (plain) | **Rescue Selected…** in the bottom bar |
| Upgrade Readiness | Target menu (`macOS 27 ▾`) · segmented `Needs Attention / All` | Share ▾ · Inspector | **Scan Again** |
| Reports | `.searchable` | Export ▾ | none |

- **Share menu** (`square.and.arrow.up`): Copy Diagnostic Report (⇧⌘C), Export as Markdown…, Export as JSON…, Email Support…. Export opens the preview sheet described in §4.9.
- **Inspector** (`sidebar.trailing`): closed by default. It shows evidence and technical details for the selected finding, device node or timeline event. `InspectorCommands()` provides the menu item and its shortcut.
- **Spacing between toolbar groups:** on macOS 26+, separate groups with `ToolbarSpacer(.fixed)`. Check whether `ToolbarContentBuilder` accepts `if #available` in our Xcode. If it doesn't, leave the spacers out, because the system groups items automatically.
- Don't add anything else to the toolbar: no text labels, no brand color and no custom backgrounds.

### 1.4 Menu bar extra

- **Label:** a custom template symbol exported from the SF Symbols app (`menubar.normal`) plus an alert variant (`menubar.alert`) with a small dot cut into it. Template images are monochrome, so state is shown by shape. Never color the menu bar icon.
- **Panel:** 320 pt wide, 480 pt maximum height, scrolls beyond that. The wireframe is in §4.8. Its content, top to bottom:
  1. A header with the verdict and the time of the last check.
  2. The top finding as a compact FindingCard, or nothing when all is clear.
  3. The **Connected** section: one row per device, showing a status dot, the name, and a monospaced live value.
  4. The **iCloud Drive** section: one line.
  5. **Run Quick Check**, then Open AppName, Settings…, Quit AppName.
- **Rows:** clicking a row calls `NSApp.activate()` and `openWindow(id: "main")`, then sets `store.route` and the selection.
- **Section headers:** uppercase `.caption.weight(.semibold)` in `.secondary`. This is allowed **only here**, because it is a dense panel (MaCursor `CursorEngineHelper/MenuBarPanelView.swift`, WhatPort). The main window uses title-case headers.
- **Legibility on Tahoe:** ship on the system background. If the QA contrast check fails over a bright wallpaper with Liquid Glass set to "Clear", add `.background(.thickMaterial)` to the panel content. That one line is the fix WhatPort shipped.
- **Upgrade path, not in v1:** if we later want a right-click menu or a global hotkey, move to `NSStatusItem` + `NSPopover` (the pattern in MaCursor `MACMenuBar.m` and Maccy `FloatingPanel.swift`) and add KeyboardShortcuts (§6).

### 1.5 Settings scene

Build Settings as a `TabView` with `.tabItem`. The `Tab(...)` API needs macOS 15, and `.tabItem` works from 14 through 27. Each pane is a `Form { … }.formStyle(.grouped)` at a fixed **520 pt** width. The window title follows the tab automatically.

Rules for every pane:
- Every control has a one-line caption directly under it (`.caption`, `.secondary`). Don't use `.tertiary`, because it fails contrast in light mode.
- Destructive actions sit alone in the last section, behind a confirmation.
- The last tab is remembered with `@AppStorage("settings.tab")`.
- To open a specific tab from elsewhere, set that key and then call `openSettings()` (macOS 14+).

| Tab | Symbol | Contents |
|---|---|---|
| General | `gearshape` | Open at login (`SMAppService.mainApp.register()` / `unregister()`). Show AppName in the menu bar. Updates: "Automatically check for updates" toggle, then "Check for Updates…" with `v1.4.2 (142)` right-aligned. |
| Monitoring | `bell.badge` | **Watch for changes** master toggle. Needs the menu bar extra or an open window; the caption says so. **Notify me when:** a dock or drive disconnects without warning; link speed drops (Thunderbolt → USB); a display falls below its best refresh rate; iCloud files are stuck for more than `[3 days ▾]`. **Only notify after it lasts** `[10 seconds ▾]`. **Keep event history for** `[7 days ▾]`. If notifications are not allowed, a PermissionRow (Notifications) appears at the top. Ask for notification permission here, in context, never at launch. |
| Privacy | `hand.raised` | PermissionRows for Full Disk Access and Notifications. A "What AppName reads" disclosure with the same list as onboarding step 2. "Keep a log of changes AppName makes" toggle (on), with Show Log in Finder. "Clear Event History…" as a destructive action. |
| License | `key` | `LicenseView` (§4.6). This is the same view the License sheet uses. |
| Advanced | `gearshape.2` | "Show technical details by default" toggle. Ignored findings (N), with Restore. Export Diagnostic Logs…. Acknowledgements…. **Reset All Settings…** alone in the last section, as a destructive action. |

### 1.6 Onboarding flow

`Welcome → Your data → Permissions → Ready`. The wireframes are in §4.5.

```swift
// PROPOSAL
enum OnboardingStage: String { case welcome, privacy, permissions, ready, complete }
```

- **Where it runs:** in the main window at a fixed 720×560 (see `RootView`), with no toolbar title. On macOS 15+ apply `.toolbar(removing: .title)` and `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`. On 14 the standard title bar shows "Welcome".
- **Resuming:** the stage is saved in `@AppStorage`, and every launch resumes at that stage. Granting Full Disk Access usually forces a relaunch, and the user must land back on Permissions (VoiceInk `reconcileStage()`).
- **Layout:** each step has a 64 pt icon tile, a title in `.largeTitle.bold()`, a subtitle in `.title3` + `.secondary`, and content no wider than 560 pt. The bottom bar has page dots on the left, and Back (bordered) plus **Continue** (`.borderedProminent`, `.keyboardShortcut(.defaultAction)`) on the right. Esc does nothing.
- **Continue is never blocked by a permission.** All permissions are optional.
- **Transitions:** steps cross-fade with `Motion.standard`, using opacity only when Reduce Motion is on.
- **No scanning before "Ready".** The trial starts when the Ready step appears (§1.7).
- **Optional question on the last step:** "What brought you here?" This picks the first module the Overview emphasises and frames the first report, like EtreCheck's "what's the problem?" question. It is never required.

### 1.7 License and trial

**Gating (recommended; confirm with the owner):** the diagnosis is always free, and a license pays for fixing problems and watching over time. This follows Mole for Mac ("each tool twice free, pay to apply") and VoiceInk's soft gating.

| Capability | Trial (14 days) | Licensed | Trial ended |
|---|---|---|---|
| Scans, findings, evidence, topology, Upgrade Readiness report on screen | ✓ | ✓ | ✓ |
| Guided tests | ✓ | ✓ | ✓ |
| Copy Diagnostic Report (plain text) | ✓ | ✓ | ✓ (helps support and word of mouth) |
| iCloud Rescue actions | ✓ | ✓ | locked |
| Background monitoring, notifications, Record a Problem sessions | ✓ | ✓ | locked (live view while the app is open stays free) |
| Export report files (Markdown/JSON), saved report history | ✓ | ✓ | locked |

- **Trial:** 14 days, not VoiceInk's 7, because intermittent dock drop-outs need time to show up. The trial starts when the user reaches the Ready step of onboarding, not at first launch. It counts down in the sidebar `LicenseBadge`, which turns orange at 2 days or fewer.
- **When the trial ends, nothing disappears.** Locked actions keep their buttons, with a leading `lock.fill` and the tooltip "Included with the lifetime license". Clicking one opens the License sheet. The action is never hidden, and the diagnosis is never blocked.
- **Backend:** Polar.sh license keys, calling the public customer-portal `validate`, `activate` and `deactivate` endpoints with only the `organization_id` compiled in, as VoiceInk's `Infrastructure/Licensing/PolarService.swift` does. The key and activation ID live in the Data Protection Keychain. We improve on VoiceInk in three ways:
  - We re-validate every 14 days.
  - We allow a 30-day offline grace period, with no UI until fewer than 7 days of grace remain.
  - We **never fail open silently.** If the Keychain is unavailable, the app shows a banner.
- **Surfaces:** Settings › License, the License sheet (opened from locked actions and from the sidebar badge), and one line in the About panel.

---

## 2. Design tokens

### 2.1 Spacing (points)

| Token | Value | Use |
|---|---|---|
| `Space.xxs` | 4 | icon to label inside chips; gap between title and subtitle |
| `Space.xs` | 8 | rows inside a card; button groups |
| `Space.s` | 12 | between cards; card padding in dense panels (menu bar) |
| `Space.m` | 16 | card padding; between the hero and the first section |
| `Space.l` | 20 | window content padding (keeps content out of Tahoe's larger corners) |
| `Space.xl` | 24 | between sections |
| `Space.xxl` | 32 | onboarding content padding |
| `Space.xxxl` | 40 | onboarding top margin, above the icon tile |

### 2.2 Corner radii

Always use `style: .continuous`. A nested shape's radius is the parent's radius minus the padding between them, never below 4. Maccy keeps selection shapes concentric this way (`Observables/Popup.swift`).

| Token | Value | Use |
|---|---|---|
| `Radius.badge` | 4 | small capsule-like tags ("HD", "Recommended"), inner nested shapes |
| `Radius.control` | 6 | icon tiles ≤ 24 pt, text-field chips |
| `Radius.row` | 8 | callouts, hover and selection backgrounds, topology nodes |
| `Radius.card` | 12 | FindingCard, module cards, sections |
| `Radius.hero` | 16 | StatusHeroCard, onboarding icon tile (64 pt) |
| capsule | n/a | ScanCapsule, choice chips, the "Copied" pill |

Don't hard-code window-corner insets or control heights: macOS 26 made controls slightly taller, and macOS 27 tightens window corners.

### 2.3 Typography

Use system text styles only. macOS has no Dynamic Type, so these sizes are fixed: body is 13 pt and the floor is 10 pt. Never use Ultralight, Thin or Light. Headers use title-style capitalization, except in the menu bar panel.

| Token | SwiftUI | Size | Use |
|---|---|---|---|
| `verdict` | `.largeTitle.weight(.bold)` | 26 | Hero verdict word ("Worth a Look"), onboarding titles |
| `heroHeadline` | `.title3` | 15 | The one-sentence headline under the verdict; guided-test instruction |
| `sectionTitle` | `.headline` | 13 bold | Section headers ("Before you upgrade"), card titles |
| `body` | `.body` | 13 | Explanations, steps |
| `meta` | `.callout` + `.secondary` | 12 | Summary lines, evidence rows, subtitles, timeline subtitles |
| `caption` | `.caption` + `.secondary` | 10 | Settings footers, table footnotes |
| `panelHeader` | `.caption.weight(.semibold)` + `.textCase(.uppercase)` + `.secondary` | 10 | Menu bar panel only |
| `value` | any of the above + `.monospacedDigit()` | n/a | Every number that changes: speeds, sizes, counts, times |
| `raw` | `.callout.monospaced()` + `.textSelection(.enabled)` | 12 | Technical details only |

When a value changes, animate it with `.contentTransition(.numericText())`, or `.opacity` under Reduce Motion.

### 2.4 Severity: color, symbol, word

Use **system colors only**. `Color.red`, `.orange`, `.green` and `.blue` already have light, dark and Increase Contrast variants, so we need no asset-catalog colors. Warning is **orange, not yellow**, because yellow symbols and text fail contrast on light backgrounds.

| Severity | Color | Symbol | Word (visible and spoken) | Hero verdict | When to use it |
|---|---|---|---|---|---|
| `.critical` | `.red` | `xmark.octagon.fill` | Needs attention | **Needs Attention** | Risk of data loss, or a device that doesn't work at all |
| `.warning` | `.orange` | `exclamationmark.triangle.fill` | Worth a look | **Worth a Look** | Degraded or blocked, but safe (slow link, 30 Hz, stuck uploads, an upgrade blocker) |
| `.info` | `.blue` | `info.circle.fill` | Note | All Clear | A fact worth knowing that needs no action |
| `.ok` | `.green` | `checkmark.circle.fill` | OK | **All Clear** | A check passed. Shown only in "All checks", never as a card. |
| `.unknown` | `.secondary` | `questionmark.circle` | Couldn't check | no effect on the verdict | Couldn't be measured. **Always** comes with a reason. |

- **Tinted fills:** callout and card backgrounds use `color.opacity(0.08)`. Under Increase Contrast (`colorSchemeContrast == .increased`) the fill goes to `0.16` and the card gets a 1 pt stroke.
- **Differentiate Without Color:** `SeverityIcon` adds its word as visible text next to the symbol.
- **Text stays primary.** Only symbols and dots use the severity color. WhatPort colors only the dot, never the whole row.
- **Verdict:** the hero verdict is the worst severity among current findings. `.unknown` and `.info` never change the verdict; they appear in the summary line.

### 2.5 Check outcomes

We adapt Mole's six task outcomes (`lib/optimize/outcomes.sh`) for check rows in "All checks" and for rescue results.

| Outcome | Symbol | Color | Summary wording |
|---|---|---|---|
| `passed` | `checkmark.circle` | `.green` | "22 passed" |
| `fixed` | `wrench.and.screwdriver` | `.green` | "1 fixed" |
| `attention(Severity)` | the severity's symbol | the severity's color | "2 need attention" |
| `skipped(reason)` | `minus.circle` | `.secondary` | "skipped: Pages has the file open" |
| `unavailable(reason)` | `questionmark.circle` | `.secondary` | "couldn't check: the enclosure doesn't report health" |
| `failed(reason)` | `exclamationmark.circle` | `.secondary` | "check didn't finish: iCloud didn't answer in 30 s" |

`failed` means **our** check failed, not the Mac, so it is neutral gray and never red. The summary line format is always `Checked 24 · 2 need attention · 1 couldn't be checked`, with zero-count parts left out.

### 2.6 SF Symbols

Check each symbol's minimum OS in the SF Symbols app (Info › Availability) before use. When a newer name has an older alias, use the older name, because old names keep working on 26 and 27 but new names don't exist on 14. Example: `doc.on.doc`, not `document.on.document`. Use one weight family everywhere: `.regular` in lists and `.semibold` in `SeverityIcon`.

| Concept | Symbol | Concept | Symbol |
|---|---|---|---|
| Overview | `gauge.with.dots.needle.67percent` | iCloud Rescue module | `icloud` |
| Dock & Display module | `cable.connector` | iCloud stuck / ok / off | `exclamationmark.icloud` / `checkmark.icloud` / `icloud.slash` |
| Upgrade Readiness module | `arrow.up.circle` | Upload / download | `icloud.and.arrow.up` / `icloud.and.arrow.down` |
| Reports | `doc.text.magnifyingglass` | Retry sync | `arrow.clockwise.icloud` |
| Mac (laptop / desktop) | `laptopcomputer` / `desktopcomputer` | Intel-only app | `cpu` |
| Display / two displays | `display` / `display.2` | Kernel or system extension, plug-in | `puzzlepiece.extension` |
| Hardware dock | `rectangle.connected.to.line.below` | Free space | `internaldrive` |
| Cable | `cable.connector.horizontal` | Backup | `clock.arrow.circlepath` |
| Charger / power | `powerplug` | Timeline | `list.bullet.rectangle` |
| External drive | `externaldrive` | Record a Problem | `record.circle` |
| Guided test | `checklist` | Full Disk Access | `lock.shield` |
| Notifications | `bell.badge` | Menu bar toggle | `menubar.rectangle` |
| License / licensed | `key` / `checkmark.seal.fill` | Locked action | `lock.fill` |
| Scan Again | `arrow.clockwise` | Stop scan | `xmark` |
| Share / Copy | `square.and.arrow.up` / `doc.on.doc` | Reveal in Finder | `folder` |
| Inspector | `sidebar.trailing` | More actions | `ellipsis.circle` |

On macOS 27, menus show fewer icons by default. Opt the Scan menu items in with `.labelStyle(.titleAndIcon)`. Rectangle does the equivalent in AppKit with `preferredImageVisibility = .visible`.

### 2.7 Materials and Liquid Glass

| Surface | Layer | macOS 26 / 27 | macOS 14 / 15 |
|---|---|---|---|
| Sidebar, toolbar, inspector | navigation | System, automatic. No custom backgrounds and no `NSVisualEffectView`. | System |
| Toolbar prominent action | navigation | `.buttonStyle(.borderedProminent)`, tinted automatically | Same |
| **ScanCapsule** (floating) | control | `glassEffect(.regular, in: Capsule())` | `.regularMaterial` capsule + 0.5 pt `.separator` stroke |
| Bottom action bar (iCloud Rescue) | navigation | `safeAreaBar(edge: .bottom)` | `safeAreaInset` + `Divider` + `.bar` background |
| Hero, cards, tables, reports | content | `.cardStyle()`: `primary` at 4% fill + hairline. **Never glass.** | Same |
| Sheets, alerts, popovers, menus | system | System | System |
| Menu bar panel | system | System; add `.thickMaterial` only if QA fails (§1.4) | System |

- **One file owns every availability check.** `DesignSystem/Glass.swift` is the only file allowed to contain `#available(macOS 26, *)`, and views never branch on it inline. This follows the pattern of robinebers/openusage PR #623, which is MIT.
- **Standard controls need no wrapping.** They adapt by themselves.
- **No `.glassProminent`, no `backgroundExtensionEffect`, no `GlassEffectContainer` in v1.** With only one glass element there is nothing to group. Add them only if a second floating control appears.
- **Accessibility is automatic for system materials.** System glass and materials handle Reduce Transparency, Increase Contrast and Reduce Motion themselves. `.regularMaterial` in the fallback becomes opaque under Reduce Transparency without any code from us.
- **Inactive windows:** on macOS 27, inactive windows dim automatically. Our only custom surface, the ScanCapsule, reads `@Environment(\.appearsActive)` and switches its label to `.secondary` when the window is inactive.

### 2.8 Motion

| Token | Default | With Reduce Motion |
|---|---|---|
| `Motion.standard` | `.smooth(duration: 0.28)` | `.linear(duration: 0.15)`, opacity only |
| `Motion.hover` | `.easeOut(duration: 0.12)` | same, since it is opacity only |
| Entrance (a new finding or event) | `.opacity.combined(with: .move(edge: .top))` | `.opacity` |
| Phase swap (scan label text) | `.contentTransition(.opacity)` | same |
| Verdict symbol change | `.contentTransition(.symbolEffect(.replace))` | no transition |
| Live dot, "waiting" dot | `.symbolEffect(.pulse, isActive: true)` | static |
| Activation success | `checkmark.seal.fill` with `.symbolEffect(.bounce, value:)`, once | static |

**Never** put an unscoped `.animation(...)` on live data. Always use `.animation(_:value:)`. New timeline rows animate in; existing rows never move. Batch live UI updates to at most two per second.

### 2.9 Token and glass files

```swift
// PROPOSAL: DesignSystem/Tokens.swift
import SwiftUI

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum Radius {
    static let badge: CGFloat = 4
    static let control: CGFloat = 6
    static let row: CGFloat = 8
    static let card: CGFloat = 12
    static let hero: CGFloat = 16
    static func inner(_ outer: CGFloat, padding: CGFloat) -> CGFloat { max(4, outer - padding) }
}

enum Severity: Int, Comparable, CaseIterable, Sendable {
    case ok, unknown, info, warning, critical
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var color: Color {
        switch self {
        case .ok: .green
        case .unknown: .secondary
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }
    }
    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }
    var word: String {
        switch self {
        case .ok: String(localized: "OK")
        case .unknown: String(localized: "Couldn't check")
        case .info: String(localized: "Note")
        case .warning: String(localized: "Worth a look")
        case .critical: String(localized: "Needs attention")
        }
    }
    var verdict: String {
        switch self {
        case .critical: String(localized: "Needs Attention")
        case .warning: String(localized: "Worth a Look")
        default: String(localized: "All Clear")
        }
    }
}

enum Motion {
    static func standard(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.28)
    }
    static let hover: Animation = .easeOut(duration: 0.12)
    static func entrance(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top))
    }
}

struct CardStyle: ViewModifier {
    var tint: Color? = nil
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let high = contrast == .increased
        content
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(tint.map { $0.opacity(high ? 0.16 : 0.08) } ?? Color.primary.opacity(0.04)))
            .overlay(shape.strokeBorder(Color.primary.opacity(high ? 0.35 : 0.08), lineWidth: high ? 1 : 0.5))
    }
}

extension View {
    func cardStyle(tint: Color? = nil) -> some View { modifier(CardStyle(tint: tint)) }
}

/// Honest size label: "At least 4.2 GB" when a scan was partial, "Unknown" when nothing was measured.
/// (Idea from Mole cmd/analyze/format.go measuredSizeLabel; reimplemented.)
func sizeLabel(_ bytes: Int64?, partial: Bool) -> String {
    guard let bytes, !(partial && bytes == 0) else { return String(localized: "Unknown") }
    let size = bytes.formatted(.byteCount(style: .file))
    return partial ? String(localized: "At least \(size)") : size
}
```

```swift
// PROPOSAL: DesignSystem/Glass.swift. The ONLY file allowed to contain `#available(macOS 26, *)`.
import SwiftUI

extension View {
    /// Floating controls only (the ScanCapsule). Never apply to content.
    @ViewBuilder
    func controlGlass(in shape: some Shape = Capsule()) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.separator, lineWidth: 0.5))
        }
    }

    /// Bottom action bar that gets the system scroll-edge treatment on 26+.
    @ViewBuilder
    func bottomActionBar(@ViewBuilder _ bar: () -> some View) -> some View {
        if #available(macOS 26, *) {
            safeAreaBar(edge: .bottom) {   // verify the signature against the shipping SDK
                bar().padding(.horizontal, Space.l).padding(.vertical, Space.s)
            }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    bar().padding(.horizontal, Space.l).padding(.vertical, Space.s)
                }
                .background(.bar)
            }
        }
    }
}
```

`.rect(corner: .containerConcentric)` and `glassEffect(_:in:isEnabled:)` appear in WWDC25 slides and many blogs, but they are beta spellings and won't compile. Trust only the shipping API docs.

---

## 3. Components

All components live in `DesignSystem/Components/`. Each ships `#Preview`s for every state listed, in light and dark. A component takes plain data and closures and never reads the store directly, so the Overview, the modules, the menu bar panel and report rendering can all share them.

### 3.0 Shared model contract

```swift
// PROPOSAL: pure value types produced by the diagnosis engines (no SwiftUI, no IOKit here).
struct Finding: Identifiable, Hashable {
    enum Impact: Int, Comparable { case minor, degraded, upgradeBlocker, blockedWork, dataLoss
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue } }
    let id: String                 // stable across scans, e.g. "dock.link.downgraded:<deviceID>"
    let module: Module
    let severity: Severity
    let impact: Impact             // tie-breaker for the headline (see 3.2)
    let title: String              // the verdict: ≤ 60 chars, sentence case, no trailing period
    let explanation: String        // what we measured + why it matters: ≤ 3 sentences
    let steps: [String]            // what to try, in order: ≤ 4
    let evidence: [Evidence]
    let actions: [FindingAction]   // [0] primary, [1] secondary, the rest go in the ⋯ menu
    let isLikelySymptom: Bool      // shows the "Likely a symptom" chip
    let detectedAt: Date
}

struct Evidence: Hashable {
    enum Source: CaseIterable { case measured, reportedByDevice, appleRequirement, knowledgeBase }
    let source: Source             // group header: "Measured on this Mac" / "Reported by the device" /
                                   // "Apple's requirement" / "Our knowledge base"
    let label: String              // "Link speed"
    let value: String?             // "10 Gb/s"; nil means `note` explains why ("Not read on this connection")
    let note: String?
    let raw: [String: String]      // technical details, rendered only on demand
}

struct FindingAction: Identifiable, Hashable {
    enum Kind: Hashable {
        case fix(reversible: Bool, needsAdmin: Bool), guidedTest, openURL(URL), revealInFinder(URL), copyText
    }
    let id: String
    let title: String              // verb first, ≤ 3 words: "Run Guided Test"
    let systemImage: String
    let kind: Kind
    let requiresLicense: Bool
}

enum ActionState: Equatable { case idle, running, done(outcome: String), failed(String) }

struct ScanSummary: Hashable {
    let verdict: Severity          // worst severity among findings; .ok when there are none
    let headline: String           // top finding's title, or "Nothing needs your attention."
    let checked: Int, needsAttention: Int, unavailable: Int, resolvedSinceLast: Int
    let finishedAt: Date
    let duration: Duration
    let topFinding: Finding.ID?
}
```

**Picking the headline** (after Mole's `diagnosis.go`, reimplemented): take the finding with the highest `severity`, then the highest `impact`, then the newest `detectedAt`. The impact order is: data loss (a drive reporting failures, iCloud files that exist only on a failing disk), then blocked work (a display not driven, a dock dropping out, uploads stuck more than 3 days), then an upgrade blocker, then degraded, then minor. With no findings, the headline is "Nothing needs your attention."

### 3.1 SeverityIcon (primitive)

This is the only view allowed to draw a severity. Every other component uses it.

```swift
// PROPOSAL
struct SeverityIcon: View {
    let severity: Severity
    var size: CGFloat = 16
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        HStack(spacing: Space.xxs) {
            Image(systemName: severity.symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(severity.color)
            if differentiate && severity != .ok {
                Text(severity.word).font(.caption.weight(.semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(severity.word))
    }
}
```

### 3.2 StatusHeroCard: the overall verdict

```swift
// PROPOSAL
struct StatusHeroCard: View {
    enum Content: Equatable {
        case neverScanned
        case result(ScanSummary, isUpdating: Bool)      // isUpdating: a scan is running, show last result dimmed
        case failed(message: String, last: ScanSummary?)
    }
    let content: Content
    var onScan: () -> Void
    var onReview: (Finding.ID) -> Void
}
```

- **Anatomy:** `SeverityIcon` at 28 pt, then the verdict word (`verdict`), the headline (`heroHeadline`), the summary line (`meta` + `.monospacedDigit()`: "Checked 24 · 2 need attention · 1 couldn't be checked"), then "Scanned 2 min ago · took 18 s", then an optional **[Review ›]**, which jumps to the top finding. Padding is 20. Use `.cardStyle(tint:)` with the verdict color for warning and critical, and the neutral fill otherwise. Radius is `Radius.hero`.
- **Modules:** each module screen uses the same view in a compact variant, with the verdict and headline on one line and no Review button.

**States** (drawn in §4.1):

| State | What shows |
|---|---|
| `neverScanned` | "Not checked yet", "A full check takes about 20 seconds and changes nothing on your Mac.", and **[Run First Scan]** (prominent). While this state shows, the toolbar Scan button is plain. |
| scanning, first run | A skeleton of the real layout using `.redacted(reason: .placeholder)`. The ScanCapsule shows progress. |
| scanning, with a previous result | The last result at 50% opacity with "Updating…" top right. There is never a blank card. |
| `result` | As above. Add "2 resolved since last scan" to the summary line when that count is above 0. |
| `failed` | `exclamationmark.circle` in `.secondary` (never red, because it is our failure), "The scan didn't finish", the reason, and **[Try Again]** + **[Copy Details]**. Keep showing the last good result underneath if there is one. |
| stopped by the user | Headline: "Scan stopped. Showing results from 2 min ago." (Mole's summary heading always says how the run ended.) |

- **Motion:** the verdict symbol uses `.contentTransition(.symbolEffect(.replace))`. The headline uses `.contentTransition(.opacity)`. Counts use `.numericText()`.
- **Keyboard:** Review takes no default shortcut. ⌘R is Scan Again from the menu.
- **Accessibility:** `.accessibilityElement(children: .combine)` with the label "Worth a look. Your dock is connected at USB speed, not Thunderbolt. Checked 24, 2 need attention." Add a custom action "Review".

### 3.3 FindingCard

```swift
// PROPOSAL
struct FindingCard: View {
    enum Style { case full, compact }                    // compact: Overview, menu bar panel
    let finding: Finding
    var style: Style = .full
    var actionState: [FindingAction.ID: ActionState] = [:]
    var isLocked: (FindingAction) -> Bool = { _ in false }
    var onAction: (FindingAction) -> Void
    var onIgnore: (() -> Void)? = nil
    @AppStorage("showTechnicalDetails") private var technicalByDefault = false
    @State private var showsEvidence = false
}
```

```text
┌────────────────────────────────────────────────────────────────────────┐
│ [1]▲ [2]Your dock is connected at USB speed    [3]Likely symptom  [4]⋯ │
│     [5]We measured a 10 Gb/s link on the left USB-C port. This dock    │
│        supports 40 Gb/s. A USB 3 or charge-only cable is usually why.  │
│     [6]What to try  1. … 2. … 3. …                                     │
│     [7]▸ Evidence   (provenance groups; nested ▸ Technical details)    │
│     [8][ Run Guided Test ]  [9]Copy Details                            │
└────────────────────────────────────────────────────────────────────────┘
```

The numbers in the drawing map to the parts below.

1. `SeverityIcon` at 16 pt.
2. The title in `.headline`, `lineLimit(2)`.
3. The "Likely a symptom" chip, shown only when `isLikelySymptom`. The explanation then names the likely cause, as Mole does for WindowServer.
4. The `⋯` menu (`ellipsis.circle`, `.menuStyle(.borderlessButton)`): Copy Details, Reveal in Finder where it applies, "Ignore This Finding…". Ignore works like Mole's whitelist: the finding hides with an Undo toast, and you can restore it in Settings › Advanced.
5. The explanation in `.body`.
6. "What to try", a numbered list in `.callout`.
7. The **Evidence** `DisclosureGroup`. Evidence lines are grouped by `Source` using the fixed headers, with the `note` as the group subtitle when `value == nil` (WhatCable `Output/BulletGroup.swift`). A nested "Technical details" `DisclosureGroup` renders `raw` in the `raw` style. It is expanded by default only when `technicalByDefault` is on.
8. The primary action. It is always `.bordered`, **never prominent**, because the screen owns its one prominent button.
9. The secondary action, a `.link`-style button.

The compact style shows the header plus one line of evidence and a trailing `›`. The whole card is a `Button` that navigates to the finding.

**States:**

| State | What shows |
|---|---|
| idle | As drawn. |
| action `running` | The button shows `ProgressView().controlSize(.small)` and "Working…", and is disabled. The other actions are disabled too. |
| action `done(outcome)` | A result line under the actions: `✓ Done. The link is now 40 Gb/s.` or `No change needed.` |
| action `failed(msg)` | `exclamationmark.circle` in `.secondary` + the message + **Try Again**. |
| locked (`isLocked`) | The action keeps its title, gains a leading `lock.fill`, and has `.help("Included with the lifetime license")`. Clicking it opens the License sheet. |
| resolved on the next scan | The card leaves with `Motion.entrance` reversed, and the hero adds "1 resolved since last scan". |
| loading (skeleton) | `FindingCard(finding: .placeholder).redacted(reason: .placeholder)`. |

- **Keyboard:** cards sit in a `List(selection:)`, so ↑ and ↓ move between them. With Full Keyboard Access, Space toggles Evidence, because the DisclosureGroup is native. Return on a selected card opens its evidence in the inspector. Destructive actions never get a shortcut.
- **Accessibility:** the header uses `.accessibilityElement(children: .combine)` with the label "Worth a look: Your dock is connected at USB speed, not Thunderbolt". Expose every action with `.accessibilityActions { ForEach(finding.actions) { a in Button(a.title) { onAction(a) } } }`.

### 3.4 EventTimelineRow

```swift
// PROPOSAL
struct TimelineEvent: Identifiable, Hashable {
    enum Kind: CaseIterable { case connected, disconnected, linkChanged, powerChanged, displayModeChanged,
                                   driveEjectedUnexpectedly, icloudStateChanged, sleep, wake }
    let id: UUID
    let date: Date
    let kind: Kind
    let severity: Severity?        // nil = context event (sleep/wake), drawn neutral
    let device: String             // "CalDigit TS4"
    let location: String?          // "left USB-C port"
    let title: String              // before → after: "Link: 40 Gb/s → 10 Gb/s"
}

struct EventTimelineRow: View {
    let event: TimelineEvent
    var hasDetail: Bool = true
}
```

```text
 [1]▲  [2]Link: 40 Gb/s → 10 Gb/s                       [4]14:02:31   [5]›
        [3]CalDigit TS4 · left USB-C port
 [1]·  [2]Mac woke from sleep  (context: no color)           14:02:05
```

1. `SeverityIcon` at 14 pt. Context events get a 6 pt `circle.fill` in `.tertiary`.
2. The title, with `→` between the before and after values, which use `.monospacedDigit()`.
3. Device · location, in `meta`.
4. The absolute time `Text(event.date, format: .dateTime.hour().minute().second())` in `.monospacedDigit()` + `.secondary`, with the relative time ("2 min ago") in `.help`.
5. A chevron that appears on hover (`Motion.hover`), only when the row has detail.

- **Grouping and order:** rows are grouped by day in `Section`s headed "Today", "Yesterday" or the date, newest first.
- **Behavior:** selecting a row shows the full event in the inspector. New rows enter with `Motion.entrance`, and existing rows never animate.
- **Hover:** the row fills with `Color.primary.opacity(0.04)`.
- **Accessibility:** combine the row; label it "Worth a look. Link changed from 40 to 10 gigabits per second. CalDigit TS4, left USB-C port. 2:02 PM."
- **Sleep and wake:** these context events always show. They are what makes "the dock dropped after wake" visible.

### 3.5 GuidedTestStepper (A/B dock tests)

```swift
// PROPOSAL
struct GuidedStep: Identifiable {
    enum Detection { case automatic(timeout: Duration), manual }
    let id: String
    let title: String              // "Swap the port"
    let instruction: String        // one sentence, shown in heroHeadline
    let detail: String?
    let illustration: [String]     // SF Symbols composed left → right
    let precondition: Precondition?   // e.g. "Eject drives behind the dock first"; blocks until satisfied
    let detection: Detection
}

@Observable final class GuidedTestModel {
    enum StepState: Equatable { case instructing, waiting(since: Date), captured(Reading), timedOut, skipped }
    let title: String
    let steps: [GuidedStep]
    private(set) var index = 0
    private(set) var state: StepState = .instructing
    private(set) var readings: [Reading] = []          // A, B, C… shown in the comparison grid
    private(set) var result: GuidedTestResult?
    // API: begin() · confirmManually() · back() · skip() · cancel()
}

struct GuidedTestStepper: View {
    @Bindable var model: GuidedTestModel
    var onFinish: (GuidedTestResult) -> Void
    var onCancel: () -> Void
}
```

- **Anatomy** (wireframes in §4.2c):
  - a title and a meta line ("4 steps · about 3 minutes · nothing on your Mac is changed");
  - a horizontal step indicator (`✓ done`, `● current`, `○ upcoming`);
  - the step card: illustration, instruction, precondition line, and a live detection row;
  - a readings `Grid` that grows as values are captured;
  - a bottom bar built with `bottomActionBar`.
- **Detection:** steps advance **automatically** when the engine sees the expected event, such as the dock reconnecting on another port. The user never has to press "Done" (Rectangle `AccessibilityAuthorization.swift`, which polls and auto-continues). On detection the row shows `✓ Reading captured` with one bounce, then advances 1 s later.
- **Manual fallback:** "I've Done This" (prominent, `.defaultAction`) becomes enabled after 10 s.
- **Timeout:** after 90 s the step shows "We didn't see the dock reconnect." with **[Try Again]** and **[I've Done This]**.
- **Safety preconditions** are enforced. Example: "Eject Samsung T7 before you unplug the dock", with an **[Eject]** button. The step stays blocked until the drive is gone. We never ask the user to unplug a mounted drive.
- **Result step:** a verdict line, the A/B/C comparison grid (✓ on the best row), "Ruled out:" with reasons, and "Confidence: High / Medium / Low". Confidence is a word, never a percentage, and applies to the named claim (WhatCable `DiagnosticPresentation.swift`). The buttons are **[Save to Reports]** and **[Done]** (prominent).
- **Keyboard:** Return = the default action · ⌘[ = Back · Esc = Cancel Test. After step 1, Esc asks "Stop the test? Readings so far will be discarded." (Stop Test / Keep Going).
- **Motion:** the live dot pulses, and is static under Reduce Motion. Steps cross-fade with `Motion.standard`.
- **Accessibility:** announce each captured reading with `AccessibilityNotification.Announcement("Reading captured: 10 gigabits per second").post()`.

### 3.6 PermissionRow

```swift
// PROPOSAL
enum PermissionKind: CaseIterable { case fullDiskAccess, notifications }   // title, reason, usedBy, requirement, symbol
enum PermissionStatus: Equatable { case granted, notGranted, waiting, needsRelaunch, unknown }

struct PermissionRow: View {
    let kind: PermissionKind
    let status: PermissionStatus
    var number: Int? = nil          // shown as a step badge in onboarding; nil in Settings
    var onOpenSettings: () -> Void
    var onRelaunch: () -> Void
    var onRecheck: () -> Void
}
```

```text
┌──────────────────────────────────────────────────────────────────────┐
│ (1) Full Disk Access   Recommended          [ Open System Settings ] │
│     Reason, one line.  Used by iCloud Rescue, Upgrade Readiness      │
└──────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────┐
│ (1) Full Disk Access   Recommended                ◌ Waiting for you… │
│     System Settings › Privacy & Security › Full Disk Access          │
└──────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────┐
│ ✓   Full Disk Access   Recommended                         ✓ Granted │
└──────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────┐
│ (1) Full Disk Access   Recommended              [ Relaunch AppName ] │
│     macOS applies this after AppName restarts.                       │
└──────────────────────────────────────────────────────────────────────┘
```

- **Row layout:** a leading number badge (24 pt circle) that becomes `checkmark.circle.fill` in green once the permission is granted. In Settings the badge is replaced by a `kind.symbol` tile. Next come the title (`.headline`), a requirement chip ("Recommended" or "Optional"), a one-line reason (`meta`), and "Used by: …" (`caption`).
- **Trailing control by status:**
  - `notGranted`: **[Open System Settings]**, bordered.
  - `waiting`: a small spinner, "Waiting for you…", and the exact path as a caption.
  - `granted`: `Label("Granted", systemImage: "checkmark")` in green.
  - `needsRelaunch`: **[Relaunch AppName]**.
  - `unknown`: "Couldn't confirm" with **[Check Again]**.
- **Detecting Full Disk Access:** there is no API for it, so probe TCC-protected paths that exist, and return granted, not granted or unknown. Mole's `has_full_disk_access` in `lib/core/ui.sh` stats Safari, Mail and Messages paths the same way. We reimplement the idea.
- **Polling:** after "Open System Settings", poll every 1 s for 60 s (VoiceInk) and again on `NSApplication.didBecomeActiveNotification`. Stop the moment the permission is granted. Never show a modal alert and never tell the user to "quit and reopen", which is the Recordly anti-pattern. Only show `needsRelaunch` when the probe still fails after the user has toggled the permission and come back.
- **Deep links and path strings** live in one table, `Support/SettingsLinks.swift`, and every entry must be verified on 14, 15, 26 and 27. If a link fails, open System Settings at its root.
  - Full Disk Access: `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`, path "System Settings › Privacy & Security › Full Disk Access".
  - Notifications: `x-apple.systempreferences:com.apple.preference.notifications`.
  - These anchors are undocumented. Rectangle's source shows macOS 27 renamed the Accessibility pane to "Device Control and Data Access" (`AccessibilityView.swift` L56-62), so branch the path copy with `#available(macOS 27, *)` as needed.
- **Accessibility:** label the row "Full Disk Access, recommended, not granted". Its action is "Open System Settings".

### 3.7 EmptyState (presets over ContentUnavailableView)

Keep the copy consistent by always using these presets; never build an empty state by hand. Don't use `ContentUnavailableView` for locked features. A locked feature shows its real UI with lock badges.

```swift
// PROPOSAL (two cases shown; the rest follow the table)
enum EmptyState: View {
    case neverScanned(scan: () -> Void)
    case noSearchResults(query: String, clear: () -> Void)
    // …allClear, nothingConnected, unavailable, failed

    var body: some View {
        switch self {
        case .neverScanned(let scan):
            ContentUnavailableView {
                Label("No Scan Yet", systemImage: "stethoscope")
            } description: {
                Text("A full check takes about 20 seconds and changes nothing on your Mac.")
            } actions: {
                Button("Run First Scan", action: scan).buttonStyle(.borderedProminent)
            }
        case .noSearchResults(let query, let clear):
            ContentUnavailableView {
                Label("No Results for “\(query)”", systemImage: "magnifyingglass")
            } description: {
                Text("Check the spelling or try a different name.")
            } actions: {
                Button("Clear Search", action: clear)
            }
        }
    }
}
```

| Preset | Title | Symbol | Description | Action |
|---|---|---|---|---|
| `neverScanned` | No Scan Yet | `stethoscope` | A full check takes about 20 seconds and changes nothing on your Mac. | **Run First Scan** |
| `allClear(.icloud)` | No Stuck Files | `checkmark.icloud` | Everything in iCloud Drive is up to date. | Scan Again |
| `allClear(.upgrade)` | Nothing to Fix First | `checkmark.circle` | Nothing we checked should get in the way of macOS 27. | Scan Again |
| `nothingConnected` | Nothing Connected | `cable.connector` | Connect a dock, display or drive and AppName checks it automatically. | Scan Again |
| `timelineEmpty` | No Events Yet | `list.bullet.rectangle` | Connections, drop-outs and speed changes appear here. Keep AppName in the menu bar to catch problems overnight. | Show in Menu Bar (only if it's off) |
| `noSearchResults` | No Results for “q” | `magnifyingglass` | Check the spelling or try a different name. | Clear Search |
| `unavailable(icloudOff)` | iCloud Drive Is Off | `icloud.slash` | Turn it on in System Settings › Apple Account › iCloud to check your files. | Open iCloud Settings |
| `failed` | Check Didn't Finish | `exclamationmark.circle` | *(the specific reason)* | Try Again · Copy Details |

### 3.8 ScanProgress (the ScanCapsule and the inline variant)

```swift
// PROPOSAL
struct ScanProgressModel: Equatable {
    let phaseTitle: String        // "Reading USB-C and Thunderbolt ports"
    let detail: String            // "This takes a few seconds"
    let fraction: Double?         // nil = indeterminate; always shown clamped to ≤ 0.99 until finished
    let step: Int
    let stepCount: Int
}

struct ScanCapsule: View {
    let progress: ScanProgressModel
    var onStop: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        HStack(spacing: Space.s) {
            if let f = progress.fraction {
                ProgressView(value: min(f, 0.99)).frame(width: 64)
            } else {
                ProgressView().controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.phaseTitle).font(.callout.weight(.semibold))
                    .foregroundStyle(appearsActive ? .primary : .secondary)
                Text(progress.detail).font(.caption).foregroundStyle(.secondary)
            }
            .contentTransition(.opacity)
            Spacer(minLength: Space.s)
            Text("\(progress.step) of \(progress.stepCount)")
                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
            Button("Stop Scan", systemImage: "xmark", action: onStop)   // ⌘. lives in the Scan menu
                .labelStyle(.iconOnly).buttonStyle(.borderless)
                .help("Stop Scan (⌘.)")
        }
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
        .frame(width: 380)                                     // fixed: phase text changes never resize it
        .controlGlass(in: Capsule())
        .animation(Motion.standard(reduceMotion), value: progress)
        .padding(.bottom, Space.l)
    }
}
```

- **Placement:** the capsule floats at bottom center of the detail column, only while a scan runs. It enters with `.move(edge: .bottom).combined(with: .opacity)`, or `.opacity` under Reduce Motion. This is Recordly's idea of one launch surface that changes state; the values are ours.
- **Finish:** when the scan finishes, the capsule shows `✓ Done · 18 s` for 1.2 s and then leaves.
- **Inline variant:** used inside sheets such as the Rescue sheet and Upgrade export. It shows the same content without glass, as a full-width `ProgressView` with text and a per-item outcome list.
- **No layout jumps, no blank states:**
  - Swap phase text in place.
  - Device nodes keep a skeleton until their readings settle. The settling window defaults to 6 s and is tuned per check (WhatCable waits 6 s for the e-marker).
  - Never flash "Problem found" before readings are stable.
- **Phase copy:** Reading USB-C and Thunderbolt ports · Checking displays · Checking connected drives · Looking at iCloud Drive · Checking apps for macOS 27 · Putting the report together.
- **Keyboard:** ⌘. stops the scan at the next safe point, and ⌘R starts a new scan (disabled while one is running).
- **Accessibility:** use `.accessibilityElement(children: .contain)` with the label "Scanning, step 2 of 5, reading USB-C ports". Announce only the start and the finish.

### 3.9 LicenseBadge

```swift
// PROPOSAL
enum LicenseState: Equatable {
    case trial(daysLeft: Int)
    case trialExpired
    case licensed(activationsUsed: Int, limit: Int?)
    case offlineGrace(daysLeft: Int)      // couldn't re-validate; still unlocked
    case revoked                           // refunded or disabled key
}

struct LicenseBadge: View {
    let state: LicenseState
    var onTap: () -> Void                 // opens the License sheet (§4.6)
}
```

| State | Sidebar badge | Tone |
|---|---|---|
| `trial(d)` where d > 2 | `key` + "Trial · 9 days left" | `.secondary` |
| `trial(d)` where d ≤ 2 | `clock` in orange + "Trial · 2 days left" | warning symbol, text stays primary |
| `trialExpired` | `lock` + "Trial ended · Unlock" | primary, `.link` style |
| `offlineGrace(d)` where d < 7 | `wifi.exclamationmark` + "License check pending" | `.secondary` |
| `revoked` | `exclamationmark.circle` + "License inactive" | `.secondary` |
| `licensed` | not rendered | n/a (Settings › License shows "Lifetime · 2 of 3 Macs") |

The badge is a plain `Button` with `.buttonStyle(.plain)`, a hover fill, and the accessibility label "Trial, 9 days left. Opens license options."

### 3.10 Supporting pieces

- **`IconTile(symbol:color:size:)`:** a rounded square (`Radius.control` at ≤ 24 pt, `Radius.hero` at 64 pt) filled with a system color and holding a white `.semibold` symbol. It is used only on Overview module cards and onboarding headers. VoiceInk's `SidebarIconTile` inspired it; build it without the gloss strip.
- **`TopologyView(ports: [PortNode], selection: Binding<DeviceID?>)`:**
  - One row per Mac port, drawn as a horizontal chain `Mac port → cable → device`. Devices behind a dock are listed as a tree below the dock.
  - Each `DeviceNode` is a `Button` card (`Radius.row`), about 150–190 pt wide, with a name (`.headline`, `.truncationMode(.middle)`), a spec line (`meta`) and a live chip.
  - The live chip shows "10 of 40 Gb/s" or "30 of 60 Hz" with the severity tint. It is the same idea as Recordly's live level meter on each mic row.
  - The hop where speed drops is drawn with a dashed stroke in the severity color, with the chip on the line.
  - Disconnected devices stay visible at 40% opacity with "Disconnected 2 min ago" for 5 minutes.
  - When the chain doesn't fit, `ViewThatFits` switches it to a vertical layout.
  - Every node's accessibility label is a full sentence, for example "CalDigit TS4, Thunderbolt dock, connected at 10 of 40 gigabits per second, worth a look."
- **`EvidenceList(evidence:)`:** the grouped provenance list used by FindingCard and the inspector.
- **`CheckRow(outcome:title:detail:)`:** a row in the "All checks (N)" disclosure at the bottom of each module.
- **`SectionHeader(title:trailing:)`:** `.headline` title with an optional trailing link-style button ("Show All ›").

### 3.11 Keyboard map

| Action | Shortcut | Where |
|---|---|---|
| Scan Again (full scan) | ⌘R | Scan menu, toolbar |
| Stop Scan | ⌘. | Scan menu |
| Record a Problem / Stop Recording | ⇧⌘R | Scan menu, Timeline |
| Copy Diagnostic Report | ⇧⌘C | Scan menu, Share menu |
| Export Report… | ⇧⌘E | Scan menu, Share menu |
| Overview … Reports | ⌘1 … ⌘5 | View menu (`CommandGroup(before: .sidebar)`) |
| Show/Hide Sidebar, Inspector | system (`SidebarCommands`, `InspectorCommands`) | View menu |
| Find | ⌘F | iCloud Rescue, Upgrade, Reports (`.searchable`) |
| Select all / toggle one stuck file | ⌘A / Space | iCloud Rescue table |
| Rescue Selected… | ⌘↩ | iCloud Rescue bottom bar |
| Guided test: Continue / Back / Cancel | ↩ / ⌘[ / Esc | Guided Test |
| Settings | ⌘, | App menu |

- **Destructive buttons never get a shortcut** and are never the default button.
- **Every destructive confirmation has no default button:** Return does nothing and Esc cancels.
- **Stray keypresses:** the destructive button stays disabled for 0.5 s after its sheet appears, so a key typed before the sheet opened can't confirm it (Mole issue #726, `drain_pending_input`).

```swift
// PROPOSAL: App/AppCommands.swift
struct AppCommands: Commands {
    let store: AppStore
    var body: some Commands {
        CommandGroup(replacing: .newItem) {}                         // no File › New
        CommandGroup(after: .appInfo) { CheckForUpdatesButton() }    // Sparkle, §6
        SidebarCommands()
        InspectorCommands()
        CommandMenu("Scan") {
            Button("Scan Again", systemImage: "arrow.clockwise") { store.scan() }
                .keyboardShortcut("r").disabled(store.isScanning)
            Button("Stop Scan", systemImage: "xmark") { store.cancelScan() }
                .keyboardShortcut(".").disabled(!store.isScanning)
            Divider()
            Button(store.isRecording ? "Stop Recording" : "Record a Problem", systemImage: "record.circle") {
                store.toggleRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            Divider()
            Button("Copy Diagnostic Report", systemImage: "doc.on.doc") { store.copyReport() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Export Report…", systemImage: "square.and.arrow.up") { store.exportReport() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}
```

If menu item state doesn't update because `Commands` doesn't observe the store on 14, publish `isScanning` through `.focusedSceneValue` instead.

---

## 4. Wireframes

**Legend:**
- `[ Button ]` is a bordered button and `[[ Button ]]` is the screen's single prominent button.
- Status marks: `✓` ok, `ⓘ` info, `▲` warning, `✕` critical, `?` unknown, `⊘` check didn't finish, `●` live or status dot, `◌` in progress.
- Controls: `▸`/`▾` disclosure, `[x]`/`[ ]` checkbox, `◧` sidebar toggle, `▣` inspector toggle, `⎘` share menu, `⋯` more.
- An UPPERCASE segment in a segmented control is the selected one.
- `[D] [C] [U]` stand for icon tiles and `▢` for app icons.
- A double-line box marks the selected topology node.

### 4.1 Overview

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●   ◧   Overview                                                 ⎘ ▾    ▣    [[ ↻ Scan Again ]] │
├────────────────────────┬────────────────────────────────────────────────────────────────────────────┤
│                        │                                                                            │
│ ◉ Overview             │ ┌────────────────────────────────────────────────────────────────────────┐ │
│                        │ │                                                                        │ │
│ Checks                 │ │  ▲  Worth a Look                                                       │ │
│   Dock & Display     2 │ │     Your dock is connected at USB speed, not Thunderbolt.              │ │
│   iCloud Rescue      1 │ │     Checked 24 · 2 need attention · 1 couldn't be checked              │ │
│   Upgrade Readiness    │ │     Scanned 2 min ago · took 18 s                        [ Review › ]  │ │
│                        │ │                                                                        │ │
│ History                │ └────────────────────────────────────────────────────────────────────────┘ │
│   Reports              │                                                                            │
│                        │ ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐ │
│                        │ │ [D] Dock & Display   │ │ [C] iCloud Rescue    │ │ [U] Upgrade Readiness│ │
│                        │ │ ▲ 2 need attention   │ │ ▲ 14 files waiting   │ │ ✓ Ready for macOS 27 │ │
│                        │ │ 3 devices · ● live   │ │ Syncing · 41 GB free │ │ 2 things to check    │ │
│                        │ └──────────────────────┘ └──────────────────────┘ └──────────────────────┘ │
│                        │                                                                            │
│                        │  Needs your attention                                          Show All ›  │
│                        │ ┌────────────────────────────────────────────────────────────────────────┐ │
│                        │ │ ▲ Your dock is connected at USB speed, not Thunderbolt               › │ │
│                        │ │   10 of 40 Gb/s · CalDigit TS4 · left USB-C port                       │ │
│                        │ ├────────────────────────────────────────────────────────────────────────┤ │
│                        │ │ ▲ 14 files haven't uploaded to iCloud in 3 days                      › │ │
│                        │ │   At least 2.3 GB · waiting since 24 Sep                               │ │
│                        │ └────────────────────────────────────────────────────────────────────────┘ │
│                        │                                                                            │
│                        │  Recent events                                            Open Timeline ›  │
│                        │    ▲  Link: 40 Gb/s → 10 Gb/s    CalDigit TS4 · left port       14:02:31   │
│                        │    ·  Mac woke from sleep                                       14:02:05   │
│ ────────────────────── │                                                                            │
│ Trial · 9 days left  › │  Everything stays on this Mac.                            [ Copy Report ]  │
│                        │                                                                            │
└────────────────────────┴────────────────────────────────────────────────────────────────────────────┘
```

- **Layout:** the hero comes first, then three module cards (`LazyVGrid(columns: [.adaptive(minimum: 220)])`, `IconTile` + name + one status line + one meta line). Then "Needs your attention", which lists at most 3 compact FindingCards across all modules, with "Show All ›" opening a filtered list. Then "Recent events" (the last 2 timeline events, shown only when monitoring is on). The footer holds a trust line and **Copy Report**.
- **Healthy is quiet.** When all is clear, the "Needs your attention" section disappears. The module cards read `✓ No issues`, and nothing else is added.
- **Module card click** goes to that module. A card whose module hasn't been scanned shows "Not checked yet" in `.secondary`.
- **Hero states:**

```text
 A. Never scanned (Overview shows no cards, no lists)
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  Not checked yet                                                       │
│  A full check takes about 20 seconds and changes nothing on your Mac.  │
│                                                                        │
│  [[ Run First Scan ]]                                                  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

 B. Scanning (last result dimmed to 50%, or a redacted skeleton on first run)
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  ▲  Worth a Look                                            Updating…  │
│     Your dock is connected at USB speed, not Thunderbolt.              │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
      ╭────────────────────────────────────────────────────────────╮
      │ ◌  Reading USB-C and Thunderbolt ports      2 of 5   [ ✕ ] │
      │    ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░  This takes a few seconds        │
      ╰────────────────────────────────────────────────────────────╯

 C. Scan didn't finish (neutral, never red: this is our failure, not the Mac's)
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  ⊘  The scan didn't finish                                             │
│     iCloud Drive didn't answer in 30 s. Other results are current.     │
│     [ Try Again ]   [ Copy Details ]                                   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Dock & Display Doctor

**(a) Devices tab**, with the live topology and the inspector open on the selected dock (sidebar omitted):

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧   Dock & Display    [ DEVICES | Timeline | Guided Test ]             ⎘ ▾   ▣   [[ ↻ Scan Again ]] │
├────────────────────────────────────────────────────────────────────────┬────────────────────────────┤
│                                                                        │                            │
│ ┌────────────────────────────────────────────────────────────────────┐ │ CalDigit TS4               │
│ │ ▲ Worth a Look · 2 need attention                           ● Live │ │ Thunderbolt dock           │
│ │ Your dock is connected at USB speed, not Thunderbolt.              │ │                            │
│ └────────────────────────────────────────────────────────────────────┘ │ Measured on this Mac       │
│                                                                        │   Link             10 Gb/s │
│ Left USB-C port                                                        │   Expected         40 Gb/s │
│ ┌──────────────┐    ┌─────────────┐ 10 of 40 Gb/s  ╔═════════════════╗ │   Power to Mac        96 W │
│ │ MacBook Pro  │────│ Cable       │─ ─ ─ ─▲─ ─ ─ ─ ║ CalDigit TS4    ║ │   Connected     2 h 14 min │
│ │ USB-C port 1 │    │ USB 3 (est.)│  link too slow ║ Thunderbolt dock║ │                            │
│ └──────────────┘    └─────────────┘                ╚═════════════════╝ │ Reported by the device     │
│ Behind CalDigit TS4                                                    │   Vendor          CalDigit │
│   ├─ LG UltraFine 5K     3840×2160 · 30 of 60 Hz                   ▲   │   Firmware            64.1 │
│   ├─ Samsung T7          USB 10 Gb/s · healthy                     ✓   │                            │
│   └─ Keyboard and 1 more                                           ▸   │ Our knowledge base         │
│                                                                        │   Full speed needs a       │
│ Right USB-C port                                                       │   Thunderbolt 4 cable.     │
│ ┌──────────────┐    ┌───────────────────┐                              │                            │
│ │ MacBook Pro  │────│ Apple 96W charger │                              │ ▸ Technical details        │
│ │ USB-C port 2 │    │ charging 94 W  ✓  │                              │                            │
│ └──────────────┘    └───────────────────┘                              │ [ Copy Details ]           │
│                                                                        │                            │
│ Findings (2)                                        All checks (24) ▸  │                            │
│ ┌────────────────────────────────────────────────────────────────────┐ │                            │
│ │ ▲ Your dock is connected at USB speed, not Thunderbolt           ⋯ │ │                            │
│ │                                                                    │ │                            │
│ │   We measured a 10 Gb/s link on the left USB-C port. This dock     │ │                            │
│ │   supports 40 Gb/s. A USB 3 or charge-only cable is the most       │ │                            │
│ │   common cause.                                                    │ │                            │
│ │                                                                    │ │                            │
│ │   What to try                                                      │ │                            │
│ │   1. Use a cable marked with the Thunderbolt logo or "40 Gb/s".    │ │                            │
│ │   2. Plug the dock into the other USB-C port on your Mac.          │ │                            │
│ │   3. Still slow? Run the guided test to rule out the dock.         │ │                            │
│ │                                                                    │ │                            │
│ │   ▾ Evidence                                                       │ │                            │
│ │     Measured on this Mac     Link 10 Gb/s · port 1 (left)          │ │                            │
│ │     Reported by the device   CalDigit TS4 · firmware 64.1          │ │                            │
│ │     Our knowledge base       Full speed needs a Thunderbolt cable  │ │                            │
│ │     ▸ Technical details                                            │ │                            │
│ │                                                                    │ │                            │
│ │   [ Run Guided Test ]   Copy Details                               │ │                            │
│ │                                                                    │ │                            │
│ └────────────────────────────────────────────────────────────────────┘ │                            │
│ ┌────────────────────────────────────────────────────────────────────┐ │                            │
│ │ ▲ LG UltraFine 5K is running at 30 Hz instead of 60 Hz           ▸ │ │                            │
│ └────────────────────────────────────────────────────────────────────┘ │                            │
│                                                                        │                            │
└────────────────────────────────────────────────────────────────────────┴────────────────────────────┘
```

- **Live updates:** topology refreshes from IOKit notifications, with no polling in the UI layer. The `● Live` dot pulses and is static under Reduce Motion. If the engine hasn't delivered for 10 s, the dot turns gray and reads "Paused". Mole's status view marks stale data the same way.
- **"All checks (24) ▸"** expands into CheckRows. Healthy checks live only there.
- **Drives** show up in the tree under whatever they are plugged into. A drive that reports health failures produces a **critical** FindingCard, "Back up “Samsung T7” soon". The healthy SMART row is hidden, following Mole's `view.go` rule that a healthy state asks nothing of the user. An enclosure that hides SMART data shows `? Couldn't check drive health · the enclosure doesn't report it`, and nothing more.

**(b) Timeline tab:**

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧   Dock & Display    [ Devices | TIMELINE | Guided Test ]             ⎘ ▾   ▣   [[ ↻ Scan Again ]] │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ Range [8 hours ▾]   Device [All ▾]   Kind [All ▾]  529 events   ● Live   [ ◉ Record a Problem ] │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ● Recording · 00:41 · 12 events so far                                       [ Stop Recording ] │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ Today                                                                                               │
│   ▲  Link: 40 Gb/s → 10 Gb/s                                                        14:02:31   ›    │
│      CalDigit TS4 · left USB-C port                                                                 │
│   ·  Mac woke from sleep                                                            14:02:05        │
│   ✓  LG UltraFine 5K: 30 Hz → 60 Hz                                                 03:15:02   ›    │
│      Behind CalDigit TS4                                                                            │
│   ✕  Samsung T7 disconnected without being ejected                                  03:14:50   ›    │
│      Behind CalDigit TS4 · 2 files were open                                                        │
│   ·  Mac went to sleep                                                              01:30:00        │
│ Yesterday                                                                                           │
│   ✓  CalDigit TS4 connected at 40 Gb/s                                              18:40:12   ›    │
│      Left USB-C port                                                                                │
│                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Filters:** Range (Last hour / 8 hours / 24 hours / 7 days), Device, and Kind, with a live event count. This follows WhatPort's Flight Recorder layout, reimplemented.
- **Record a Problem** starts a session (licensed or trial). A red banner shows "● Recording · mm:ss · N events so far" and a **[Stop Recording]** button. The dot blinks and is static under Reduce Motion. When the user stops, the session is saved to Reports and a toast offers **Export Session…**.
- **Retention** is set in Settings › Monitoring (7 days by default). Notifications fire only after a condition lasts, never on a single reading. Each uses a stable ID, so a new alert replaces the old one, and the notification is removed when the condition recovers (Stats `Kit/module/notifications.swift`).

**(c) Guided Test tab, step 2:**

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧   Dock & Display    [ Devices | Timeline | GUIDED TEST ]                                 ⎘ ▾   ▣  │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│   Is it the dock, the cable, or the Mac port?                                                       │
│   4 steps · about 3 minutes · nothing on your Mac is changed                                        │
│                                                                                                     │
│   ✓ 1 Baseline ─────── ● 2 Swap the port ─────── ○ 3 Swap the cable ─────── ○ 4 Result              │
│                                                                                                     │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                                             │   │
│   │   [ illustration: laptopcomputer · arrow.right · rectangle.connected.to.line.below ]        │   │
│   │                                                                                             │   │
│   │   Unplug the dock from the left port and plug it into the right port.                       │   │
│   │   Leave everything else connected.                                                          │   │
│   │                                                                                             │   │
│   │   ✓ Samsung T7 was ejected first, so it's safe to unplug.                                   │   │
│   │   ● Waiting for the dock to reconnect…                                                      │   │
│   │     We'll move on by ourselves as soon as we see it.                                        │   │
│   │                                                                                             │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                     │
│   Readings so far              Link        Display     Link errors                                  │
│   A  Left port (original)      10 Gb/s     30 Hz       0                                            │
│   B  Right port                —           —           —                                            │
│                                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  [ Cancel Test ]                                 [ ‹ Back ]   [ Skip Step ]   [[ I've Done This ]]  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Result step:**

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧   Dock & Display    [ Devices | Timeline | GUIDED TEST ]                                 ⎘ ▾   ▣  │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│   Is it the dock, the cable, or the Mac port?                                                       │
│                                                                                                     │
│   ✓ 1 Baseline ─────── ✓ 2 Swap the port ─────── ✓ 3 Swap the cable ─────── ● 4 Result              │
│                                                                                                     │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                                             │   │
│   │  ▲  The cable is the most likely cause                                                      │   │
│   │      With the original cable the link stayed at 10 Gb/s on both ports. With a               │   │
│   │      second cable it reached 40 Gb/s and the display ran at 60 Hz.                          │   │
│   │                                                                                             │   │
│   │                               Link        Display     Link errors                           │   │
│   │      A  Original setup        10 Gb/s     30 Hz       0                                     │   │
│   │      B  Other Mac port        10 Gb/s     30 Hz       0                                     │   │
│   │      C  Other cable           40 Gb/s     60 Hz       0             ✓                       │   │
│   │                                                                                             │   │
│   │      Ruled out    Mac port: same result on both ports                                       │   │
│   │                   Dock: full speed with another cable                                       │   │
│   │      Confidence   High                                                                      │   │
│   │                                                                                             │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  [ Save to Reports ]                                                                    [[ Done ]]  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

The test catalog for v1 is small:

1. "Is it the dock, the cable, or the Mac port?"
2. "Why is my display stuck at 30 Hz?"
3. "Why does my drive disconnect?" This test records the Timeline while the user works normally, then compares the events.

### 4.3 iCloud Rescue

**(a) Stuck files list:**

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧   iCloud Rescue                          [ ⌕ Search files         ]   Show [All ▾]   ⎘ ▾   ▣   ↻  │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ▲ 14 files haven't uploaded to iCloud in 3 days                                                 │ │
│ │   They're safe on this Mac. iCloud is usually waiting because a file is open in another         │ │
│ │   app, or its name has characters iCloud doesn't accept.                                        │ │
│ │                                                                                                 │ │
│ │   iCloud Drive  On · syncing      Optimize Mac Storage  On      Free on this Mac  41 GB         │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ [-] Name  ▾                    Folder                 Size           State             Stuck since  │
│ ──────────────────────────────────────────────────────────────────────────────────────────────────  │
│ [x] Budget 2026.numbers        iCloud Drive › Finance 2.1 MB         Waiting to upload 24 Sep       │
│ [x] Trip photos.zip            Desktop                1.1 GB         Upload failed     24 Sep       │
│ [ ] Thesis draft.pages  ⓘ      Documents              At least 18 MB Open in Pages     today        │
│ [ ] Q3 report?.docx  ⓘ         Documents › Work       340 KB         Name blocks sync  25 Sep       │
│ [x] Invoice-114.pdf            Downloads              88 KB          Waiting to upload 25 Sep       │
│     9 more…                                                                                         │
│                                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 3 selected · 1.1 GB     2 left out: open or recently edited ⓘ               [[ Rescue Selected… ]]  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Table:** use a SwiftUI `Table` with sortable columns. The default sort is longest stuck first. Names truncate in the middle, so both the start and the extension stay visible (Maccy `.truncationMode(.middle)`).
- **Selection starts safe.** Files that are open in an app, edited in the last 7 days, or in an uncertain state start **unchecked**, with an `ⓘ` that explains why. This follows Mole's `classify_purge_activity`. The bottom bar keeps a live count ("3 selected · 1.1 GB") and a "2 left out" note that opens a popover listing the reasons.
- **Sizes** use `sizeLabel`, so a partial measurement reads "At least 18 MB" and never "0 KB".
- **Status strip in the hero:** iCloud Drive state, Optimize Mac Storage, and free space on this Mac. If iCloud Drive is off, the whole screen becomes `EmptyState.unavailable(icloudOff)`.
- **Without Full Disk Access** the list still works from the file-provider state we can read. An `unknown`-severity row, "Deeper check needs Full Disk Access", sits above the table and opens a PermissionRow sheet.

**(b) Rescue flow.** A sheet opened by **Rescue Selected…**, 640 pt wide, with three phases in one sheet that swap with `Motion.standard`. The exact mechanics belong to the iCloud engine spec. The UI contract is:
- Steps 1–3 are non-destructive, and the backup copy always happens first and can't be skipped.
- Any destructive step moves items to the Trash and needs its own confirmation.

Phase 1, Review (Return starts the rescue, because this phase changes nothing destructive):

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  Rescue 3 files (1.1 GB)                                                   │
│  We'll do this in order and stop if anything looks wrong.                  │
│                                                                            │
│   1  Save a copy of each file to Documents › AppName Rescue › 27 Sep       │
│   2  Ask iCloud to retry the upload                                        │
│   3  Wait up to 2 minutes, then check each file again                      │
│                                                                            │
│  Nothing is deleted. If a file still won't upload, you decide what's next. │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Budget 2026.numbers                       2.1 MB    Copy, then retry │  │
│  │ Trip photos.zip                           1.1 GB    Copy, then retry │  │
│  │ Invoice-114.pdf                            88 KB    Copy, then retry │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ▸ Left out (2)                                                            │
│      Thesis draft.pages: open in Pages. Close it and scan again.           │
│      Q3 report?.docx: its name blocks sync. Rename it first.               │
│                                                                            │
│  Needs 1.1 GB free for the copies · 41 GB available                        │
├────────────────────────────────────────────────────────────────────────────┤
│                                           [ Cancel ]   [[ Start Rescue ]]  │
└────────────────────────────────────────────────────────────────────────────┘
```

Phase 2, Running. Progress is per file and capped at 99% until every file reports back:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  Rescuing 3 files…                                                         │
│                                                                            │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░                          2 of 3  │
│                                                                            │
│   ✓ Budget 2026.numbers                                 Copied · uploaded  │
│   ◌ Trip photos.zip                          Copied · waiting for iCloud…  │
│   ○ Invoice-114.pdf                                           Not started  │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│  Stop finishes the current file first.                           [ Stop ]  │
└────────────────────────────────────────────────────────────────────────────┘
```

Phase 3, Done. Each file gets an outcome, and the user chooses the next step for anything still stuck:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  ▲ 2 of 3 files are back in sync                                           │
│    1 file is still waiting. Its copy is safe in the Rescue folder.         │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ ✓ Budget 2026.numbers                                       Uploaded │  │
│  │ ✓ Invoice-114.pdf                                           Uploaded │  │
│  │ ▲ Trip photos.zip                         Still waiting · copy saved │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  For Trip photos.zip you can:                                              │
│   [ Keep Waiting ]   [ Re-add to iCloud… ]   [ Show in Finder ]            │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│  [ Show Rescue Folder ]                                        [[ Done ]]  │
└────────────────────────────────────────────────────────────────────────────┘
```

The destructive escalation is a second sheet with no default button, and its destructive button is disabled for 0.5 s after it appears:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  Re-add “Trip photos.zip” to iCloud?                                       │
│                                                                            │
│  We'll put a fresh copy in the same folder and move the stuck              │
│  one to the Trash. Your backup stays in Documents › AppName Rescue.        │
│                                                                            │
│  You can put it back from the Trash.                                       │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│  (no default button)              [ Cancel ]   [ Move to Trash & Re-add ]  │
└────────────────────────────────────────────────────────────────────────────┘
```

- **Before acting,** re-check each file (Mole's purge re-check). A file that changed since the review is skipped, with the reason "Changed since you reviewed it".
- **Logging:** every change is written to the operation log. Reports › Changes lists it with **Put Back**, which uses the `resultingItemURL` returned by `FileManager.trashItem`. If that item is gone, it falls back to **Show Trash**.

### 4.4 Upgrade Readiness

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧   Upgrade Readiness   Target [macOS 27 ▾]  [ NEEDS ATTENTION | All ]   ⎘ ▾  ▣  [[ ↻ Scan Again ]] │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │                                                                                                 │ │
│ │ ✓  Ready for macOS 27, with 2 things to check first                                             │ │
│ │    Your MacBook Pro (14-inch, 2023) is supported. Nothing here blocks the upgrade,              │ │
│ │    but 3 apps and 1 extension may not work the same afterwards.                                 │ │
│ │                                                                                                 │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ Before you upgrade                                                                                  │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ✓ This Mac is supported        MacBook Pro (14-inch, 2023)                       Apple's list ⓘ │ │
│ │ ▲ Free space is tight          18 GB free · about 26 GB needed        [ Open Storage Settings ] │ │
│ │ ▲ Last backup was 12 days ago  Time Machine · “Backup Disk”               [ Open Time Machine ] │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ Apps built only for Intel (3)                                                                   ▾   │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ▢ OldScanner 2.1               Intel only · runs through Rosetta today       [ Show in Finder ] │ │
│ │ ▢ LabelMaker Pro 5             Intel only · from the Mac App Store           [ Open App Store ] │ │
│ │ ▢ 1 more                                                                                      ▸ │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ Extensions & plug-ins (2)                                                                       ▾   │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ▢ Legacy Audio Driver          Kernel extension · may not load on macOS 27   [ Show in Finder ] │ │
│ │ ▢ ReverbX.component            Audio plug-in · Intel only                    [ Show in Finder ] │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ Couldn't check (1)                                                                              ▾   │
│ ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ? Other users' apps            Needs Full Disk Access                                [ Grant… ] │ │
│ └─────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                     │
│ Requirements from apple.com, checked 12 Sep 2026.                    [ Export Readiness Report… ]   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Target:** the Target menu lists the next major macOS and the latest point release. By default the screen shows **Needs Attention** only; "All" adds the passed rows.
- **Hero verdict:** "Ready for macOS 27, with 2 things to check first", "Ready for macOS 27", or "Not ready yet: 1 thing blocks the upgrade". Only a real blocker, such as an unsupported Mac or too little space to install, makes it critical. Intel-only apps are **warning** at most, and the copy says they still run today (§5, string 9).
- **Rows:** each row shows the app icon (`NSWorkspace.shared.icon(forFile:)`, cached by bundle ID as Maccy does), name + version, a badge with the issue, and a provenance tooltip on `ⓘ`. The row action is **Show in Finder**, or **Open App Store** for Mac App Store apps. We never claim that an update exists unless our knowledge base says so.
- **Grouping:** Before you upgrade (Mac supported, free space, last backup), Apps built only for Intel, Extensions & plug-ins (kernel extensions, system extensions, audio plug-ins), Login & background items, and Couldn't check.
- **Freshness:** the footer states how fresh the knowledge base is ("checked 12 Sep 2026") next to **Export Readiness Report…**.

### 4.5 Onboarding (720 × 560, in the main window)

Step 1, Welcome:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                                                                          │
│                                ┌────────┐                                │
│                                │  icon  │                                │
│                                └────────┘                                │
│                                                                          │
│                            Welcome to AppName                            │
│         Find out why your dock, display, drives or iCloud Drive          │
│                     misbehave, and fix them safely.                      │
│                                                                          │
│    [D]  Dock & Display      Topology, speeds and a live event timeline   │
│    [C]  iCloud Rescue       Finds files stuck uploading and rescues them │
│    [U]  Upgrade Readiness   What might break before you install macOS    │
│                                                                          │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ● ○ ○ ○                                                 [[ Continue ]]  │
└──────────────────────────────────────────────────────────────────────────┘
```

Step 2, Your data (the trust screen comes **before** any ask, as VoiceInk's `OnboardingTrustScreen.swift` does):

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                           [ lock.shield tile ]                           │
│                                                                          │
│                   Your Mac's details stay on your Mac                    │
│      Here's exactly what AppName looks at, and what it never does.       │
│                                                                          │
│    What AppName reads                  What AppName never does           │
│    ✓ Connected devices and speeds      – Upload your files or reports    │
│    ✓ Display and drive status          – Send analytics or tracking      │
│    ✓ iCloud Drive sync state           – Change anything without asking  │
│    ✓ App and extension versions        – Delete files (Trash only)       │
│                                                                          │
│    AppName goes online only to check for updates and your license.       │
│    How we keep your data safe ›                                          │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ○ ● ○ ○                                      [ Back ]   [[ Continue ]]  │
└──────────────────────────────────────────────────────────────────────────┘
```

Step 3, Permissions. Full Disk Access is shown in its `waiting` state; the full state set is in §3.6:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                         Two optional permissions                         │
│     Everything works without them. A few checks go deeper with them.     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ (1) Full Disk Access    Recommended            ◌ Waiting for you…  │  │
│  │     Lets AppName read iCloud Drive's sync records. It only reads.  │  │
│  │     System Settings › Privacy & Security › Full Disk Access        │  │
│  │     If macOS asks to quit and reopen AppName, choose Quit & Reopen.│  │
│  └────────────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ (2) Notifications       Optional                        [ Allow ]  │  │
│  │     Tells you when a dock or drive drops out while you're away.    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│    [x] Show AppName in the menu bar                                      │
│        Keeps watching for dock, display and drive drop-outs.             │
│    [ ] Open AppName at login                                             │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ○ ○ ● ○                                      [ Back ]   [[ Continue ]]  │
└──────────────────────────────────────────────────────────────────────────┘
```

Step 4, Ready:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                         [ checkmark.seal tile ]                          │
│                                                                          │
│                              You're all set                              │
│          Your 14-day trial has started. Everything is unlocked.          │
│                                                                          │
│                    What brought you here? (optional)                     │
│           ( Dock or display trouble )  ( iCloud files stuck )            │
│                ( Planning an upgrade )  ( Just checking )                │
│                                                                          │
│                           [[ Run First Scan ]]                           │
│                                                                          │
│                Already bought AppName?  Enter License Key                │
│                                                                          │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ○ ○ ○ ●                                                       [ Back ]  │
└──────────────────────────────────────────────────────────────────────────┘
```

- **Welcome:** the icon is the 96 pt app icon.
- **Your data:** "How we keep your data safe ›" opens the public safety page, our equivalent of Mole's SECURITY_DESIGN.md. It is a selling point.
- **Permissions:** clicking **Continue** without granting Full Disk Access is fine. The Ready step then adds one line: "You can turn on Full Disk Access later in Settings › Privacy."
- **Ready:** the choice chips are single-select and optional. **Run First Scan** marks onboarding `complete`, switches the window to MainView, and starts a scan. "Enter License Key" opens the License sheet on top of MainView.

### 4.6 License

Settings › License during the trial (this is `LicenseView`; the sheet reuses it):

```text
┌──────────────────────────────────────────────────────────────┐
│   General   Monitoring   Privacy   [ LICENSE ]   Advanced    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │                                                          │ │
│ │  ┌──────┐   AppName Lifetime License                     │ │
│ │  │ icon │   Trial · 9 days left                          │ │
│ │  └──────┘   One payment. Free updates. No subscription.  │ │
│ │                                                          │ │
│ │  ✓ Scans, findings and guided tests stay free            │ │
│ │  ✓ Unlocks rescues, monitoring and report exports        │ │
│ │  ✓ 14-day refund                                         │ │
│ │                                                          │ │
│ │  [[ Buy License… ]]                                      │ │
│ │                                                          │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ Have a license key?                                          │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ [ Paste your license key          ]         [ Activate ] │ │
│ │ It's in your purchase email.   Lost it? Recover Key ›    │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

Licensed:

```text
┌──────────────────────────────────────────────────────────────┐
│   General   Monitoring   Privacy   [ LICENSE ]   Advanced    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │                                                          │ │
│ │  ✓ Licensed · Lifetime                                   │ │
│ │    Activated on this Mac · 2 of 3 Macs in use            │ │
│ │    Key  •••• •••• •••• 7F3A                    [ Copy ]  │ │
│ │    Version 1.4.2 (142) · updates included for life       │ │
│ │                                                          │ │
│ ├──────────────────────────────────────────────────────────┤ │
│ │  [ Manage License… ]           [ Deactivate This Mac… ]  │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

The License sheet, opened from a locked action after the trial ends (480 pt wide):

```text
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  ┌──────┐   Unlock iCloud Rescue                                   │
│  │ icon │   Your trial has ended. Scans and findings stay free;    │
│  └──────┘   rescues, monitoring and exports need a license.        │
│                                                                    │
│   ( 1 Mac  $— )     ( 2 Macs  $— )     ( 3 Macs  $— )              │
│   Prices and seat counts come from config, never hard-coded.       │
│                                                                    │
│   [[ Buy License… ]]     [ Enter License Key… ]                    │
│                                                                    │
│   One-time purchase · free updates · 14-day refund                 │
├────────────────────────────────────────────────────────────────────┤
│                                                       [ Not Now ]  │
└────────────────────────────────────────────────────────────────────┘
```

An activation error, shown inline under the key field and never in an alert:

```text
 ┌──────────────────────────────────────────────────────────┐
 │ [ 7F3A-91C2-…                     ]    [ ◌ Activating… ] │
 └──────────────────────────────────────────────────────────┘
 ▲ This key is already in use on the maximum number of Macs. Deactivate it on
   another Mac, or contact support if you no longer have that Mac.
   [ Contact Support… ]
```

- **Key field:** `.font(.body.monospaced())`, trims whitespace, and doesn't change case. **Activate** stays disabled while the field is empty. While working it shows "◌ Activating…" and disables the field.
- **Activation errors,** each saying what to do next (the mapping follows VoiceInk `LicenseViewModel.swift`):

| Case | Message |
|---|---|
| 404 | "We couldn't find that key. Check for typos, or copy it again from your purchase email." |
| 403 | "This key is already in use on the maximum number of Macs. Deactivate it on another Mac, or contact support if you no longer have that Mac." A **Contact Support…** button (`Links.support`, the site's support page) sits under every activation error. |
| Revoked | "This key has been turned off. If you think that's a mistake, contact support." |
| Network | "Can't reach the license server. Check your connection and try again." |

- **Success:** `checkmark.seal.fill` bounces once (static under Reduce Motion) and the view shows "Thanks! AppName is unlocked on this Mac." There is no confetti.
- **Deactivate This Mac…** asks for confirmation. Title: "Deactivate this Mac?" Message: "This frees one of your 3 activations so you can use AppName on another Mac. Scans stay free here." Buttons: Deactivate (destructive) and Cancel. If saving to the Keychain fails after a successful activation, call deactivate so the customer doesn't lose a seat (VoiceInk `activateAndPersistLicense`).
- **The masked key** copies on click. A "Copied" capsule slides in for 1.5 s, or fades under Reduce Motion.
- **Links:** **Manage License…** opens the Polar customer portal URL from config, and "Recover Key ›" opens the portal's request page.

### 4.7 Settings (reference layout)

Every tab uses the same form grammar. General is shown as the example:

```text
┌──────────────────────────────────────────────────────────────┐
│   [ GENERAL ]   Monitoring   Privacy   License   Advanced    │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Open AppName at login                             [on] │  │
│  │ Needed to watch for drop-outs while you're away.       │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ Show AppName in the menu bar                      [on] │  │
│  │ A quick look at docks, displays, drives and iCloud.    │  │
│  └────────────────────────────────────────────────────────┘  │
│  Updates                                                     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Automatically check for updates                   [on] │  │
│  │ [ Check for Updates… ]                  v1.4.2 (142)   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 4.8 Menu bar panel (320 pt), attention state

```text
┌────────────────────────────────────────────┐
│ ◉ AppName              ▲ 1 needs attention │
│   Last check 4 min ago · watching          │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │ ▲ Dock at USB speed, not Thunderbolt › │ │
│ └────────────────────────────────────────┘ │
├────────────────────────────────────────────┤
│ CONNECTED                                  │
│ ● CalDigit TS4            10 of 40 Gb/s  › │
│ ● LG UltraFine 5K                 30 Hz  › │
│ ● Samsung T7                    10 Gb/s  › │
│ ICLOUD DRIVE                               │
│ ● Syncing                    14 waiting  › │
├────────────────────────────────────────────┤
│ [[ Run Quick Check ]]                      │
├────────────────────────────────────────────┤
│ Open AppName                               │
│ Settings…                              ⌘,  │
│ Quit AppName                           ⌘Q  │
└────────────────────────────────────────────┘
```

In the all-clear state the header reads `✓ All clear`, the finding card is gone, and nothing else changes. Idle ports stay in the list at `.tertiary` with a gray dot, so the panel never jumps (WhatPort `screenshot-list.webp`).

### 4.9 Reports (no separate wireframe)

- **Layout:** a two-column layout inside the detail pane. On the left is a `List` of entries grouped by kind: Scans, Guided tests, Recorded sessions, and Changes (the operation log). On the right is the rendered report, read-only with `.textSelection(.enabled)`.
- **Export sheet:** export opens a preview sheet showing the **exact** text or JSON that will be written, in a monospaced scroll view about 240 pt tall. Below it are two toggles:
  - "Hide file and volume names": on by default.
  - "Include Mac model and macOS version": on by default. We need it to diagnose docks, and it is not personal data.
  
  Serial numbers are never included, and there is no toggle for them. The footer reads: "Nothing is sent anywhere. You choose where to paste or attach it." This follows the WhatCable `CableReportSheet.swift` anatomy.
- **Email Support…** opens `NSSharingService(named: .composeEmail)` with the previewed report attached. If that service isn't available, it copies the report and opens a `mailto:` link (VoiceInk `EmailSupport.swift` pattern).

---

## 5. Copywriting

### 5.1 Tone rules

1. **Verdict first, in plain words.** Numbers come second and jargon comes last, behind Technical details. Write "Your display is running at 30 Hz instead of 60 Hz", not "DP link rate HBR2 insufficient".
2. **Never alarmist.** Don't use "danger", "fatal", "corrupted", "infected", "failed!", exclamation marks or ALL CAPS. Keep "Back up now" for real data-loss risk.
3. **Always explain why, then what to try, then when to escalate.** Follow WhatCable's order: what we measured, what can cause it, steps in order, when to go further (for example "If it keeps happening, try Apple Diagnostics.").
4. **Don't blame what we can't prove.** Write "most likely", "looks like" and "usually". Say when something is probably a symptom. Never write "your cable is fake", only "this cable reports unusual details".
5. **Be honest about measurements.** Write "At least 2.3 GB", "Unknown: the enclosure doesn't report it", and "Couldn't check, because…". Never write `0`, `N/A`, or a bare "Error".
6. **Say what we will and won't do before doing it.** "Nothing is deleted. Items go to the Trash." "This only reads."
7. **Keep healthy states short and calm.** "All clear. Checked 24 things; nothing needs your attention." Don't congratulate.
8. **Voice:** second person, active voice, contractions allowed. Don't write "please", "oops", "uh-oh" or emoji. Don't use "we" for things the Mac did.
9. **Capitalization:** buttons, menu items, window titles and section headers use title case, verb first, at most 3 words ("Run Guided Test", "Move to Trash"). Finding titles and body text use sentence case.
10. **Length limits:** finding titles are at most 60 characters, explanations at most 3 sentences, "What to try" at most 4 steps, and settings captions one line.
11. **Units:** "40 Gb/s", "60 Hz", "96 W", "2.1 GB" (`ByteCountFormatter`), and "24 Sep" or "3 days ago" through the date formatters. Numbers are always localized, and live ones use monospaced digits.
12. **License copy never guilt-trips.** Always state what stays free. Write "Not Now", never "No thanks, I like broken docks".

| Don't | Do |
|---|---|
| "ERROR: USB link degraded!" | "Your dock is connected at USB speed, not Thunderbolt" |
| "Drive status: N/A" | "Couldn't check drive health. The enclosure doesn't report it, which is common and not a fault." |
| "0 KB" (partial scan) | "At least 18 MB" |
| "Your cable is fake" | "This cable reports details we don't usually see. Try a different cable to compare." |
| "Delete 3 files?" | "Move 3 files (1.1 GB) to the Trash? You can put them back from the Trash." |

### 5.2 Ten example strings

| # | Where | String |
|---|---|---|
| 1 | Finding, warning (dock) | **Your dock is connected at USB speed, not Thunderbolt** · "We measured a 10 Gb/s link on the left USB-C port. This dock supports 40 Gb/s. A USB 3 or charge-only cable is the most common cause." |
| 2 | Finding, warning (display) | **Your display is running at 30 Hz instead of 60 Hz** · "The dock is sending a 4K signal over a link that can't carry 60 Hz. Connecting the display straight to your Mac, or using a Thunderbolt cable for the dock, usually fixes it." |
| 3 | Finding, critical (drive) | **“Samsung T7” is reporting disk errors** · "The drive's own health check says it's failing. Your files can still be read today, but that can change without warning. Copy anything important to another drive, then replace this one." Primary action: **Back Up Now** |
| 4 | Finding, warning (iCloud) | **14 files haven't uploaded to iCloud in 3 days** · "They're safe on this Mac. iCloud is usually waiting because a file is open in another app, or its name has characters iCloud doesn't accept." |
| 5 | Unknown / unavailable | "Couldn't check drive health. The enclosure doesn't pass health data through. That's common and not a fault." |
| 6 | Symptom note | "WindowServer is busy, but that's usually a symptom, not the cause. The display setting above is the more likely culprit." |
| 7 | Hero, all clear | **All Clear** · "Checked 24 things. Nothing needs your attention." |
| 8 | Destructive confirmation | **Re-add “Trip photos.zip” to iCloud?** · "We'll put a fresh copy in the same folder and move the stuck one to the Trash. Your backup stays in Documents › AppName Rescue. You can put it back from the Trash." |
| 9 | Upgrade, Intel-only app | "“OldScanner” is built for Intel Macs only. It runs today through Rosetta, but Apple has said Rosetta will be limited in future versions of macOS. Check whether the developer offers an Apple silicon version." *(Re-check Apple's current Rosetta wording before shipping.)* |
| 10 | Trial ended | "Your trial has ended. Scans, findings and guided tests stay free. Rescues, monitoring and exports need a license." |

Scan phases, permission reasons, empty states and license errors are written out in §3.6–§3.8 and §4.6. Use those strings exactly as written.

---

## 6. Third-party packages and licenses

### 6.1 Packages

We prefer native APIs and add one package.

| Package | Use | License | Decision |
|---|---|---|---|
| **Sparkle 2** (`sparkle-project/Sparkle`) | Updates, with an EdDSA-signed appcast | MIT | **Use.** Set `supportsGentleScheduledUpdateReminders = true` (Rectangle `AppDelegate.swift` L676-695), so no update window appears in the middle of a task. See the notes after this table. |
| Swift Charts | Link-speed and power sparklines, iCloud backlog | Apple SDK | **Use** (it's a system framework). Every chart gets a title plus a one-line takeaway, zero-based bars, and accessibility labels with real values. |
| sindresorhus/KeyboardShortcuts | Global hotkey | MIT | **Skip in v1.** There is no global hotkey. Add it if we add a quick panel (§1.4). |
| sindresorhus/LaunchAtLogin-Modern | Login item | MIT | **Skip.** `SMAppService.mainApp.register()` is one line. |
| sindresorhus/Defaults | Preferences | MIT | **Skip.** `@AppStorage` covers about 12 keys. |
| sindresorhus/Settings | Toolbar settings window | MIT | **Skip.** The SwiftUI `Settings` scene with `TabView` is native on 14+. |
| Polar SDK | Licensing | n/a | **Skip.** Three POST endpoints over `URLSession`, following the contract in VoiceInk `PolarService.swift`. The endpoint facts aren't covered by its license, but write our own client. |
| Confetti or Lottie | Celebration | n/a | **Skip.** A single `symbolEffect(.bounce)` is enough. |
| Any analytics SDK | n/a | n/a | **Never.** "No telemetry" is a product promise (§4.5). |

Sparkle notes:
- Show "Update Available" as a sidebar chip and as a renamed menu item ("Update Available…").
- The "Check for Updates…" menu item follows the `canCheckForUpdates` publisher pattern.
- Bridge `automaticallyChecksForUpdates` into a SwiftUI `Toggle` with an `@Observable` wrapper (Maccy `SoftwareUpdater.swift`).
- Ship non-sandboxed, notarized, with the hardened runtime, because IOKit and diagnostics access need it. That removes the need for Maccy's `-spks`/`-spki` sandbox exceptions.

### 6.2 License hygiene

- **Never copy code** from Mole (tw93/Mole, GPL-3.0; its name is also trademarked), Recordly (AGPL-3.0, with a branding clause), VoiceInk (GPL-3.0) or MaCursor (GPL-3.0). Using their ideas, layouts and measurements is fine, and this spec does only that.
- **MIT code** from Maccy, Rectangle, WhatCable, WhatPort and Stats may be adapted. If we adapt any, add its copyright and permission notice to Settings › Advanced › Acknowledgements. WhatCable's `Sources/WhatCablePlugins/` directory is proprietary and off limits.
- **Never reuse** another app's name, icon or artwork.

---

## 7. QA and acceptance

**Test matrix.** Every screen, in every state from §3, must pass:

| Dimension | Values |
|---|---|
| OS | macOS 14, 15, 26.x (Liquid Glass set to **Clear** and to **Tinted**), 27 (glass slider at both ends) |
| Appearance | Light, Dark |
| Accessibility | Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, each turned on alone |
| Window | 900×600 minimum, full screen, inactive window (27 dims it; check the ScanCapsule), sidebar collapsed, inspector open |
| Input | Keyboard only with Full Keyboard Access on; VoiceOver pass over the sidebar, hero, findings, table, stepper and license |
| Wallpaper | Bright and busy wallpaper behind the menu bar panel and the ScanCapsule (the Tahoe legibility check) |

**Acceptance checks:**

- [ ] Only `Glass.swift` contains `#available(macOS 26`. Grep for it in CI.
- [ ] No view sets a custom background behind the sidebar, toolbar or inspector. Grep for `NSVisualEffectView`; it must not appear.
- [ ] Each screen has exactly one `.borderedProminent` button.
- [ ] Every icon-only button has `.help` and an accessibility label.
- [ ] No severity is shown by color alone. Check with Differentiate Without Color on and in grayscale.
- [ ] No `0`, `N/A`, or bare "Error" is shown for an unmeasured value.
- [ ] Progress never shows 100% before completion.
- [ ] Every destructive action runs this sequence in order:
  - a review list;
  - a backup or the Trash;
  - a confirmation sheet with no default button;
  - a 0.5 s arm delay on the destructive button;
  - a re-check before acting;
  - an operation-log entry with Put Back.
- [ ] Permission grants are detected without a "Done" button, and a relaunch resumes at the same onboarding step.
- [ ] Contrast is at least 4.5:1 for text up to 17 pt, and at least 3:1 for bold or larger text (Accessibility Inspector audit).
- [ ] Live views update at most twice a second, and no unscoped `.animation` is used (grep for it).
- [ ] Every component has `#Preview`s for each state in light and dark.
- [ ] The app icon is built in Icon Composer (`.icon`), with an `.appiconset` fallback for 14/15, following Rectangle's `ASSETCATALOG_OTHER_FLAGS` setup.
- [ ] The menu bar icon is a template image and stays legible when the menu bar is tinted.

**Watch for these known Tahoe issues** (from Maccy's source; add them to regression tests):
- Hover and gestures don't fire on views with no background. The fix is `.background(.white.opacity(0.001))` on the affected row.
- Text inside some hosted views renders flipped. Maccy fixed this with `.drawingGroup()`.
- Some Unicode scalars in file names make CoreText hang. Sanitize display names from the iCloud file list before rendering them.

---

## Appendix A: pattern sources

| Decision | Source (read in the studies; ideas only unless the source is MIT) |
|---|---|
| One-line verdict chosen by priority; critical caps the verdict | tw93/Mole `cmd/status/diagnosis.go`, `metrics_health.go` (GPL, idea only) |
| Six check outcomes; skipped always gives a reason | Mole `lib/optimize/outcomes.sh` (idea only) |
| "At least X" / "Unknown"; progress capped at 99% | Mole `cmd/analyze/format.go`, `analyze/view.go` (idea only) |
| Safe default selection, re-check before delete, stray-keypress guard | Mole `lib/clean/project.sh`, `bin/uninstall.sh` (issue #726) (idea only) |
| Provenance-grouped evidence; plain-English diagnosis order; 6 s settling | WhatCable `Output/BulletGroup.swift`, `ConnectionDiagnostic.swift`, `Views/ContentView.swift` (MIT) |
| Timeline filters, record session, per-port health; Tahoe popover `.thickMaterial` | WhatPort Flight Recorder screenshots, `Views/PortListView.swift` L46-50 (MIT) |
| Debounced notifications that clear on recovery | Stats `Kit/module/notifications.swift` (MIT) |
| Per-OS metrics, concentric radii, hover/keyboard handoff, Sparkle bridge | Maccy `Observables/Popup.swift`, `HoverSelectionModifier.swift`, `SoftwareUpdater.swift` (MIT) |
| Permission window, auto-detect without "Done", macOS 27 pane rename, gentle update reminders | Rectangle `AccessibilityAuthorization/*`, `AppDelegate.swift` (MIT) |
| Trust screen before paywall, permission rows, Polar licensing contract, license page anatomy | VoiceInk `Features/Onboarding/*`, `Features/Licensing/*`, `Infrastructure/Licensing/PolarService.swift` (GPL, idea only) |
| Status dot + plain status + one button; "disabled with a reason"; review-before-commit sheet; stock controls give Tahoe look | MaCursor `SettingsViews.swift`, `ThemeConversionReviewView.swift`, `screenshot.png` (GPL, idea only) |
| One launch surface that morphs; live data in pickers; skeletons that match layout | Recordly `LaunchWindow.tsx`, `EditorLoadingSkeleton.tsx` (AGPL, idea only) |
| Glass only on navigation, one tint, toolbar ≤ 3 groups, Settings via ⌘, | Apple HIG (Materials, Toolbars, Sidebars, Settings, The menu bar); WWDC25 219/310/323/356; WWDC26 269/289 |

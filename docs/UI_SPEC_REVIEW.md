> **Superseded in part: the app is free ([BUILD_PLAN §10](BUILD_PLAN.md)); pricing/licensing/paywall/Dodo items are historical.** Where this document and BUILD_PLAN disagree, BUILD_PLAN wins.

=== UI CRITIQUE 0 ===
 **Verdict:** The foundations are right: system parts first, one accent colour, safe-by-default actions, honest numbers and a full accessibility matrix. The layer built on top of them is not. As written, the app would look like a web dashboard running on a Mac: a card on every surface, the same finding repeated on one screen, an iOS-style floating progress capsule, a four-screen wizard before the user gets an answer, and a permanently blue toolbar button. Maccy, Rectangle and MaCursor feel polished because they leave these things out. Most of the fixes below delete code.

## P0: these decide whether it reads as native or as a template

1. **Too many cards, and the same finding repeated (§2.7, §4.1).**
   - On the Overview, the dock finding appears 5 times: the sidebar badge, the hero headline, the module card ("2 need attention"), the "Needs your attention" row and the "Recent events" row.
   - Fix: make the Overview the hero plus one inset `List` of findings. Delete the module cards (the sidebar badges already show module state), the Recent events section (the Timeline has it), and the footer's trust line and Copy Report button (already in the Share menu and ⇧⌘C).
   - Build Upgrade Readiness and the iCloud status strip as `Form { Section { LabeledContent… } }.formStyle(.grouped)` with trailing buttons. That is how System Settings › Software Update and Storage are built, and it gets the Tahoe look for free. Use `GroupBox` (macOS 10.15+) for anything else.
   - Then delete `IconTile` and the `Radius` tokens other than `card`, because native containers set their own radii.

2. **FindingCard inside `List(selection:)` (§3.3).**
   - A filled, rounded card inside a selectable row draws two layers of chrome, and buttons and DisclosureGroups inside selectable rows compete with row selection and Full Keyboard Access.
   - Evidence also appears twice in §4.2a: once in the expanded card and again in the inspector.
   - Fix: use plain rows, the way Xcode's Issue Navigator and Mail do. Each row is SeverityIcon, title and one meta line (your existing `.compact` style). A row expands with a DisclosureGroup to show the explanation, What to try, and actions. Evidence and Technical details live only in the inspector, driven by the selection.

3. **The ScanCapsule should go (§3.8).**
   - Recordly's floating HUD makes sense because it floats over other apps. Inside a window, a floating capsule covers content, and it collides with the iCloud bottom bar, since both sit at the bottom of the detail column. It is also the only reason `Glass.swift` exists.
   - Fix: show progress in the toolbar, as Safari and Xcode do.
   - Delete ScanCapsule, `controlGlass`, the 50% "Updating…" dimming, the "✓ Done · 18 s" state and the Glass.swift CI rule. Having no custom glass at all is exactly what MaCursor ships.

   ```swift
   // PROPOSAL
   .toolbar { ToolbarItem(placement: .primaryAction) {
       if store.isScanning {
           HStack(spacing: 6) {
               ProgressView(value: min(store.progress, 0.99)).progressViewStyle(.circular).controlSize(.small)
               Button("Stop Scan", systemImage: "xmark") { store.cancelScan() }.help("Stop Scan (⌘.)")
           }
       } else {
           Button("Scan Again", systemImage: "arrow.clockwise") { store.scan() }.help("Scan Again (⌘R)")
       }
   } }
   .navigationSubtitle(store.isScanning ? store.phaseText /* "Checking displays… 2 of 5" */ : store.lastScanText /* "Scanned 2 min ago" */)
   ```

4. **"Scan Again" is permanently prominent (§1.3).**
   - It is a tinted pill on every screen for an action that becomes secondary once there are results. Dock & Display already updates live from IOKit notifications (§4.2a), so rescanning there adds almost nothing.
   - The HIG's colour guidance says to tint only the one primary action.
   - Fix: make Scan a plain `arrow.clockwise` button. The prominent slot is contextual:
     - iCloud: **Rescue Selected…** moves into the toolbar, and "3 selected · 1.1 GB" goes in the subtitle. This deletes `bottomActionBar` and `safeAreaBar`.
     - Overview: the hero's Run First Scan only in the never-scanned state.
     - Everywhere else: nothing prominent.
   - Change the §7 check to "at most one" prominent button per screen. Reports has none, so the spec currently fails its own "exactly one" check.

5. **The hero has two titles (§3.2).**
   - It stacks five lines: the verdict word at 26 pt, the headline, the summary, the timestamp and a Review button.
   - Users cannot tell which is worse, "Worth a look" or "Needs attention".
   - Fix:
     - The title becomes the fact itself, "Your dock is running at USB speed, not Thunderbolt", in `.title2.weight(.semibold)` with a 28 pt SeverityIcon.
     - Keep one meta line: "24 checks · 2 need attention · 1 couldn't be checked".
     - The timestamp moves to the subtitle, and Review goes, because the first row underneath is that finding.
     - The all-clear title is "No problems found".
     - Keep the verdict words for VoiceOver and Differentiate Without Color only.
   - Drop the tinted hero fill.

6. **Onboarding is four screens before the answer (§1.6, §4.5).** The user arrived with a broken dock. The spec also admits a bug where the window resizes from 720×560 to 900×600 partway through.
   - Fix: no onboarding flow. The never-scanned empty state is the welcome: app icon, one sentence, one privacy line with a "How AppName protects your data" link, and **Run First Scan**. The trial starts at the first scan.
   - Ask for permissions in context: Full Disk Access through the row you already designed for iCloud, and Notifications when the user turns on monitoring.
   - After the first scan finds a dock or drive, offer the menu bar icon once, inline: "Watch for drop-outs from the menu bar? [Turn On]".
   - Delete `OnboardingStage`, the view switching in `RootView`, the page dots, and the "What brought you here?" capsule chips, which are an iOS and web idiom.

7. **The `Devices | Timeline | Guided Test` segmented control (§4.2).**
   - The Timeline is not dock-only: it includes `icloudStateChanged`, sleep and wake events (§3.4). The Guided Test is a task, not a view.
   - Fix: move Timeline to its own sidebar item under History. Make Guided Test a sheet opened from the finding, the way Disk Utility runs First Aid. A sheet also stops the user switching tabs mid-test and losing readings.
   - Inside the test:
     - Show "Step 2 of 4" as text instead of the custom ✓/●/○ step indicator.
     - The buttons are Cancel, Back and Continue.
     - Remove the "‹" chevron and Skip Step, because a skipped step breaks the A/B comparison.
     - Rename "I've Done This" to "Continue".

8. **Custom topology chain (§3.10).**
   - At the 900 pt minimum width, with a 220 pt sidebar and a 300 pt inspector, the detail column is about 380 pt. That cannot hold three nodes of 150–190 pt each.
   - Custom node buttons also need hand-built Full Keyboard Access handling.
   - Fix: use `List(devices, children: \.children)`, a native outline like System Information's USB tree. Each row has the real icon, the name, a spec line and a trailing "10 of 40 Gb/s" badge with a SeverityIcon. Selection drives the inspector.
   - Keep one small drawn path (Mac → cable → dock, with the slow hop highlighted) only inside the dock finding. Rectangle's `MacDesktopGraphic` is the model: a picture only where it earns its place.

9. **Use real device icons, which look premium for no design cost.**
   - Use `NSImage(named: NSImage.computerName)` for the Mac. Verify that it returns the model artwork on 14 and 26.
   - Use `NSWorkspace.shared.icon(forFile:)` for mounted volumes, and app icons as already planned.
   - Rename Overview to **This Mac**, with the Mac icon and model name in the hero, like About This Mac.
   - Replace `gauge.with.dots.needle.67percent`: a gauge implies a score, and the app has none.

## P1

10. **Menu bar panel (§4.8).** The `.window` panel draws fake menu rows (Open, Settings… ⌘,, Quit ⌘Q) and a full-width prominent "Run Quick Check". Those rows neither highlight nor respond to the keyboard like a real menu, and "Quick Check" adds a second kind of scan.
    - Fix for v1: `.menuBarExtraStyle(.menu)`, which is available from macOS 13 and is what VoiceInk ships. It contains a disabled status item, `Section("Connected")` items such as "CalDigit TS4, 10 of 40 Gb/s", then Scan Now, Open AppName, Settings… and Quit.
    - This also removes the `.thickMaterial` legibility question.
    - Tie the icon to the Monitoring toggle, so there is one setting instead of two.

11. **Timeline rows and the filter card (§3.4, §4.2b).** Apple's own event log is Console.app, which puts filters in the toolbar and uses a table.
    - Use a `Table` with columns Time, Device, Event and Change. Sorting, multi-select and copy come built in.
    - Put Range and Device as toolbar menus, the event count and "Recording 00:41" in the subtitle, and Record as a toolbar toggle.
    - Delete `EventTimelineRow` and the red in-content banner.

12. **Info severity is blue, which clashes with the default accent.** Blue already means "clickable". Show `.info` in `.secondary`, as Stats leaves normal values uncoloured.

13. **Constant motion.** The "● Live" dot pulses forever. Make it static, and animate only the guided test's "waiting for reconnect" state.

14. **Web-style truncation.** "9 more…" inside a `Table` (§4.3a) and "▢ 1 more ▸" (§4.4) should go. Show every row and let the view scroll.

15. **Too many chevron links.** "Review ›", "Show All ›", "Open Timeline ›", "Recover Key ›", "Manage License ›" and the link-style "Copy Details" add up to the web-dashboard look. Put secondary actions in the ⋯ menu or make them small `.bordered` buttons. Use `.link` only for external "Learn More" links, with no "›".

16. **Settings has 5 tabs for about 15 controls (§1.5).** Reduce to 3:
    - General: login, monitoring and menu bar, notification rules, updates.
    - License.
    - Advanced: privacy list, log, ignored findings, clear history, reset.

    For captions, use the second `Text` in the control's label as the native subtitle: `Toggle(isOn:) { Text("Open at login"); Text("Needed to watch…") }`. Verify it renders as a subtitle in `.grouped` on 14. Add a caption only where the label doesn't explain itself.

17. **The sidebar is turning into a promo tray.** The "History" header covers a single item, and the bottom holds the LicenseBadge and the Update chip.
    - History should contain Timeline and Reports.
    - Update belongs in the app menu as "Update Available…", as in Rectangle `AppDelegate.swift` L676-695.
    - Show the trial badge only at 3 days or fewer, and never in orange: the trial isn't a problem with the Mac.

18. **The copy contradicts its own tone rule 2.** "iCloud Rescue", "Rescue Selected…" and "Rescue folder" sound alarmist, and the other modules are named with plain nouns. Use "iCloud Drive", "Retry Upload…" and "AppName Backups".

19. **Destructive confirmation (§4.3b).** A custom sheet opened on top of a sheet, plus a 0.5 s arm delay.
    - Use a standard alert: `.confirmationDialog` or `NSAlert`, with Cancel as the only keyboard default. Once there is no default button, the arm delay is redundant: Mole issue #726 happened because a queued Enter hit a default button.
    - If SwiftUI makes the destructive button the default on 14, use `NSAlert`, clear that button's `keyEquivalent`, and set `hasDestructiveAction` (macOS 11+).

20. **License sheet tier chips "( 1 Mac $— )" (§4.6).** That is a pricing page, not a Mac control. Use one Buy License… button that opens the Polar checkout, and delete the price config. For the "Copied" capsule, swap the button label to "Copied" for 1.5 s instead.

21. **Upgrade Readiness toolbar.** Drop the Target menu (put "macOS 27" in the title) and the `Needs Attention | All` control. Use the same "All checks (N)" disclosure as the other modules. Drop `.searchable` everywhere in v1, because every list here is short.

22. **Reports (§4.9).** A list plus a report inside the detail pane makes four columns at 900 pt. Make Reports a List where Return pushes the report (NavigationStack), and turn off the inspector on this route.

23. **First-scan skeletons (§3.2).** Replace them with a centred, determinate `ProgressView` and the phase label, as Software Update and First Aid do. Rescans keep the old results at full opacity. This also removes the `.placeholder` fixtures for every component.

## Contradictions and bugs in the spec

- §2.4 says "only symbols and dots use severity color", but `CardStyle(tint:)`, the hero and the callouts all fill with the severity colour. Keep symbols only.
- §5.1 rule 9 requires title case for section headers, but the wireframes use "Needs your attention", "Recent events", "Before you upgrade" and "Readings so far". Pick one.
- §1.3 puts `ToolbarSpacer` inside `if #available(macOS 26, *)`. `ToolbarContentBuilder.buildLimitedAvailability` is macOS 14.5+ according to Apple's docs, so this probably won't compile against a 14.0 target. Drop the spacers (the system groups items automatically) or raise the target to 14.5.
- §3.3 FindingCard reads `@AppStorage` directly, which breaks §3's "components take plain data". Pass in `showsTechnical`.
- 900 pt minimum width with the inspector open leaves about 380 pt of detail. Raise the minimum to about 1000 pt, or auto-close the inspector at narrow widths. Add this case to QA.
- With the menu bar extra on and no windows open, clicking the Dock icon must reopen the main window (Rectangle `applicationShouldHandleReopen`, L249-256). Add this to QA.

## Net deletions

ScanCapsule, Glass.swift and its CI rule, `bottomActionBar`, `IconTile`, the custom TopologyView chain, `EventTimelineRow`, the four-step OnboardingView, the stepper indicator, the Overview module cards, Recent events, the trust footer, most of the LicenseBadge, the skeleton fixtures, four of the five `Radius` tokens, and the Settings tabs reduced from 5 to 3. What remains is NavigationSplitView, List and outline rows, Form(.grouped), Table, the inspector, sheets, ContentUnavailableView and one tinted action per screen. That is the Maccy/Rectangle/MaCursor recipe.

## What I checked

I checked availability against Apple's docs JSON (developer.apple.com/tutorials/data/documentation/...):

| API | Available from |
|---|---|
| `navigationSubtitle(_:)` | macOS 13.0 (the listing I fetched) |
| `ToolbarContentBuilder.buildLimitedAvailability` | macOS 14.5 |
| `safeAreaBar(edge:alignment:spacing:content:)` | macOS 26.0 |
| `MenuBarExtraStyle.menu` | macOS 13.0 |
| `NSButton.hasDestructiveAction` | macOS 11.0 |
| `NSImage.computerName` | macOS 10.5 ("A computer icon") |
| `GroupBox` | macOS 10.15 |
| `toolbarTitleDisplayMode` | macOS 14.0 |

Still unverified: whether `NSImage.computerName` shows your specific Mac model, the Toggle subtitle rendering in grouped forms on 14, and which button SwiftUI makes the default in a destructive `confirmationDialog`. The reference-app claims come from the studies digest (Maccy, Rectangle `AppDelegate.swift`, VoiceInk `MenuBarView.swift`, MaCursor `screenshot.png` and `release.yml`). All code above is labelled PROPOSAL. 

=== UI CRITIQUE 1 ===
 # Adversarial SwiftUI review: AppName UI spec v1

I checked API availability against Apple's docs JSON (`developer.apple.com/tutorials/data/documentation/...`). Anything I couldn't confirm is marked **VERIFY**.

## A. Won't compile, wrong spelling, or deprecated

1. **§4.1 grid columns.** `LazyVGrid(columns: [.adaptive(minimum: 220)])` is a type error. Write it as `LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))])`.

2. **§3.3 ⋯ menu.** `.menuStyle(.borderlessButton)` is deprecated. The docs mark it deprecated in 27.2 and say to use `menuStyle(.button)` with `.buttonStyle(.borderless)`.
   - Fix: `.menuStyle(.button).buttonStyle(.borderless).menuIndicator(.hidden).fixedSize()`.
   - All of these work on macOS 13 or earlier.

3. **§1.3 `ToolbarSpacer` inside `if #available`.** This isn't a "check in our Xcode" item. It fails at a 14.0 deployment target.
   - `ToolbarContentBuilder.buildLimitedAvailability` is documented as **macOS 14.5+** and only for `CustomizableToolbarContent`. `buildIf` and `buildEither` also take only `CustomizableToolbarContent`.
   - `ToolbarItem` counts as customizable only when `ID == String`, and plain `ToolbarItem(placement:)` isn't.
   - It would also break the CI grep rule, because views would contain `#available(macOS 26`.
   - Fix: ship v1 without spacers, which the spec already allows. If 26 needs separate groups, have `Glass.swift` add a second toolbar only on 26. `ViewBuilder` handles `if #available` fine, and multiple `.toolbar` modifiers merge. **VERIFY** where the spacer ends up in the order.
   ```swift
   // PROPOSAL (Glass.swift)
   @ViewBuilder func primaryActionSpacer() -> some View {
       if #available(macOS 26, *) { toolbar { ToolbarSpacer(.fixed, placement: .primaryAction) } } else { self }
   }
   ```

4. **§3.11 menu state refresh.** The fallback for `AppCommands` state is wrong. `.focusedSceneValue` is nil when no scene is key, for example when only the menu bar extra is in use. Scan and Stop would then be disabled exactly when they're needed.
   - Fix: put the menu items in a `View` struct. View bodies track Observation, and a view can also read `@Environment(\.openWindow)` for ⌘1–⌘5 when the window is closed. Sparkle's `CheckForUpdatesView` uses this pattern.
   ```swift
   // PROPOSAL
   CommandMenu("Scan") { ScanMenuItems(store: store) }
   struct ScanMenuItems: View { let store: AppStore
       var body: some View { Button("Scan Again", systemImage: "arrow.clockwise") { store.scan() }
           .keyboardShortcut("r").disabled(store.isScanning) /* … */ } }
   ```

5. **§1.1 menu bar label.** The label closure reads `store.needsAttention` directly in `App.body`. Move it into a `MenuBarLabel: View` so Observation tracking runs in a view body.
   - **VERIFY** that `.accessibilityLabel` on the label image reaches the `NSStatusItem` button when you test with VoiceOver.
   - If it doesn't, use `Label(store.menuBarAccessibilityLabel, image: name)` as the label, then **VERIFY** that it still shows only the icon.

## B. Compiles, but fights SwiftUI

6. **Onboarding inside the `Window` with `.windowResizability(.contentSize)` (§1.1, §1.6).**
   - The content is fixed at 720×560, so min equals max and `defaultSize(1120, 760)` never applies. The window frame is also autosaved at 720×560.
   - After onboarding, the window grows only to the 900×600 minimum.
   - On 14 there is no SwiftUI API to set a `Window`'s frame. `windowIdealSize(_:)` and `defaultWindowPlacement(_:)` are both macOS 15.
   - Fix:
     - Present onboarding as `.sheet(isPresented:)` on MainView with `.interactiveDismissDisabled()` and a fixed 720×560 frame.
     - Change the scene to `.windowResizability(.contentMinSize)` with `.defaultSize(width: 1120, height: 760)`.
     - Delete the RootView branch and the 15-only `.toolbar(removing: .title)` and `.toolbarBackgroundVisibility`.
   - With no `.cancelAction` button, Esc already does nothing, as the spec wants.

7. **Findings in `List(selection:)` (§3.3 Keyboard).** This contradicts the wireframes: 4.2a puts the hero, topology and findings on one scrolling page.
   - A `List` inside a `ScrollView` collapses to zero height.
   - List row selection and insets also fight `.cardStyle()` and DisclosureGroup height changes.
   - Fix: use `ScrollView { LazyVStack(spacing: Space.s) { ForEach … } }`.
   - Drop the ↑/↓/Return promise, because Full Keyboard Access already tabs to every control. Alternatively, build it with `.focusable()`, `@FocusState`, `.onMoveCommand(perform:)` (10.15) and `.onKeyPress(.return)` (14).

8. **iCloud Rescue `Table` (§4.3).**
   - A `Table` can't sit inside a ScrollView with the hero above it. Use `VStack(spacing: 0) { hero; Table }`, or put the hero in the Table's `.safeAreaInset(edge: .top)`.
   - A `TableColumn` header takes only a title (`LocalizedStringKey`, `Text` or `String`); no initializer accepts a view. So the `[-]` tri-state header checkbox can't be built.
   - Space-to-toggle may be swallowed by the table before `.onKeyPress` sees it.
   - Fix: make the table's selection the rescue set with `Table(files, selection: $ids, sortOrder: $order)`, and pre-select only the safe rows. That gives ⌘A, ⇧-click, ⌘-click and the "N selected" count for free. Drop the checkbox column.

9. **Compact FindingCard.** It is a whole-card `Button` that contains the ⋯ `Menu` and action buttons. Nested controls inside a Button swallow clicks and confuse VoiceOver. The compact style must render no menu or buttons.

10. **`ScanCapsule .frame(width: 380)`.** At the 900 pt minimum, with the sidebar (200+) and the inspector (260+) open, the detail column is about 340–440 pt before the 20 pt padding on each side. The capsule overflows.
    - Fix: `.frame(maxWidth: 380)` plus `.lineLimit(1)` on the phase text.
    - While scanning, add `.contentMargins(.bottom, 72, for: .scrollContent)` (14) so the capsule doesn't cover the last card.

11. **Menu bar panel (`MenuBarExtra(.window)`).**
    - **No programmatic close.** There is no `isPresented` binding (FB11984872), which is why github.com/orchetect/MenuBarExtraAccess exists. **VERIFY** that the panel closes when the main window becomes key after a row click. If it doesn't, use that package (check its license) or accept the behavior.
    - **Settings opens behind other apps** when called from the panel while AppName isn't active (steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items).
      - We are a `.regular` app, so call `NSApp.activate()` (macOS 14) before `openSettings()`.
      - Last resort: find the Settings window and call `orderFrontRegardless()`.
    - **No `.sheet`, `.alert`, `.confirmationDialog`, popover or file panel from the panel's content.** The License sheet for locked actions, errors and exports must route to the main window: `NSApp.activate(); openWindow(id: "main"); store.sheet = .license`.
    - **Height.** The panel sizes itself to its content's ideal size. **VERIFY** that `ScrollView{…}.frame(width: 320).frame(maxHeight: 480)` doesn't collapse. If it does, measure the content with `onGeometryChange(for:of:action:)` (macOS 13) and set `.frame(height: min(h, 480))`.

12. **Store ownership and the Dock menu (§1.1).**
    - `applicationDockMenu` and the terminate logic live in `AppDelegate`, but the store is App `@State`. Fix: put `let store = AppStore()` on the `@MainActor` AppDelegate and pass `appDelegate.store` to the scenes.
    - AppKit can't call `openWindow`, so "Open Timeline" can't work from the Dock menu. Keep only "Scan Again" there, or cut the Dock menu from v1; the HIG says "consider", and clicking the Dock icon already reopens the window.

13. **Window tabbing.** Set `NSWindow.allowsAutomaticWindowTabbing = false` in `applicationWillFinishLaunching(_:)`. `didFinish` can run after SwiftUI has already created the window.

14. **Open at login pops the main window at every login.** On 14 there is no way to suppress a `Window` at launch. `defaultLaunchBehavior(_:)` is macOS 15 and applies to every launch without saved state, so it doesn't help.
    - **VERIFY** that `NSAppleEventManager.shared().currentAppleEvent` still carries `keyAEPropData == keyAELaunchedAsLogInItem` for `SMAppService.mainApp` launches.
    - If it does, call `dismissWindow(id: "main")` (14) on first appear. There will be a brief flash.
    - Separately, the Settings toggle must read `SMAppService.mainApp.status` (`.enabled`, `.requiresApproval`, `.notRegistered`), not `@AppStorage`. Users can remove the login item in System Settings.

15. **Destructive confirmations (§3.11, §7).**
    - The 0.5 s arm delay and the "no default button" rule are only dependable in a custom `.sheet`. `.alert` and `.confirmationDialog` buttons are NSAlert buttons, and a live `.disabled` isn't guaranteed. **VERIFY** which button Return triggers.
    - Make every destructive confirmation a custom sheet, including "Deactivate This Mac…":
      - Cancel gets `.keyboardShortcut(.cancelAction)`.
      - The destructive button gets `.disabled(!armed)`, set from `.task { try? await Task.sleep(for: .milliseconds(500)); armed = true }`.
      - Nothing gets `.defaultAction`.
      - Initial focus goes to Cancel with `@FocusState` and `.defaultFocus($focus, .cancel)` (13), so a Full Keyboard Access Space press can't hit the destructive button.

16. **⌘F with `.searchable`.** The only way to focus the search field from code is `searchFocused(_:)`, which is macOS 15. **VERIFY** that ⌘F focuses the toolbar search field on 14. If it doesn't, use `searchFocused` on 15+ and accept the gap on 14.

17. **Reports text selection.** `.textSelection(.enabled)` selects within a single `Text` only, so you can't drag-select across a report built from many Texts. Render the report as one `Text(AttributedString)` inside a ScrollView.

18. **Settings panes.** A grouped `Form` is scroll-backed, and the Settings window takes each tab's height from the pane's ideal size.
    - **VERIFY** each tab. If a pane collapses or grows too tall, add `.scrollDisabled(true).fixedSize(horizontal: false, vertical: true)`.
    - For the one-line captions, don't hand-build caption views. Put two Texts in the label: `Toggle(isOn:) { Text("Open AppName at login"); Text("Needed to…") }`. A grouped Form renders the second Text as the secondary subtitle.

19. **Inspector placement.**
    - `.inspector` on the `NavigationSplitView` gives a full-height column with its own toolbar section.
    - Wireframe 4.2a draws a full-width toolbar above the inspector. That is the layout you get with `.inspector` attached to the detail column instead.
    - Pick one. Toolbar items then belong to the column they are declared in.

20. **Smaller items.**
    - A skeleton made with `.redacted(reason: .placeholder)` still accepts clicks. Add `.allowsHitTesting(false)`.
    - Use `.symbolEffect(.pulse, isActive: !reduceMotion)`, not `isActive: true`.
    - For the "Ignore" undo, register with `@Environment(\.undoManager)` so Edit › Undo (⌘Z) works; the toast becomes optional.
    - For Maccy's Tahoe hover bug, try `.contentShape(.rect)` first. Keep `.white.opacity(0.001)` only if hover still fails on 26. Use `.drawingGroup()` only as a targeted fix, because it rasterizes text.
    - For "Relaunch AppName": `NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration:)` with `createsNewApplicationInstance = true`, then `NSApp.terminate(nil)`.
    - For `noSearchResults`, use `ContentUnavailableView.search(text:)` (14) and drop the custom preset.
    - §1.1 says Settings opens with "⌘, only", but the panel has a Settings… row. The row is fine; fix the wording.

## C. Checked and correct as written

| API | Availability |
|---|---|
| `MenuBarExtra(isInserted:content:label:)` | macOS 13 |
| `openSettings`, `SettingsLink` | macOS 14 |
| `inspector(isPresented:content:)`, `InspectorCommands` | macOS 14 |
| `ContentUnavailableView` | macOS 14 |
| `Button(_:systemImage:action:)` | macOS 14 |
| `NSApplication.activate()` | macOS 14 |
| `onKeyPress` | macOS 14 |
| `focusable(_:interactions:)` | macOS 14 |
| `dismissWindow` | macOS 14 |
| `contentMargins` | macOS 14 |
| `appearsActive` | back-deployed to macOS 10.15 |
| `tag(_:includeOptional:)` | back-deployed to 10.15, so optional `Route?` sidebar selection works |
| `ShapeStyle.separator` | macOS 10.15 |
| `onGeometryChange` | macOS 13 |
| `dialogSeverity`, `defaultFocus` | macOS 13 |
| `toolbar(removing: .title)` (`ToolbarDefaultItemKind.title`), `toolbarBackgroundVisibility` | macOS 15, as the spec says |
| `glassEffect(_:in:)` | macOS 26 |
| `safeAreaBar(edge:alignment:spacing:content:)` | macOS 26; separate HorizontalEdge and VerticalEdge overloads, and `.bottom` resolves to the vertical one |

`.tabItem` in Settings on 14, `@AppStorage` with a String-backed enum, and the local `@Bindable var store = store` inside `body` are all fine.

The verification helper script was `<scratchpad>/av.py` (a temporary file, not in the repo). 


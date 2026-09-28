import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WhydunitCore
import WhydunitMac

struct FindingDetailView: View {
    @Environment(AppStore.self) private var store
    let rule: RuleID
    /// Sorted rows of the finding's items; kept in state so selection changes don't re-sort thousands of rows.
    @State private var rows: [ItemRow] = []
    @State private var sortOrder = [KeyPathComparator(\ItemRow.sortModified)]   // oldest (longest stuck) first
    /// Builds a big finding's rows off the main thread; cancelled when a newer build starts.
    @State private var building: Task<Void, Never>?
    /// Copy Command shows "Copied" for a moment, since copying has no other visible effect.
    @State private var copied = false
    /// The finding the default selection was made for; a rescan keeps the user's own selection instead.
    @State private var preselected: RuleID?
    /// Focused once rows are pre-selected, so the selection shows in the accent colour, not the unfocused gray.
    @FocusState private var tableFocused: Bool

    var body: some View {
        if let finding = store.finding(rule) {
            detail(finding)
        } else {
            ContentUnavailableView {
                Label("No Longer Found", systemImage: "checkmark.circle")
            } description: {
                Text("The latest scan didn't find this problem.")
            } actions: {
                Button("Show Summary") { store.route = .summary }
            }
        }
    }

    private func detail(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The toolbar action exists only while rows are selected; the header is stateless, so
            // swapping it in and out doesn't disturb the table.
            if let action = toolbarAction(finding) {
                header(finding).toolbar {
                    ToolbarItem(placement: .primaryAction) {   // VERIFY: sits before Scan and Inspector in the merged toolbar.
                        Button(title(action)) { run(action, finding) }
                            .help("\(action.actionTitle) the selected items (⌘↩)")
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                }
            } else {
                header(finding)
            }
            if !rows.isEmpty {
                Divider()
                table(finding)
            } else {
                Spacer(minLength: 0)
            }
        }
        .onChange(of: finding, initial: true) { _, finding in
            if preselected == finding.rule {
                store.selection.formIntersection(finding.itemPaths)
            } else {
                preselected = finding.rule
                rows = []   // the last finding's rows mustn't show, or be acted on, while a big one builds
                // Only item actions pre-select; on Show in Finder or information-only findings a full selection
                // looks broken and would open a Finder window per folder.
                if finding.primaryAction == .backUp || finding.primaryAction == .retryUpload {
                    let now = Date()
                    store.selection = Set(store.items(for: finding)
                        .filter { ICloudClassifier.isSafeToPreselect($0, now: now) }.map(\.path))
                } else {
                    store.selection = []
                }
            }
            reload(finding)
            tableFocused = !store.selection.isEmpty   // VERIFY: Table honours .focused and the selection turns accent
        }
        // Retry Upload re-reads each item into itemsByPath; show the fresh Status and Size here too.
        .onChange(of: store.isRetrying) { _, running in
            if !running { reload(finding) }
        }
        // A rescan whose finding is value-equal doesn't fire onChange(of: finding); its items are new all the same.
        .onChange(of: store.lastScanDate) { _, _ in reload(finding) }
        .onChange(of: sortOrder) { _, _ in reload(finding) }
        .onDisappear { store.selection = [] }
    }

    @ViewBuilder private func table(_ finding: Finding) -> some View {
        @Bindable var store = store
        Table(rows, selection: $store.selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { row in
                HStack(spacing: Space.xs) {
                    // VERIFY: returns a generic icon (never materializes) for dataless items.
                    Image(nsImage: NSWorkspace.shared.icon(forFile: row.item.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(row.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .help(row.item.path)
            }
            .width(min: 100, ideal: 220)
            TableColumn("Folder", value: \.folder) { row in
                Text(row.folder)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 70, ideal: 240)
            TableColumn("Size", value: \.sortSize) { row in
                Text(ByteFormat.string(row.item.logicalSize, lowerBound: row.item.listingFailed))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 100)   // room for "At least 1.2 GB"
            .alignment(.numeric)   // right-aligned, like Finder
            TableColumn("Status", value: \.status) { row in
                StatusTag(status: row.state)
            }
            .width(min: 100, ideal: 150)
            // Minimums (430 in all) fit the 1000 pt window with sidebar and inspector open. Modified shows the
            // date only so they do; the tooltip and the inspector have the time.
            TableColumn("Modified", value: \.sortModified) { row in
                Text(row.item.modified?.formatted(date: .numeric, time: .omitted) ?? "Unknown")
                    .monospacedDigit()
                    .help(row.item.modified?.formatted(date: .numeric, time: .shortened) ?? "")
            }
            .width(min: 70, ideal: 100)
        }
        // Past the last row macOS 26 draws the alternating fills as detached empty slabs.
        .alternatingRowBackgrounds(.disabled)
        .focused($tableFocused)
        .contextMenu(forSelectionType: String.self) { paths in
            if !paths.isEmpty {
                if let action = finding.primaryAction, action == .backUp || action == .retryUpload {
                    Button("\(action.actionTitle)…") { store.request(action, for: finding, paths: paths.sorted()) }
                    Divider()
                }
                Button("Show in Finder") { FinderBridge.reveal(paths.sorted()) }
                Button(paths.count == 1 ? "Copy Path" : "Copy Paths") { copy(paths.sorted()) }
            }
        } primaryAction: { paths in
            FinderBridge.reveal(paths.sorted())
        }
        // Plain text, not file URLs, so pasting into Finder can't copy (or download) the items.
        .onCopyCommand(perform: store.selection.isEmpty ? nil : {
            [NSItemProvider(object: store.selection.sorted().joined(separator: "\n") as NSString)]
        })
    }

    private func header(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                SeverityIcon(severity: finding.severity, size: 40, tile: true)
                Text(finding.title)
                    .font(.title2.weight(.bold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            // Capped like System Settings' detail panes: full-width lines in a wide window are hard to read.
            Text(finding.explanation)
                .textSelection(.enabled)
                .frame(maxWidth: 640, alignment: .leading)

            if !finding.steps.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("What to Try").font(.headline)
                    ForEach(Array(finding.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .frame(width: 20, height: 20)
                                .background(Color.accentColor.opacity(0.14), in: Circle())
                            Text(step)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
            }

            // Moved Files can name folders outside the scan roots (Relocated Items, iCloud Drive (Archive)) beside
            // second-Mac folders that do have rows; the outside ones have no row, so list them here. Only this
            // rule has such paths, so other findings skip the lookup over their thousands of paths.
            let unlisted = finding.rule == .relocatedFiles ? finding.itemPaths.filter { store.itemsByPath[$0] == nil } : []
            if !unlisted.isEmpty {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    ForEach(unlisted, id: \.self) { path in
                        Text((path as NSString).abbreviatingWithTildeInPath)
                    }
                }
                .font(.callout.monospaced())
                .textSelection(.enabled)
            }

            if let command = finding.command {
                // One line per command, however many paths it holds, so the header stays short;
                // Copy Command copies it in full.
                VStack(alignment: .leading, spacing: Space.xxs) {
                    ForEach(command.components(separatedBy: "\n"), id: \.self) { line in
                        Text(line).lineLimit(1).truncationMode(.middle)
                    }
                }
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .help(command)
            }

            // Stacked when the row doesn't fit (minimum window, inspector open), instead of truncated titles.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.xs) { actionButtons(finding) }
                VStack(alignment: .leading, spacing: Space.xs) { actionButtons(finding) }
            }
            .padding(.top, Space.xxs)

            // Says why the prominent button is gray when nothing qualified for pre-selection.
            if let action = finding.primaryAction, needsSelection(action), store.selection.isEmpty {
                Text(action == .backUp ? "Select the items to back up." : "Select the items to retry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func actionButtons(_ finding: Finding) -> some View {
        ForEach(actions(for: finding), id: \.self) { action in
            let button = Button(title(action)) { run(action, finding) }
                .disabled(needsSelection(action) && store.selection.isEmpty)
            if action == finding.primaryAction {
                button.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            } else {
                button.buttonStyle(.bordered)
            }
        }
        if !rows.isEmpty {
            Button("Export List…") { export(finding) }
                .buttonStyle(.bordered)
        }
    }

    /// Primary first; Back Up next to Retry Upload because a retry needs a verified backup.
    private func actions(for finding: Finding) -> [FixAction] {
        var list = finding.primaryAction.map { [$0] } ?? []
        if finding.primaryAction == .retryUpload { list.append(.backUp) }
        if !finding.itemPaths.isEmpty, !list.contains(.showInFinder) { list.append(.showInFinder) }
        if finding.command != nil, !list.contains(.copyCommand) { list.append(.copyCommand) }
        return list
    }

    /// Actions with a consent sheet end in "…"; Copy Command says "Copied" for a moment.
    private func title(_ action: FixAction) -> String {
        if copied && action == .copyCommand { return "Copied" }
        return [.backUp, .retryUpload, .restartSync].contains(action) ? action.actionTitle + "…" : action.actionTitle
    }

    private func toolbarAction(_ finding: Finding) -> FixAction? {
        guard !store.selection.isEmpty, let action = finding.primaryAction,
              action == .backUp || action == .retryUpload else { return nil }
        return action
    }

    /// Back Up and Retry Upload work on the table selection (their findings are all scanned items, so rows are
    /// never legitimately empty); everything else (Show in Finder too) acts on all the finding's paths when
    /// nothing is selected. Not keyed to `rows`: they're empty while a big finding's rows build.
    private func needsSelection(_ action: FixAction) -> Bool {
        [.backUp, .retryUpload].contains(action)
    }

    private func run(_ action: FixAction, _ finding: Finding) {
        // Selected rows in table order (in the finding's order while a big finding's rows build). Nothing selected
        // sends no paths, and request(_:for:paths:) then uses all the finding's paths.
        let paths = (rows.isEmpty ? finding.itemPaths : rows.map(\.id)).filter(store.selection.contains)
        store.request(action, for: finding, paths: paths)
        if action == .copyCommand {
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        }
    }

    /// Always from the store, so a sort during a rebuild can't bring back the old rows. Big findings build off the
    /// main thread; small ones right away, so switching findings doesn't flash an empty table.
    private func reload(_ finding: Finding) {
        building?.cancel()
        let byPath = store.itemsByPath, order = sortOrder
        let build = { @Sendable () -> [ItemRow] in
            finding.itemPaths.compactMap { byPath[$0] }.map(ItemRow.init).sorted(using: order)
        }
        // ponytail: fixed cutoff; a couple of thousand rows build and sort in a few milliseconds.
        guard finding.itemPaths.count > 2_000 else {
            rows = build()
            return
        }
        building = Task {
            let built = await Task.detached(priority: .userInitiated) { build() }.value
            if !Task.isCancelled { rows = built }
        }
    }

    private func export(_ finding: Finding) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(finding.rule.shortName).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        let csv = store.exportCSV(for: finding)
        // Sheets on the main window, like Finder and Pages; app-modal only when there's no window.
        let window = NSApp.keyWindow
        let save = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else { return }
            do {
                // Materialization is off for the whole process, so writing into a dataless folder
                // (~/Documents with Optimize Mac Storage) would fail with EDEADLK. This write only.
                try Materialization.allowingOnThisThread {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                let alert = NSAlert(error: error)
                if let window { alert.beginSheetModal(for: window, completionHandler: nil) } else { alert.runModal() }
            }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: save) } else { save(panel.runModal()) }
    }

    private func copy(_ paths: [String]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }
}

/// A table row with its sort keys worked out once: sorting on ItemRecord's computed name, folder and status
/// redid that work (path splitting, lowercasing) on every comparison. Unknown sizes and dates sort first.
private struct ItemRow: Identifiable, Sendable {
    let item: ItemRecord
    let name: String
    let folder: String
    let state: ItemStatus
    let status: String
    let sortSize: Int64
    let sortModified: Date
    var id: String { item.path }

    init(_ item: ItemRecord) {
        self.item = item
        name = item.name
        folder = item.displayFolder
        state = ICloudClassifier.status(of: item)
        status = state.label
        sortSize = item.logicalSize ?? -1
        sortModified = item.modified ?? .distantPast
    }
}

/// Status as a tag: accent while waiting, red when failed, gray otherwise. White on a selected row, like its text.
private struct StatusTag: View {
    let status: ItemStatus
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Tag(text: status.label, tint: prominence == .increased ? .white : tint)
    }

    private var tint: Color {
        switch status {
        case .waitingToUpload: .accentColor
        case .uploadFailed: .red
        default: .secondary
        }
    }
}

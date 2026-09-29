import SwiftUI
import WhydunitCore

struct MainView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Ticks so "Scanned 2 minutes ago" stays true while nothing else changes.
    @State private var now = Date.now
    /// No empty sidebar: the detail alone until the first diagnosis arrives (DESIGN.md §5.1). View state, not AppStore.
    @State private var columns = NavigationSplitViewVisibility.detailOnly

    var body: some View {
        @Bindable var store = store
        NavigationSplitView(columnVisibility: $columns) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                // Nothing to toggle before the first diagnosis (§5.1). Keyed to the diagnosis, not to .detailOnly, so
                // hiding the sidebar later doesn't take away the button that brings it back. VERIFY on macOS 15 and 26.
                .toolbar(removing: store.diagnosis == nil ? .sidebarToggle : nil)
        } detail: {
            DetailView()
                .navigationSubtitle(subtitle)
                .toolbar { toolbarItems }
        }
        // Only finding pages have rows to inspect; elsewhere the inspector stays closed without losing the user's choice.
        .inspector(isPresented: store.isFindingRoute ? $store.inspectorShown : .constant(false)) {
            InspectorView()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
        // One Sky for the whole window. Inside the detail it came out blank on Welcome (.detailOnly) whether it was a
        // background, a window container background or a ZStack child. The sidebar's material doesn't pick it up.
        // VERIFY in the screens capture.
        .background { Sky() }
        .sheet(item: $store.sheet) { sheet in
            Group {
                switch sheet {
                case .backUp(let paths, let thenRetry): BackUpSheet(paths: paths, thenRetry: thenRetry)
                case .retryUpload(let paths): RetryUploadSheet(paths: paths)
                case .restartSync: RestartSyncSheet()
                }
            }
            .environment(store)   // explicit, so a sheet never depends on environment inheritance
        }
        // A diagnosis arriving opens the sidebar; rescans keep theirs, so after that it's the user's to hide. One already
        // there at launch (the demo screens) opens it without animating.
        .onChange(of: store.diagnosis != nil, initial: true) { had, has in
            guard has else { return }
            withAnimation(had ? nil : Motion.spring(reduceMotion)) { columns = .all }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = .now
            }
        }
    }

    /// Before the first result the only action is Welcome's Scan button, so no Scan Again and no Inspector; the first
    /// scan's progress and Stop still show.
    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        if store.diagnosis != nil || isScanning {
            ToolbarItem(placement: .primaryAction) {
                if case .scanning(_, _, let fraction) = store.scanState {
                    HStack(spacing: Space.xs) {
                        ProgressView(value: fraction.map { min($0, 0.99) })
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .accessibilityLabel("Scanning")
                        Button("Stop Scan", systemImage: "xmark") { store.cancelScan() }
                            .help("Stop Scan (⌘.)")
                    }
                } else {
                    Button("Scan Again", systemImage: "arrow.clockwise") { store.scan() }
                        .help("Scan Again (⌘R)")
                }
            }
        }
        // Only finding pages have rows to inspect: elsewhere the button would only ever be disabled.
        if store.isFindingRoute {
            ToolbarItem(placement: .primaryAction) {
                Button(store.inspectorShown ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing") {
                    store.inspectorShown.toggle()
                }
                .help(store.inspectorShown ? "Hide Inspector (⌃⌘I)" : "Show Inspector (⌃⌘I)")
            }
        }
    }

    private var isScanning: Bool {
        if case .scanning = store.scanState { return true }
        return false
    }

    private var subtitle: String {
        if case .scanning(let phase, let itemsSeen, _) = store.scanState {
            return itemsSeen > 0 ? "\(phase) · \(itemCount(itemsSeen))" : phase
        }
        if case .finding(_)? = store.route, !store.selection.isEmpty {
            let selected = "\(store.selection.count.formatted()) selected"
            let sizes = store.selection.compactMap { store.itemsByPath[$0]?.logicalSize }
            if sizes.isEmpty { return selected }   // never "At least 0 bytes"
            return "\(selected) · \(ByteFormat.string(sizes.reduce(0, +), lowerBound: sizes.count < store.selection.count))"
        }
        if case .failed = store.scanState { return "The scan didn't finish" }
        guard let date = store.lastScanDate else { return "" }
        if now.timeIntervalSince(date) < 60 { return "Scanned just now" }
        return "Scanned \(date.formatted(.relative(presentation: .named)))"
    }
}

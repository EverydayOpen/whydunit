import SwiftUI
import WhydunitCore

struct MainView: View {
    @Environment(AppStore.self) private var store
    /// Ticks so "Scanned 2 minutes ago" stays true while nothing else changes.
    @State private var now = Date.now

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = .now
            }
        }
    }

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
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
        ToolbarItem(placement: .primaryAction) {
            let shown = store.isFindingRoute && store.inspectorShown
            Button(shown ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing") {
                store.inspectorShown.toggle()
            }
            .help(shown ? "Hide Inspector (⌃⌘I)" : "Show Inspector (⌃⌘I)")
            .disabled(!store.isFindingRoute)
        }
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

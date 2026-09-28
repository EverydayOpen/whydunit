import SwiftUI
import WhydunitCore

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.route) {
            Section("iCloud Drive") {
                Label("Summary", systemImage: "icloud")
                    .tag(Route.summary)
                ForEach(store.diagnosis?.findings ?? []) { finding in
                    Label {
                        Text(finding.rule.shortName)
                    } icon: {
                        SeverityIcon(severity: finding.severity, size: nil, showsWord: false)
                    }
                    .badge(finding.itemPaths.count)
                    .tag(Route.finding(finding.rule))
                }
            }
            Section("History") {
                Label("Backups", systemImage: "clock.arrow.circlepath")
                    .tag(Route.backups)
                Label("Activity", systemImage: "list.bullet.rectangle")
                    .tag(Route.activity)
            }
        }
        .listStyle(.sidebar)
        // A click on the blank area (or ⌘-click on the selected row) clears the selection; like Mail, keep one.
        .onChange(of: store.route) { old, new in
            if new == nil { store.route = old ?? .summary }
        }
    }
}

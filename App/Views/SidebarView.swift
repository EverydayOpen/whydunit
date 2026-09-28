import SwiftUI
import WhydunitCore

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.route) {
            Section("iCloud Drive") {
                row("Summary", "icloud.fill", .accentColor)
                    .tag(Route.summary)
                ForEach(store.diagnosis?.findings ?? []) { finding in
                    Label {
                        Text(finding.rule.shortName)
                    } icon: {
                        SeverityIcon(severity: finding.severity, size: 20, showsWord: false, tile: true)
                    }
                    .badge(finding.itemPaths.count)
                    .tag(Route.finding(finding.rule))
                }
            }
            Section("History") {
                row("Backups", "clock.arrow.circlepath", .teal)
                    .tag(Route.backups)
                row("Activity", "list.bullet.rectangle", .gray)
                    .tag(Route.activity)
            }
        }
        .listStyle(.sidebar)
        // A click on the blank area (or ⌘-click on the selected row) clears the selection; like Mail, keep one.
        .onChange(of: store.route) { old, new in
            if new == nil { store.route = old ?? .summary }
        }
    }

    /// Tiles keep their colour on the selected row, as in System Settings.
    private func row(_ title: LocalizedStringKey, _ symbol: String, _ color: Color) -> some View {
        Label { Text(title) } icon: { Image(systemName: symbol).tile(color, size: 20) }
    }
}

import SwiftUI
import WhydunitCore

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        @Bindable var store = store
        List(selection: $store.route) {
            Section("iCloud Drive") {
                row(Text("Summary"), "icloud", .accentColor)
                    .tag(Route.summary)
                // Category symbols, not severity tiles: colour only in the symbol, orange or red only when it matters
                // (DESIGN.md §5.1). Without colour, the severity's own symbol shape says it instead.
                ForEach(store.diagnosis?.findings ?? []) { finding in
                    row(Text(finding.rule.shortName),
                        differentiate ? finding.severity.symbol : finding.rule.symbol, finding.severity.color)
                        .accessibilityLabel("\(finding.severity.word), \(finding.rule.shortName)")
                        .badge(finding.itemPaths.count)
                        .tag(Route.finding(finding.rule))
                }
            }
            Section("History") {
                row(Text("Backups"), "clock.arrow.circlepath", .secondary)
                    .tag(Route.backups)
                row(Text("Activity"), "list.bullet.rectangle", .secondary)
                    .tag(Route.activity)
            }
        }
        .listStyle(.sidebar)
        // A click on the blank area (or ⌘-click on the selected row) clears the selection; like Mail, keep one.
        .onChange(of: store.route) { old, new in
            if new == nil { store.route = old ?? .summary }
        }
    }

    private func row(_ title: Text, _ symbol: String, _ tint: Color) -> some View {
        Label { title } icon: { SidebarSymbol(name: symbol, tint: tint) }
    }
}

/// White on the selected row's accent fill, like the row's text; its tint everywhere else.
private struct SidebarSymbol: View {
    let name: String
    let tint: Color
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Image(systemName: name)
            .foregroundStyle(prominence == .increased ? AnyShapeStyle(.foreground) : AnyShapeStyle(tint))
    }
}

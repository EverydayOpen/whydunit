import AppKit
import SwiftUI
import WhydunitCore
import WhydunitMac

/// Every change the app made, newest first (the activity log).
struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @State private var selection = Set<AuditEntry.ID>()

    var body: some View {
        if store.activity.isEmpty {
            ContentUnavailableView("No Activity Yet", systemImage: "list.bullet.rectangle",
                                   description: Text("Every change Whydunit makes, like a backup or a retried upload, is listed here."))
        } else {
            Table(store.activity, selection: $selection) {
                TableColumn("Time") { entry in
                    Text(entry.date.formatted(date: .abbreviated, time: .standard))
                        .monospacedDigit()
                }
                .width(min: 150, ideal: 170)
                TableColumn("Action") { entry in
                    Text(actionTitle(entry))
                }
                .width(min: 110, ideal: 150)
                TableColumn("Item") { entry in
                    Text((entry.target as NSString).lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(entry.target)
                }
                .width(min: 120, ideal: 200)
                TableColumn("Outcome") { entry in
                    OutcomeLabel(outcome: entry.outcome)
                }
                .width(min: 100, ideal: 110)
                TableColumn("Detail") { entry in
                    Text(entry.detail)
                        .lineLimit(1)
                        .help(entry.detail)
                }
            }
            // Full target and detail, e.g. the holding-folder path of an item a quit left out of iCloud Drive.
            .contextMenu(forSelectionType: AuditEntry.ID.self) { ids in
                if !ids.isEmpty {
                    Button("Copy") { copy(ids) }
                    let paths = entries(ids).map(\.target).filter { $0.hasPrefix("/") }
                    if !paths.isEmpty {
                        Button("Show in Finder") { FinderBridge.reveal(paths) }
                    }
                }
            }
            .onCopyCommand(perform: selection.isEmpty ? nil : {
                [NSItemProvider(object: text(selection) as NSString)]
            })
        }
    }

    /// Newest first, like the table.
    private func entries(_ ids: Set<AuditEntry.ID>) -> [AuditEntry] {
        store.activity.filter { ids.contains($0.id) }
    }

    /// One tab-separated line per entry: time, action, target, outcome, detail.
    private func text(_ ids: Set<AuditEntry.ID>) -> String {
        entries(ids).map {
            [$0.date.formatted(date: .abbreviated, time: .standard), actionTitle($0), $0.target,
             $0.outcome.rawValue.capitalized, $0.detail].joined(separator: "\t")
        }.joined(separator: "\n")
    }

    private func copy(_ ids: Set<AuditEntry.ID>) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text(ids), forType: .string)
    }

    /// Trashing a backup is logged under Back Up (Model can't gain a case); don't let it read as a backup made.
    private func actionTitle(_ entry: AuditEntry) -> String {
        entry.detail == AppStore.trashedBackupDetail ? "Move to Trash" : entry.action.actionTitle
    }
}

/// Our own failures are gray, never red: the Mac isn't at fault. On a selected row the icon turns white like the text.
private struct OutcomeLabel: View {
    let outcome: AuditEntry.Outcome
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let style: (word: String, symbol: String, color: Color) = switch outcome {
        case .succeeded: ("Succeeded", "checkmark.circle.fill", .green)
        case .failed: ("Failed", "exclamationmark.circle", .secondary)
        case .skipped: ("Skipped", "minus.circle", .secondary)
        }
        return Label {
            Text(style.word)
        } icon: {
            Image(systemName: style.symbol)
                .foregroundStyle(prominence == .increased ? AnyShapeStyle(.foreground) : AnyShapeStyle(style.color))
        }
    }
}

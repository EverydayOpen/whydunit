import AppKit
import SwiftUI
import WhydunitCore
import WhydunitMac

/// Every change the app made, newest first (the activity log), one section per day.
struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @State private var selection = Set<AuditEntry.ID>()

    var body: some View {
        if store.activity.isEmpty {
            ContentUnavailableView("No Activity Yet", systemImage: "list.bullet.rectangle",
                                   description: Text("Every change Whydunit makes, like a backup or a retried upload, is listed here."))
        } else {
            List(selection: $selection) {
                // Offsets, not days: a clock change can split one day into two runs.
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Section(dayTitle(day.date)) {
                        ForEach(day.entries) { row($0) }
                    }
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

    /// Time in a 64 pt mono column, a dot for the outcome, then what happened and the detail.
    private func row(_ entry: AuditEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 64, alignment: .leading)
                .help(entry.date.formatted(date: .complete, time: .standard))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
                    OutcomeDot(outcome: entry.outcome)
                    Text(actionTitle(entry)).fontWeight(.semibold)
                    Text((entry.target as NSString).lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(entry.target)
                }
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .help(entry.detail)
                        .padding(.leading, 6 + Space.xs)   // under the text, not the dot
                }
            }
            Spacer(minLength: Space.s)
            // The word too: failed and skipped share a gray dot, and colour alone never carries meaning.
            Text(entry.outcome.rawValue.capitalized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// Runs of entries from the same day; `activity` is newest first, so the runs are too.
    /// ponytail: regrouped on every body pass (selection too); cache it in the store if logs reach tens of thousands.
    private var days: [(date: Date, entries: [AuditEntry])] {
        var runs: [(date: Date, entries: [AuditEntry])] = []
        for entry in store.activity {
            let day = Calendar.current.startOfDay(for: entry.date)
            if runs.last?.date == day { runs[runs.count - 1].entries.append(entry) } else { runs.append((day, [entry])) }
        }
        return runs
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .complete, time: .omitted)
    }

    /// Newest first, like the list.
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

/// Our own failures are gray, never red: the Mac isn't at fault. On a selected row the dot turns white like the text.
private struct OutcomeDot: View {
    let outcome: AuditEntry.Outcome
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Circle()
            .fill(prominence == .increased ? AnyShapeStyle(.foreground) : AnyShapeStyle(outcome == .succeeded ? Color.green : Color.secondary))
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }
}

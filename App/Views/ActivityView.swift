import AppKit
import SwiftUI
import WhydunitCore
import WhydunitMac

/// Every change the app made, newest first (the activity log), as a timeline grouped by day (DESIGN.md §5.2).
struct ActivityView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.activity.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("No Activity Yet")
                } icon: {
                    Image(systemName: "list.bullet.rectangle").symbolRenderingMode(.hierarchical).foregroundStyle(.tint)
                }
            } description: {
                Text("Every change Whydunit makes, like a backup or a retried upload, is listed here.")
            }
            .skyBackdrop()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Offsets, not days: a clock change can split one day into two runs.
                    ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                        Section {
                            ForEach(day.entries) { row($0) }
                        } header: {
                            Text(dayTitle(day.date)).smallCapsHeader()
                                .padding(.top, i == 0 ? 0 : Space.xl)
                                .padding(.bottom, Space.xs)
                        }
                    }
                }
                .padding(Space.xl)
            }
            .background { Sky() }
        }
    }

    /// Time in a 64 pt mono column, an 8 pt outcome dot on the day's 1 pt rail, what happened and the detail, and
    /// the outcome's word. The context menu has the full target and detail, e.g. the holding-folder path of an item
    /// a quit left out of iCloud Drive.
    private func row(_ entry: AuditEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 64, alignment: .leading)
                .help(entry.date.formatted(date: .complete, time: .standard))
            // Our own failures are gray, never red: the Mac isn't at fault. Its bottom sits on the text baseline.
            Circle()
                .fill(entry.outcome == .succeeded ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
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
                }
            }
            Spacer(minLength: Space.s)
            // The word too: failed and skipped share a gray dot, and colour alone never carries meaning.
            Text(entry.outcome.rawValue.capitalized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Space.xs)
        // The rail runs through the dots' centre: the 64 pt time column, the spacing, half the dot less half the rail.
        .background(alignment: .leading) {
            Rectangle().fill(.separator).frame(width: 1).padding(.leading, 64 + Space.s + 3.5)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") { copy(entry) }
            if entry.target.hasPrefix("/") {
                Button("Show in Finder") { FinderBridge.reveal([entry.target]) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Runs of entries from the same day; `activity` is newest first, so the runs are too.
    /// ponytail: regrouped on every body pass; cache it in the store if logs reach tens of thousands.
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

    /// One tab-separated line: time, action, target, outcome, detail.
    private func copy(_ entry: AuditEntry) {
        let line = [entry.date.formatted(date: .abbreviated, time: .standard), actionTitle(entry), entry.target,
                    entry.outcome.rawValue.capitalized, entry.detail].joined(separator: "\t")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(line, forType: .string)
    }

    /// Trashing a backup is logged under Back Up (Model can't gain a case); don't let it read as a backup made.
    private func actionTitle(_ entry: AuditEntry) -> String {
        entry.detail == AppStore.trashedBackupDetail ? "Move to Trash" : entry.action.actionTitle
    }
}

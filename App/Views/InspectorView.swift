import AppKit
import SwiftUI
import WhydunitCore

/// Technical details of the one selected item: every raw value macOS reported, monospaced and selectable.
struct InspectorView: View {
    @Environment(AppStore.self) private var store
    /// The section whose Copy shows "Copied" for a moment, since copying has no other visible effect.
    @State private var copied: String?

    private typealias Fact = (label: String, value: String)
    /// Long values (a path, an error message) go under their label, instead of wrapped in the narrow value column.
    private static let stacked: Set<String> = ["Path", "Upload error", "Download error"]

    var body: some View {
        if store.selection.count == 1, let path = store.selection.first, let item = store.itemsByPath[path] {
            Form {
                section("Item", itemFacts(item))
                section("Sync State", syncFacts(item))
                section("File System", fileSystemFacts(item))
            }
            .formStyle(.grouped)
        } else if store.selection.count > 1 {
            ContentUnavailableView("\(store.selection.count.formatted()) Items Selected", systemImage: "sidebar.trailing",
                                   description: Text("Select one item to see its technical details."))
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.trailing")
        }
    }

    private func section(_ title: String, _ facts: [Fact]) -> some View {
        Section {
            // Offsets, not labels: an item with both errors has two "Error code" rows.
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                if Self.stacked.contains(fact.label) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(fact.label).foregroundStyle(.secondary)
                        value(fact.value)
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    LabeledContent(fact.label) { value(fact.value) }
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(title).smallCapsHeader()   // small caps, not uppercase copy (DESIGN.md §5.2)
                Spacer()
                Button(copied == title ? "Copied" : "Copy") { copy(title, facts) }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .accessibilityLabel(copied == title ? "Copied" : "Copy \(title)")
            }
        }
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
    }

    private func itemFacts(_ item: ItemRecord) -> [Fact] {
        [("Name", item.name),
         ("Folder", item.displayFolder),
         ("Path", item.path),
         ("Kind", item.isPackage ? "Package" : item.isDirectory ? "Folder" : "File"),
         ("Size", ByteFormat.string(item.logicalSize, lowerBound: item.listingFailed)),
         ("Size on disk", ByteFormat.string(item.allocatedSize)),
         ("Modified", item.modified?.formatted(date: .abbreviated, time: .standard) ?? "Unknown"),
         // The later of this and Modified is when an item counts as stuck.
         ("Arrived here", item.inPlaceSince?.formatted(date: .abbreviated, time: .standard) ?? "Unknown"),
         ("Backup", backupText(item.path))]
    }

    private func syncFacts(_ item: ItemRecord) -> [Fact] {
        var facts: [Fact] = [
            ("Status", ICloudClassifier.status(of: item).label),
            ("In iCloud", yesNo(item.isUbiquitous)),
            ("Uploaded", yesNo(item.isUploaded)),
            ("Uploading", yesNo(item.isUploading)),
            ("Download state", downloadText(item.downloadingStatus)),
            ("Unresolved conflicts", yesNo(item.hasUnresolvedConflicts)),
            ("Excluded from sync", yesNo(item.isExcludedFromSync)),
            ("Content on this Mac", item.isDataless ? "No (dataless)" : "Yes"),
        ]
        if let error = item.uploadingError { facts += errorFacts("Upload error", error) }
        if let error = item.downloadingError { facts += errorFacts("Download error", error) }
        return facts
    }

    private func fileSystemFacts(_ item: ItemRecord) -> [Fact] {
        var facts: [Fact] = [("BSD flags", item.bsdFlags.map { String(format: "0x%08X", $0) } ?? "Unknown")]
        if let count = item.descendantCount { facts.append(("Items inside", count.formatted())) }
        facts.append(("Listing failed", item.listingFailed ? "Yes" : "No"))
        return facts
    }

    private func errorFacts(_ label: String, _ error: ItemError) -> [Fact] {
        [(label, error.message), ("Error domain", error.domain), ("Error code", String(error.code))]
    }

    /// "Label: value" lines, ready to paste into a support request.
    private func copy(_ title: String, _ facts: [Fact]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(facts.map { "\($0.label): \($0.value)" }.joined(separator: "\n"), forType: .string)
        copied = title
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copied == title { copied = nil }
        }
    }

    private func downloadText(_ status: DownloadingStatus?) -> String {
        switch status {
        case .current?: "Current"
        case .downloaded?: "Downloaded (older version)"
        case .notDownloaded?: "Not downloaded"
        case nil: "Unknown"
        }
    }

    private func yesNo(_ value: Bool?) -> String {
        value.map { $0 ? "Yes" : "No" } ?? "Unknown"
    }

    private func backupText(_ path: String) -> String {
        // `backups` is newest first.
        guard let backup = store.backups.first(where: { $0.verifiedEntry(for: path) != nil }) else { return "None" }
        return "Verified, \(backup.created.formatted(date: .abbreviated, time: .shortened))"
    }
}

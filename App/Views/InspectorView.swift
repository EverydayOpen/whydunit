import SwiftUI
import WhydunitCore

/// Technical details of the one selected item: every raw value macOS reported, monospaced and selectable.
struct InspectorView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.selection.count == 1, let path = store.selection.first, let item = store.itemsByPath[path] {
            Form {
                Section("Item") {
                    row("Name", item.name)
                    row("Folder", item.displayFolder)
                    stackedRow("Path", item.path)
                    row("Kind", item.isPackage ? "Package" : item.isDirectory ? "Folder" : "File")
                    row("Size", ByteFormat.string(item.logicalSize, lowerBound: item.listingFailed))
                    row("Size on disk", ByteFormat.string(item.allocatedSize))
                    row("Modified", item.modified?.formatted(date: .abbreviated, time: .standard) ?? "Unknown")
                    // The later of this and Modified is when an item counts as stuck.
                    row("Arrived here", item.inPlaceSince?.formatted(date: .abbreviated, time: .standard) ?? "Unknown")
                    row("Backup", backupText(item.path))
                }
                Section("Sync State") {
                    row("Status", ICloudClassifier.status(of: item).label)
                    row("In iCloud", yesNo(item.isUbiquitous))
                    row("Uploaded", yesNo(item.isUploaded))
                    row("Uploading", yesNo(item.isUploading))
                    row("Download state", downloadText(item.downloadingStatus))
                    row("Unresolved conflicts", yesNo(item.hasUnresolvedConflicts))
                    row("Excluded from sync", yesNo(item.isExcludedFromSync))
                    row("Content on this Mac", item.isDataless ? "No (dataless)" : "Yes")
                    if let error = item.uploadingError { errorRows("Upload error", error) }
                    if let error = item.downloadingError { errorRows("Download error", error) }
                }
                Section("File System") {
                    row("BSD flags", item.bsdFlags.map { String(format: "0x%08X", $0) } ?? "Unknown")
                    if let count = item.descendantCount { row("Items inside", count.formatted()) }
                    row("Listing failed", item.listingFailed ? "Yes" : "No")
                }
            }
            .formStyle(.grouped)
        } else if store.selection.count > 1 {
            ContentUnavailableView("\(store.selection.count.formatted()) Items Selected", systemImage: "sidebar.trailing",
                                   description: Text("Select one item to see its technical details."))
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.trailing")
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
    }

    /// Long values (a path, an error message) under their label, instead of wrapped in the narrow value column.
    private func stackedRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func errorRows(_ label: LocalizedStringKey, _ error: ItemError) -> some View {
        stackedRow(label, error.message)
        row("Error domain", error.domain)
        row("Error code", String(error.code))
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

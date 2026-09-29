import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WhydunitCore
import WhydunitMac

struct BackupsView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingTrash: BackupManifest?

    var body: some View {
        if store.backups.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("No Backups Yet")
                } icon: {
                    Image(systemName: "clock.arrow.circlepath").symbolRenderingMode(.hierarchical).foregroundStyle(.tint)
                }
            } description: {
                Text("Backups you make are saved in “\(folderName)” and listed here.")
            }
            .skyBackdrop()
        } else {
            // One porcelain group like Summary's, on the Sky, instead of a bare system list.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(store.backups.enumerated()), id: \.element.id) { i, backup in
                        row(backup)
                            .padding(.horizontal, Space.m)
                            .overlay(alignment: .top) {
                                if i > 0 { Divider().padding(.leading, 60) }   // 16 + 32 icon + 12: under the date
                            }
                    }
                }
                .surface(16)
                .frame(maxWidth: 760)
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.l)
                .frame(maxWidth: .infinity)
            }
            .background { Sky() }
            .confirmationDialog("Move this backup to the Trash?",
                                isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } }),
                                presenting: pendingTrash) { backup in
                // VERIFY: Return must not trigger the destructive button in this dialog.
                Button("Move to Trash", role: .destructive) { trash(backup) }
                Button("Cancel", role: .cancel) {}
            } message: { backup in
                Text("The backup from \(backup.created.formatted(date: .abbreviated, time: .shortened)) (\(itemCount(backup.entries.count))) goes to the Trash, where you can still put it back. Your files in iCloud Drive aren't touched.")
            }
        }
    }

    private var folderName: String { (store.backupsRoot.path as NSString).abbreviatingWithTildeInPath }

    /// Finder's own folder icon (a Mac object, not a tile; it's the type's icon, so nothing on disk is read), the date,
    /// the size, the verification tag and Show in Finder (DESIGN.md §5.2). Move to Trash… is in the context menu, so
    /// the destructive action isn't one click away on every row.
    private func row(_ backup: BackupManifest) -> some View {
        HStack(spacing: Space.s) {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(backup.created.formatted(date: .abbreviated, time: .shortened))
                    .font(.body.weight(.medium))
                    .monospacedDigit()   // the digits line up without a typewriter face
                Text(ByteFormat.string(backup.totalBytes))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            verifiedTag(backup)
            Button("Show in Finder") { FinderBridge.reveal([backup.folder]) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .padding(.vertical, Space.xs)
        .contentShape(Rectangle())   // the whole row opens the menu, not just its text and icons
        .contextMenu {
            Button("Show in Finder") { FinderBridge.reveal([backup.folder]) }
            Divider()
            Button("Move to Trash…") { pendingTrash = backup }
        }
    }

    /// "Verified · 14 items", or "12 of 14 verified" in orange when a copy didn't verify.
    private func verifiedTag(_ backup: BackupManifest) -> some View {
        let total = backup.entries.count
        return backup.isFullyVerified
            ? Tag(text: "Verified · \(itemCount(total))", tint: .green)
            : Tag(text: "\(backup.entries.filter(\.verified).count) of \(total) verified", tint: Severity.warning.color)
    }

    private func trash(_ backup: BackupManifest) {
        Task {
            do {
                try await store.trashBackup(backup)   // logged, then the list is re-read
            } catch {
                // A sheet on the main window; app-modal only when there's no window.
                let alert = NSAlert(error: error)
                if let window = NSApp.keyWindow { alert.beginSheetModal(for: window, completionHandler: nil) } else { alert.runModal() }
            }
        }
    }
}

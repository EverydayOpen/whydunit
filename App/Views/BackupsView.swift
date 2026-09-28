import AppKit
import SwiftUI
import WhydunitCore
import WhydunitMac

struct BackupsView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingTrash: BackupManifest?

    var body: some View {
        if store.backups.isEmpty {
            ContentUnavailableView("No Backups Yet", systemImage: "clock.arrow.circlepath",
                                   description: Text("Backups you make are saved in “\(folderName)” and listed here."))
        } else {
            List(store.backups) { backup in
                row(backup)
            }
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

    private func row(_ backup: BackupManifest) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: "folder.fill")
                .tile(.teal, size: 32)   // the Backups tile in the sidebar
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(backup.created.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text(ByteFormat.string(backup.totalBytes))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            verifiedTag(backup)
            Button("Show in Finder") { FinderBridge.reveal([backup.folder]) }
                .controlSize(.small)
            Button("Move to Trash…") { pendingTrash = backup }
                .controlSize(.small)
        }
        .padding(.vertical, Space.xs)
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

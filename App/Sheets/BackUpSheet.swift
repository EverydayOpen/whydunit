import SwiftUI
import WhydunitCore
import WhydunitMac

/// Review → running → done. Return starts it, because a backup only copies.
struct BackUpSheet: View {
    let paths: [String]
    /// Set when opened from Retry Upload's "Back Up These…": Done continues to that retry.
    var thenRetry: [String]? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable { case review, running, done(BackupManifest) }
    @State private var phase = Phase.review
    @State private var progress: BackupProgress?
    @State private var errorText: String?
    @State private var task: Task<Void, Never>?
    @State private var freeBytes: Int64?

    /// Items whose content is only in iCloud can't be copied without downloading them, so they're left out.
    private var local: [String] { paths.filter { store.itemsByPath[$0]?.isDataless != true } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            switch phase {
            case .review: review
            case .running: running
            case .done(let manifest): done(manifest)
            }
        }
        .padding(Space.l)
        .frame(width: 560, alignment: .leading)
        .animation(Motion.standard(reduceMotion), value: phase)
        .interactiveDismissDisabled(phase == .running)
        .task {
            let root = store.backupsRoot
            // Off the main actor: it can block on a busy fileproviderd.
            freeBytes = await Task.detached {
                // The backups folder may not exist yet, and resourceValues fails on a missing path.
                var url = root
                while !FileManager.default.fileExists(atPath: url.path), url.pathComponents.count > 1 { url.deleteLastPathComponent() }
                return SystemInfo.freeBytes(at: url)
            }.value
        }
    }

    @ViewBuilder private var review: some View {
        Text("Back Up Selected Items").font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
        Text("Each item is copied to “\(folderName)”, and every copy is checked against the original. Nothing in iCloud Drive is changed.")
            .fixedSize(horizontal: false, vertical: true)
        // Hidden when every item is left out: an empty list and "Total: Unknown" look broken.
        if !local.isEmpty {
            ItemList(paths: local) { path in
                Text(ByteFormat.string(store.itemsByPath[path]?.logicalSize))
            }
            Text(spaceText)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        if notEnoughSpace {
            Label("Not enough free space. A backup needs twice its size free, for the copies and a safety margin. Free up some space, or choose another backups folder in Settings.",
                  systemImage: "exclamationmark.circle")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if local.count < paths.count {
            Text("\(itemCount(paths.count - local.count)) left out because only iCloud has the content, not this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        if let errorText {
            Label {
                Text(errorText).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle")
            }
            .foregroundStyle(.secondary)
        }
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Back Up") { start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(local.isEmpty || notEnoughSpace)
        }
    }

    @ViewBuilder private var running: some View {
        Text("Backing Up…").font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
        ProgressView(value: progress.map { min(Double($0.completed) / Double(max($0.total, 1)), 0.99) })
            .progressViewStyle(.linear)
        HStack {
            Text(progress?.currentName ?? "Preparing…")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let progress {
                Text("\(progress.completed) of \(progress.total)").monospacedDigit()
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        HStack {
            Text("Stop finishes the current item first. Copies already checked are kept.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Stop") { task?.cancel() }
                .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder private func done(_ manifest: BackupManifest) -> some View {
        Label {
            Text("\(itemCount(manifest.entries.filter(\.verified).count)) backed up and verified")
                .font(.title3.weight(.semibold))
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .accessibilityAddTraits(.isHeader)
        Text("The copies are in “\((manifest.folder as NSString).abbreviatingWithTildeInPath)”. Nothing in iCloud Drive was changed.")
            .fixedSize(horizontal: false, vertical: true)
        HStack {
            Button("Show Backup in Finder") { FinderBridge.reveal([manifest.folder]) }
            Spacer()
            if let thenRetry {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Continue to Retry Upload") { store.sheet = .retryUpload(paths: thenRetry) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var folderName: String { (store.backupsRoot.path as NSString).abbreviatingWithTildeInPath }

    /// Folder sizes aren't known here, so `bytes` is nil when no size is known and a lower bound when some are.
    private var total: (bytes: Int64?, partial: Bool) {
        let sizes = local.compactMap { store.itemsByPath[$0]?.logicalSize }
        return (sizes.isEmpty ? nil : sizes.reduce(0, +), sizes.count < local.count)
    }

    /// "Total: 1.1 GB · Needs 2.2 GB free · 41 GB available". BackupService needs twice the size free.
    private var spaceText: String {
        var parts = ["Total: \(ByteFormat.string(total.bytes, lowerBound: total.partial))"]
        if let bytes = total.bytes { parts.append("Needs \(total.partial ? "at least " : "")\(ByteFormat.string(2 * bytes)) free") }
        if let freeBytes { parts.append("\(ByteFormat.string(freeBytes)) available") }
        return parts.joined(separator: " · ")
    }

    private var notEnoughSpace: Bool {
        guard let bytes = total.bytes, let freeBytes else { return false }
        return 2 * bytes > freeBytes
    }

    private func start() {
        errorText = nil
        progress = nil
        phase = .running
        task = Task {
            do {
                let manifest = try await store.backUp(paths: local) { progress = $0 }
                phase = .done(manifest)
            } catch let error as CocoaError where error.code == .userCancelled {
                // Stop is deliberate, not a failure: the kept copies are on the Backups page and in Activity.
                dismiss()
            } catch {
                errorText = error.localizedDescription
                phase = .review
            }
        }
    }
}

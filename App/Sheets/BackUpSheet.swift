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
    /// Set once the done step has turned in, so the seal bounces after the swap, not during it.
    @State private var landed = false

    /// Items whose content is only in iCloud can't be copied without downloading them, so they're left out.
    private var local: [String] { paths.filter { store.itemsByPath[$0]?.isDataless != true } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch phase {
            case .review: sheetStep(reduceMotion) { review }
            case .running: sheetStep(reduceMotion) { running }
            case .done(let manifest): sheetStep(reduceMotion) { done(manifest) }
            }
        }
        .padding(Space.l)
        .frame(width: 560, alignment: .leading)
        .overlay(alignment: .topTrailing) { StepDots(count: 3, current: stepIndex) }
        // Bordered so Cancel takes the capsule too. VERIFY: Apple documents .capsule as having no effect on
        // non-widget buttons through macOS 15, so this should only show on 26.
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .animation(Motion.spring(reduceMotion), value: phase)
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
        SheetHeader(symbol: "externaldrive.badge.checkmark", title: "Back Up Selected Items",
                    detail: "Each item is copied to “\(folderName)”, and every copy is checked against the original. Nothing in iCloud Drive is changed.")
            .accessibilityAddTraits(.isHeader)
        // Hidden when every item is left out: an empty list and "Total: Unknown" look broken.
        if !local.isEmpty {
            ItemList(paths: local) { path in
                Text(ByteFormat.string(store.itemsByPath[path]?.logicalSize))
            }
        }
        SafetyChecks {
            if !local.isEmpty { SafetyCheck(text: spaceText, unmet: spaceMark) }
            if local.count < paths.count {
                SafetyCheck(text: "\(itemCount(paths.count - local.count)) left out because only iCloud has the content, not this Mac.",
                            unmet: "minus.circle")
            } else {
                SafetyCheck(text: "Every item is on this Mac.")
            }
        }
        if notEnoughSpace {
            Text("Not enough free space. A backup needs twice its size free, for the copies and a safety margin. Free up some space, or choose another backups folder in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        SheetHeader(symbol: "externaldrive.badge.checkmark", title: "Backing Up…",
                    detail: "Stop finishes the current item first. Copies already checked are kept.")
            .accessibilityAddTraits(.isHeader)
        ProgressView(value: progress.map { min(Double($0.completed) / Double(max($0.total, 1)), 0.99) })
            .progressViewStyle(.linear)
        HStack {
            Text(progress?.currentName ?? "Preparing…")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let progress {
                Text("\(progress.completed) of \(progress.total)")
                    .font(.system(.callout, design: .rounded))
                    .monospacedDigit()
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        HStack {
            Spacer()
            Button("Stop") { task?.cancel() }
                .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder private func done(_ manifest: BackupManifest) -> some View {
        // SheetHeader's layout with the seal landing in place of the well (DESIGN.md §5.2).
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: landed)
                .symbolEffectsRemoved(reduceMotion)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
                .task {
                    try? await Task.sleep(for: .milliseconds(350))
                    landed = true
                }
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("\(itemCount(manifest.entries.filter(\.verified).count)) backed up and verified")
                    .font(.title2.weight(.bold))
                Text("The copies are in “\((manifest.folder as NSString).abbreviatingWithTildeInPath)”. Nothing in iCloud Drive was changed.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Tag(text: "SHA-256", tint: .green)
                    .padding(.top, Space.xxs)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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

    private var stepIndex: Int {
        switch phase {
        case .review: 0
        case .running: 1
        case .done: 2
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

    /// A green check only when both sizes are known in full and there's room; BackupService checks again at the start.
    private var spaceMark: String? {
        if notEnoughSpace { return "exclamationmark.circle" }
        return total.bytes == nil || total.partial || freeBytes == nil ? "questionmark.circle" : nil
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

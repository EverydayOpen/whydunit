import SwiftUI
import WhydunitCore
import WhydunitMac

/// Review (with the cross-device warning) → running, one item at a time → per-item outcomes.
struct RetryUploadSheet: View {
    let paths: [String]
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case review, running, done }
    @State private var phase = Phase.review
    @State private var current: String?
    @State private var outcomes: [String: RetryOutcome] = [:]
    /// The items handed to the retrier, frozen so the list can't shift while it runs.
    @State private var started: [String] = []

    /// Moving an item out of iCloud is only allowed with a verified copy of that exact item.
    private var ready: [String] { paths.filter { hasVerifiedBackup($0) } }
    private var needsBackup: [String] { paths.filter { !hasVerifiedBackup($0) } }
    /// AppStore.retryUpload skips every item while the upload check says sync is stalled.
    private var syncStalled: Bool { store.isSyncStalled }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch phase {
            case .review: sheetStep(reduceMotion) { review }
            case .running: sheetStep(reduceMotion) { running }
            case .done: sheetStep(reduceMotion) { done }
            }
        }
        .padding(Space.l)
        .frame(width: 560, alignment: .leading)
        .overlay(alignment: .topTrailing) { StepDots(count: 3, current: stepIndex) }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .animation(Motion.spring(reduceMotion), value: phase)
        .interactiveDismissDisabled(phase == .running)
    }

    @ViewBuilder private var review: some View {
        SheetHeader(symbol: "icloud.and.arrow.up", title: "Retry Upload",
                    detail: "Each item is moved out of iCloud Drive and back in, one at a time, so iCloud picks it up again. While an item is out, it disappears from your other devices for a moment.")
            .accessibilityAddTraits(.isHeader)
        SafetyChecks {
            SafetyCheck(text: "Only items with a verified backup are moved.")
            SafetyCheck(text: "Nothing is deleted.")
            if syncStalled {
                SafetyCheck(text: "iCloud isn't uploading anything right now, so a retry would only wait behind it. Restart iCloud Sync first.",
                            unmet: "exclamationmark.circle")
            }
        }
        if !ready.isEmpty {
            ItemList(paths: ready) { _ in Text("Backed up") }
        }
        if !needsBackup.isEmpty {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Back Up First").font(.headline).accessibilityAddTraits(.isHeader)
                Text(needsBackup.count == 1 ? "This item has no verified backup yet, so it's left out."
                                            : "These have no verified backup yet, so they're left out.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ItemList(paths: needsBackup) { _ in Text("Back up first") }
                if !ready.isEmpty || syncStalled { backUpButton }
            }
        }
        HStack {
            Text("Each item can take up to 2 minutes.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            if syncStalled {
                // Every item would come back Skipped, so the one next step is restarting sync.
                Button("Restart iCloud Sync…") { store.sheet = .restartSync }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else if ready.isEmpty {
                // Nothing can be retried yet, so backing up is the one next step.
                backUpButton
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(needsBackup.isEmpty)
            } else {
                Button("Retry Upload") { start() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // VERIFY: changing the sheet item swaps this sheet for the backup sheet in place.
    /// The backup sheet's Done continues back to this retry.
    private var backUpButton: some View {
        Button(needsBackup.count == 1 ? "Back Up This Item…" : "Back Up These…") {
            store.sheet = .backUp(paths: needsBackup, thenRetry: paths)
        }
    }

    @ViewBuilder private var running: some View {
        SheetHeader(symbol: "icloud.and.arrow.up", title: "Retrying Upload…",
                    detail: store.stopRequested ? "Stopping after this item…" : "Stop finishes the current item first.")
            .accessibilityAddTraits(.isHeader)
        ProgressView(value: Double(outcomes.count), total: Double(max(started.count, 1)))
        ItemList(paths: started) { path in
            if let outcome = outcomes[path] {
                outcomeLabel(outcome)
            } else if path == current {
                HStack(spacing: Space.xxs) {
                    ProgressView().controlSize(.small)
                    Text("Retrying…")   // most of an item's turn is waiting for iCloud, not the move
                }
            } else {
                Text("Waiting")
            }
        }
        HStack {
            Spacer()
            Button("Stop") { store.stopRequested = true }
                .keyboardShortcut(.cancelAction)
                .disabled(store.stopRequested)
        }
    }

    @ViewBuilder private var done: some View {
        let uploaded = outcomes.values.filter { if case .uploaded = $0 { true } else { false } }.count
        SheetHeader(symbol: "icloud.and.arrow.up", title: "\(uploaded) of \(itemCount(started.count)) uploaded",
                    detail: outcomes.values.contains(.stillWaiting)
                        ? "Items still waiting may finish uploading on their own. Scan again later to check. Their backups are kept."
                        : "Each result is also in Activity.")
            .accessibilityAddTraits(.isHeader)
        ItemList(paths: started) { path in
            if let outcome = outcomes[path] { outcomeLabel(outcome) } else { Text("Not started") }
        }
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func outcomeLabel(_ outcome: RetryOutcome) -> some View {
        let style: (text: String, symbol: String, color: Color) = switch outcome {
        case .uploaded: ("Uploaded", "checkmark.circle.fill", .green)
        case .stillWaiting: ("Still waiting", Severity.warning.symbol, Severity.warning.color)
        case .skipped(let reason): ("Skipped: \(reason)", "minus.circle", .secondary)
        case .failed(let reason): ("Failed: \(reason)", "exclamationmark.circle", .secondary)
        }
        return Label {
            // Wraps: a failed move back names the staging path the item is safe in.
            Text(style.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .help(style.text)
        } icon: {
            Image(systemName: style.symbol).foregroundStyle(style.color)
        }
    }

    private var stepIndex: Int {
        switch phase {
        case .review: 0
        case .running: 1
        case .done: 2
        }
    }

    /// The copy the retry will use: verified, and not inside iCloud.
    private func hasVerifiedBackup(_ path: String) -> Bool {
        store.verifiedBackup(for: path) != nil
    }

    private func start() {
        let items = ready
        started = items
        phase = .running
        // Not tied to the sheet's lifetime: an item that is out of iCloud must always be moved back.
        Task {
            await store.retryUpload(paths: items) { path, outcome in
                if let outcome { outcomes[path] = outcome } else { current = path }
            }
            current = nil
            phase = .done
        }
    }
}

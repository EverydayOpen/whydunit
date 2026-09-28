import SwiftUI
import WhydunitCore

/// Consent for restarting the user's own `bird` process, then the result.
struct RestartSyncSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    /// The logged entry, once the restart has been tried.
    @State private var result: AuditEntry?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let result {
                sheetStep(reduceMotion) {
                    SheetHeader(symbol: "arrow.clockwise.icloud", title: title, detail: message(result))
                        .accessibilityAddTraits(.isHeader)
                    HStack {
                        Spacer()
                        // No Scan Again here: the text says to wait a few minutes first.
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                    }
                }
            } else {
                sheetStep(reduceMotion) { consent }
            }
        }
        .padding(Space.l)
        .frame(width: 560, alignment: .leading)
        .overlay(alignment: .topTrailing) { StepDots(count: 2, current: result == nil ? 0 : 1) }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .animation(Motion.spring(reduceMotion), value: result == nil)
        .interactiveDismissDisabled(running)
    }

    @ViewBuilder private var consent: some View {
        SheetHeader(symbol: "arrow.clockwise.icloud", title: title,
                    detail: "This restarts your Mac's iCloud sync process (bird). macOS starts it again automatically.")
            .accessibilityAddTraits(.isHeader)
        SafetyChecks {
            SafetyCheck(text: "Nothing is deleted and no files are moved.")
        }
        Text("Afterwards, wait a few minutes, then scan again.")
            .foregroundStyle(.secondary)
        HStack {
            if running {
                ProgressView().controlSize(.small)
                Text("Restarting…").foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(running)
            Button("Restart iCloud Sync") {
                running = true
                Task {
                    result = await store.restartSync()
                    running = false
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(running)
        }
    }

    private var title: String {
        switch result?.outcome {
        case nil: "Restart iCloud Sync"
        case .succeeded?: "iCloud Sync Restarted"
        case .skipped?: "iCloud Sync Wasn't Running"
        case .failed?: "iCloud Sync Not Restarted"
        }
    }

    private func message(_ entry: AuditEntry) -> String {
        switch entry.outcome {
        case .succeeded: "Wait a few minutes, then scan again to see whether files are moving."
        case .skipped: "Nothing was restarted. macOS starts iCloud sync again when it's needed."
        case .failed: "Nothing was restarted: \(entry.detail)"
        }
    }
}

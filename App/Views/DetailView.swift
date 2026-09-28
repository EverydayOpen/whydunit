import SwiftUI
import WhydunitCore
import WhydunitMac

struct DetailView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.route ?? .summary {
        case .summary: summary.navigationTitle("Summary")
        case .finding(let rule): FindingDetailView(rule: rule).navigationTitle(rule.shortName)
        case .backups: BackupsView().navigationTitle("Backups")
        case .activity: ActivityView().navigationTitle("Activity")
        }
    }

    @ViewBuilder private var summary: some View {
        if store.locations.cloudDocs == nil {
            ContentUnavailableView {
                Label("iCloud Drive Is Off", systemImage: "icloud.slash")
            } description: {
                Text("Turn on iCloud Drive in System Settings › Apple Account › iCloud, then scan again.")
            } actions: {
                Button("Open iCloud Settings") { FinderBridge.openICloudSettings() }
                    .buttonStyle(.borderedProminent)
                Button("Scan Again") { store.scan() }
            }
        } else if let diagnosis = store.diagnosis {
            if diagnosis.checkedCount == 0, case .scanning(let phase, let itemsSeen, let fraction) = store.scanState {
                // Nothing checked to keep on screen (Scan Again after granting access), so the first-scan progress.
                scanning(phase: phase, itemsSeen: itemsSeen, fraction: fraction)
            } else if diagnosis.checkedCount == 0, let denied = store.finding(.permissionDenied) {
                ContentUnavailableView {
                    Label("Permission Needed", systemImage: "lock.shield")
                } description: {
                    // The title names the denied folders: "Desktop and Documents couldn't be checked".
                    Text("\(denied.title) because macOS didn't allow access. Allow it in Privacy & Security › Files & Folders, then scan again.")
                } actions: {
                    Button("Open Privacy Settings") { FinderBridge.openPrivacySettings() }
                        .buttonStyle(.borderedProminent)
                    Button("Scan Again") { store.scan() }
                }
            } else {
                // Rescans keep the last result on screen; the toolbar shows progress.
                SummaryView(diagnosis: diagnosis)
            }
        } else {
            switch store.scanState {
            case .scanning(let phase, let itemsSeen, let fraction):
                scanning(phase: phase, itemsSeen: itemsSeen, fraction: fraction)
            case .failed(let message):
                ContentUnavailableView {
                    Label("The Scan Didn't Finish", systemImage: "exclamationmark.circle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { store.scan() }
                }
            case .never, .done:
                WelcomeView()
            }
        }
    }

    /// First scan only: nothing to show yet, so a centred progress bar like Software Update.
    private func scanning(phase: String, itemsSeen: Int, fraction: Double?) -> some View {
        VStack(spacing: Space.s) {
            ProgressView(value: fraction.map { min($0, 0.99) })
                .progressViewStyle(.linear)
                .frame(width: 320)
            Text(phase)
                .font(.headline)
                .contentTransition(.opacity)
            if itemsSeen > 0 {
                Text("\(itemCount(itemsSeen)) checked")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if phase == AppStore.probePhase {
                Text("This can take up to 2 minutes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

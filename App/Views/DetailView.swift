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
                Label { Text("iCloud Drive Is Off") } icon: { skyIcon("icloud.slash") }
            } description: {
                Text("Turn on iCloud Drive in System Settings › Apple Account › iCloud, then scan again.")
            } actions: {
                Button("Open iCloud Settings") { FinderBridge.openICloudSettings() }
                    .buttonStyle(.borderedProminent)
                Button("Scan Again") { store.scan() }
            }
            .skyBackground()
        } else if let diagnosis = store.diagnosis {
            if diagnosis.checkedCount == 0, case .scanning(let phase, let itemsSeen, let fraction) = store.scanState {
                // Nothing checked to keep on screen (Scan Again after granting access), so the first-scan progress.
                scanning(phase: phase, itemsSeen: itemsSeen, fraction: fraction)
            } else if diagnosis.checkedCount == 0, let denied = store.finding(.permissionDenied) {
                ContentUnavailableView {
                    Label { Text("Permission Needed") } icon: { skyIcon("lock.shield") }
                } description: {
                    // The title names the denied folders: "Desktop and Documents couldn't be checked".
                    Text("\(denied.title) because macOS didn't allow access. Allow it in Privacy & Security › Files & Folders, then scan again.")
                } actions: {
                    Button("Open Privacy Settings") { FinderBridge.openPrivacySettings() }
                        .buttonStyle(.borderedProminent)
                    Button("Scan Again") { store.scan() }
                }
                .skyBackground()
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
                    Label { Text("The Scan Didn't Finish") } icon: { skyIcon("exclamationmark.circle") }
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { store.scan() }
                }
                .skyBackground()
            case .never, .done:
                WelcomeView()
            }
        }
    }

    /// Empty and error states show their symbol in the accent, over the sky (DESIGN.md §5.2).
    private func skyIcon(_ name: String) -> some View {
        Image(systemName: name).symbolRenderingMode(.hierarchical).foregroundStyle(.tint)
    }

    /// First scan only: nothing to show yet, so the glyph over a centred progress bar like Software Update.
    private func scanning(phase: String, itemsSeen: Int, fraction: Double?) -> some View {
        VStack(spacing: Space.s) {
            ScanGlyph()
            ProgressView(value: fraction.map { min($0, 0.99) })
                .progressViewStyle(.linear)
                .frame(width: 320)
            Text(phase)
                .font(.headline)
                .contentTransition(.opacity)
            if itemsSeen > 0 {
                Text("\(itemCount(itemsSeen)) checked")
                    .font(.system(.callout, design: .rounded))
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
        .accessibilityElement(children: .combine)
        .skyBackground()
    }
}

private extension View {
    func skyBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity).background { Sky() }
    }
}

/// While the first scan runs: a document turns as it rises into the cloud (MOTION.md §3.3). It exists only in the
/// first-scan view, so the loop stops with the scan. A still cloud under Reduce Motion.
private struct ScanGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Rise: CaseIterable { case below, middle, inside }

    var body: some View {
        ZStack {
            Image(systemName: "icloud")
                .font(.system(size: 72, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            if !reduceMotion {
                Image(systemName: "doc.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)
                    .phaseAnimator(Rise.allCases) { doc, phase in
                        doc
                            .rotation3DEffect(.degrees(phase == .below ? 0 : phase == .middle ? 180 : 360), axis: (x: 0, y: 1, z: 0))
                            .offset(y: phase == .below ? 52 : phase == .middle ? 23 : 5)
                            .scaleEffect(phase == .inside ? 0.6 : 1)
                            .opacity(phase == .middle ? 1 : 0)
                    } animation: { phase in
                        phase == .below ? nil : .easeInOut(duration: 0.8)   // the jump back is invisible
                    }
            }
        }
        .frame(height: 120)
        .accessibilityHidden(true)
    }
}

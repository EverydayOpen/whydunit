import SwiftUI
import WhydunitCore
import WhydunitMac

struct SummaryView: View {
    @Environment(AppStore.self) private var store
    @State private var freeBytes: Int64?
    /// Copy Diagnosis shows "Copied" for a moment, since copying has no other visible effect.
    @State private var copied = false
    let diagnosis: Diagnosis

    var body: some View {
        Form {
            Section {
                HStack(spacing: Space.s) {
                    SeverityIcon(severity: diagnosis.verdict, size: 28)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(diagnosis.headline?.title ?? "No problems found")
                            .font(.title2.weight(.semibold))
                        Text(meta)
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if case .failed(let message) = store.scanState {
                            Text("The last scan didn't finish: \(message)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, Space.xs)
                .accessibilityElement(children: .combine)
            }

            if !diagnosis.findings.isEmpty {
                Section("Findings") {
                    ForEach(diagnosis.findings) { finding in
                        Button { store.route = .finding(finding.rule) } label: { row(finding) }
                            .buttonStyle(.plain)
                    }
                }
            }

            Section("iCloud Drive") {
                LabeledContent("Sync check", value: probeText)
                // The scan's value until the fresh one arrives, instead of flashing "Unknown".
                LabeledContent("Free on this Mac", value: ByteFormat.string(freeBytes ?? store.freeBytes))
                LabeledContent {
                    Text(scannedFolders)
                } label: {
                    Text("Scanned folders")
                    Text("App folders such as Pages and Numbers aren't checked yet.")
                }
                // The Sync Stalled and Upload Errors steps say to copy the diagnosis for Apple Support.
                LabeledContent {
                    Button(copied ? "Copied" : "Copy Diagnosis") {
                        store.copyDiagnosis()
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    }
                } label: {
                    Text("Diagnosis")
                    Text("Plain text to share with Apple Support.")
                }
            }
        }
        .formStyle(.grouped)
        .task(id: diagnosis.scannedAt) {
            // Off the main actor: it can block on a busy fileproviderd.
            freeBytes = await Task.detached { SystemInfo.freeBytes(at: SystemInfo.homeDirectory) }.value
        }
    }

    private func row(_ finding: Finding) -> some View {
        HStack(spacing: Space.s) {
            SeverityIcon(severity: finding.severity, showsWord: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                Text(finding.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.xs)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    /// "4,213 items checked · 2 need attention · 3 items with no sync status · 1 folder couldn't be checked",
    /// zero parts left out.
    private var meta: String {
        let attention = diagnosis.findings.filter { $0.severity >= .warning }.count
        var parts = ["\(itemCount(diagnosis.checkedCount)) checked"]
        if attention > 0 { parts.append(attention == 1 ? "1 needs attention" : "\(attention) need attention") }
        if diagnosis.unknownCount > 0 { parts.append("\(itemCount(diagnosis.unknownCount)) with no sync status") }
        if let f = diagnosis.findings.first(where: { $0.rule == .unreadableFolders }) {
            let n = f.itemPaths.count
            parts.append(n == 1 ? "1 folder couldn't be checked" : "\(n.formatted()) folders couldn't be checked")
        }
        return parts.joined(separator: " · ")
    }

    private var probeText: String {
        switch store.probe {
        case .notRun: "Not run"
        case .uploaded(let seconds): "Working: a test file uploaded in \(duration(seconds))"
        case .notUploaded(let waited):
            // Other files still uploading means iCloud is busy, and the classifier doesn't report a stall.
            "\(store.isSyncStalled ? "Stalled" : "Busy"): a test file didn't upload in \(duration(waited))"
        case .unknown(let reason): "Unknown: \(reason)"
        }
    }

    /// "2 minutes", matching the Sync Stalled finding, instead of raw seconds.
    private func duration(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    private var scannedFolders: String {
        let names = ScanRoot.allCases.filter { store.locations.roots[$0] != nil }.map(\.displayName)
        return names.isEmpty ? "None" : names.formatted(.list(type: .and))
    }
}

import SwiftUI
import WhydunitCore
import WhydunitMac

/// The scan whose rows have flipped in; coming back to Summary shows them at rest (MOTION.md §3.4).
@MainActor private var flippedScan: Date?

struct SummaryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var freeBytes: Int64?
    /// Copy Diagnosis shows "Copied" for a moment, since copying has no other visible effect.
    @State private var copied = false
    @State private var shown: Bool
    let diagnosis: Diagnosis

    init(diagnosis: Diagnosis) {
        self.diagnosis = diagnosis
        _shown = State(initialValue: flippedScan == diagnosis.scannedAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The stage's one lifted object, over the Sky; the rows below stay native (DESIGN.md §3).
            hero
                .padding(Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {   // lit top edge, and the rim dark mode otherwise lacks
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                }
                .lifted()
                .flipIn(shown, index: 0, reduceMotion: reduceMotion)
                .padding(.horizontal, Space.l)   // aligns with the grouped Form's inset
                .padding(.top, Space.l)
            // VERIFY: the Form's own top inset doesn't double the gap under the card.
            Form {
                if !diagnosis.findings.isEmpty {
                    Section("Findings") {
                        // Only the row's content turns; the Form cell never does (MOTION §3.4). VERIFY cells don't clip it.
                        ForEach(Array(diagnosis.findings.enumerated()), id: \.element.id) { i, finding in
                            Button { store.route = .finding(finding.rule) } label: { FindingRow(finding: finding) }
                                .buttonStyle(.plain)
                                .flipIn(shown, index: i + 1, reduceMotion: reduceMotion)
                        }
                    }
                }

                Section("iCloud Drive") {
                    LabeledContent("Sync check") {
                        let p = probe
                        HStack(spacing: Space.xs) {
                            Tag(text: p.word, tint: p.tint)
                            if let detail = p.detail { Text(detail).monospacedDigit() }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    // The scan's value until the fresh one arrives, instead of flashing "Unknown".
                    LabeledContent("Free on this Mac") {
                        Text(ByteFormat.string(freeBytes ?? store.freeBytes)).monospacedDigit()
                    }
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
            .scrollContentBackground(.hidden)   // VERIFY: grouped cells keep their own fill over the wash
        }
        .background { Sky() }
        .task(id: diagnosis.scannedAt) {
            // After the first frame, so the rows have a start to flip from; a rescan shown here counts as flipped.
            flippedScan = diagnosis.scannedAt
            shown = true
            // Off the main actor: it can block on a busy fileproviderd.
            freeBytes = await Task.detached { SystemInfo.freeBytes(at: SystemInfo.homeDirectory) }.value
        }
    }

    private var hero: some View {
        HStack(spacing: Space.m) {
            // VERIFY: both symbol effects reach the Image inside SeverityIcon's tile.
            SeverityIcon(severity: diagnosis.verdict, size: 44, tile: true)
                .contentTransition(.symbolEffect(.replace))          // the verdict changed on a rescan
                .symbolEffect(.bounce, value: diagnosis.scannedAt)   // a new result landed
                .symbolEffectsRemoved(reduceMotion)
                // Always the accent, never the severity colour: severity never glows (DESIGN.md §1.1).
                .background {
                    RadialGradient(colors: [Color.accentColor.opacity(0.35), .clear], center: .center,
                                   startRadius: 0, endRadius: 40)
                        .frame(width: 80, height: 80)
                }
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(diagnosis.headline?.title ?? "No problems found")
                    .font(.title2.weight(.bold))
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
        .accessibilityElement(children: .combine)
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

    /// The upload check as a status tag ("Working") and what it measured ("a test file uploaded in 12 seconds").
    private var probe: (word: String, detail: String?, tint: Color) {
        switch store.probe {
        case .notRun: ("Not run", nil, .secondary)
        case .uploaded(let seconds): ("Working", "a test file uploaded in \(duration(seconds))", .green)
        case .notUploaded(let waited):
            // Other files still uploading means iCloud is busy, and the classifier doesn't report a stall.
            store.isSyncStalled
                ? ("Stalled", "a test file didn't upload in \(duration(waited))", Severity.critical.color)
                : ("Busy", "a test file didn't upload in \(duration(waited))", Severity.warning.color)
        case .unknown(let reason): ("Unknown", reason, .secondary)
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

/// Hover depth instead of table-row hover (MOTION.md §3.4): the tile lifts and the chevron slides.
private struct FindingRow: View {
    let finding: Finding
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lift = hovering && !reduceMotion
        HStack(spacing: Space.s) {
            SeverityIcon(severity: finding.severity, size: 24, showsWord: false, tile: true)
                .scaleEffect(lift ? 1.08 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                Text(finding.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.xs)
            // Mac-wide findings (Sync Stalled, Not Enough Space) have no items to count.
            if !finding.itemPaths.isEmpty {
                Tag(text: finding.itemPaths.count.formatted(), tint: finding.severity.color)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(itemCount(finding.itemPaths.count))
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(hovering ? .secondary : .tertiary)
                .offset(x: lift ? 3 : 0)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(Motion.follow) { hovering = h } }
    }
}

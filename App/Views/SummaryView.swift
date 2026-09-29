import SwiftUI
import WhydunitCore
import WhydunitMac

/// The scan whose rows have flipped in; coming back to Summary shows them at rest (MOTION.md §3.4).
@MainActor private var flippedScan: Date?

/// A scroll of porcelain surfaces on the Sky (DESIGN.md §5.2): the verdict plate, the findings split into
/// "Needs attention" and "Good to know", then the iCloud Drive facts.
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
        // View-level grouping only; the findings keep the classifier's worst-first order.
        let attention = diagnosis.findings.filter { $0.severity >= .warning }
        let notes = diagnosis.findings.filter { $0.severity < .warning }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                plate
                    .flipIn(shown, index: 0, reduceMotion: reduceMotion)
                if !attention.isEmpty { group("Needs attention", attention, from: 1) }
                if !notes.isEmpty { group("Good to know", notes, from: 1 + attention.count) }
                facts
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.l)
            .frame(maxWidth: .infinity)
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

    /// The stage's one lifted object: the verdict, Copy Diagnosis, and three numbers.
    private var plate: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                HStack(spacing: Space.m) {
                    // VERIFY: both symbol effects reach the Image inside SeverityIcon's tile.
                    SeverityIcon(severity: diagnosis.verdict, size: 52, tile: true)
                        .contentTransition(.symbolEffect(.replace))          // the verdict changed on a rescan
                        .symbolEffect(.bounce, value: diagnosis.scannedAt)   // a new result landed
                        .symbolEffectsRemoved(reduceMotion)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(diagnosis.headline?.title ?? "No problems found")
                            .font(.system(size: 22, weight: .semibold))
                            .tracking(-0.3)
                            .fixedSize(horizontal: false, vertical: true)
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
                Spacer(minLength: Space.s)
                // The Sync Stalled and Upload Errors steps say to copy the diagnosis for Apple Support.
                Button(copied ? "Copied" : "Copy Diagnosis") {
                    store.copyDiagnosis()
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .help("Plain text to share with Apple Support.")
            }
            Divider()
            HStack(spacing: Space.l) {
                Metric(label: "Checked", value: diagnosis.checkedCount.formatted())
                Divider()
                Metric(label: "Need attention", value: attentionCount.formatted(), dot: diagnosis.verdict.color)
                Divider()
                let local = localOnly
                Metric(label: "Only on this Mac", value: local.value, unit: local.unit)
            }
            .fixedSize(horizontal: false, vertical: true)   // the vertical hairlines take the metrics' height
        }
        .padding(Space.l)
        .surface(18)
    }

    /// A small-caps header over one surface of finding rows, hairlines inset past the well.
    private func group(_ title: String, _ findings: [Finding], from index: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).smallCapsHeader().padding(.leading, Space.xxs)
            VStack(spacing: 0) {
                // Only the row's content turns; the surface never does (MOTION §3.4).
                ForEach(Array(findings.enumerated()), id: \.element.id) { i, finding in
                    Button { store.route = .finding(finding.rule) } label: { FindingRow(finding: finding) }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            if i > 0 { Divider().padding(.leading, 56) }
                        }
                        .flipIn(shown, index: index + i, reduceMotion: reduceMotion)
                }
            }
            .surface(16)
        }
    }

    /// Reference data: it doesn't move.
    private var facts: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("iCloud Drive").smallCapsHeader().padding(.leading, Space.xxs)
            VStack(spacing: 0) {
                fact("Sync check") {
                    let p = probe
                    HStack(spacing: Space.xs) {
                        Tag(text: p.word, tint: p.tint)
                        if let detail = p.detail { Text(detail).monospacedDigit().foregroundStyle(.secondary) }
                    }
                }
                Divider()
                // The scan's value until the fresh one arrives, instead of flashing "Unknown".
                fact("Free on this Mac") {
                    Text(ByteFormat.string(freeBytes ?? store.freeBytes)).monospacedDigit().foregroundStyle(.secondary)
                }
                Divider()
                fact("Scanned folders", note: "App folders such as Pages and Numbers aren't checked yet.") {
                    Text(scannedFolders).multilineTextAlignment(.trailing).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Space.m)
            .surface(16)
        }
    }

    /// A label (and an optional note under it) with its value trailing, as LabeledContent draws it in a Form.
    private func fact<Value: View>(_ label: String, note: String? = nil, @ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if let note { Text(note).font(.callout).foregroundStyle(.secondary) }
            }
            Spacer(minLength: Space.m)
            value()
        }
        .padding(.vertical, Space.s)
        .accessibilityElement(children: .combine)
    }

    private var attentionCount: Int { diagnosis.findings.filter { $0.severity >= .warning }.count }

    /// "4,213 items checked · 2 need attention · 3 items with no sync status · 1 folder couldn't be checked",
    /// zero parts left out.
    private var meta: String {
        let attention = attentionCount
        var parts = ["\(itemCount(diagnosis.checkedCount)) checked"]
        if attention > 0 { parts.append(attention == 1 ? "1 needs attention" : "\(attention) need attention") }
        if diagnosis.unknownCount > 0 { parts.append("\(itemCount(diagnosis.unknownCount)) with no sync status") }
        if let f = diagnosis.findings.first(where: { $0.rule == .unreadableFolders }) {
            let n = f.itemPaths.count
            parts.append(n == 1 ? "1 folder couldn't be checked" : "\(n.formatted()) folders couldn't be checked")
        }
        return parts.joined(separator: " · ")
    }

    /// Only on This Mac's size split for `Metric`: "2.1 GB" is ("2.1", "GB"), "At least 2.1 GB" keeps its words,
    /// "Unknown" stays whole. No such finding is "0 bytes".
    private var localOnly: (value: String, unit: String?) {
        let f = diagnosis.findings.first { $0.rule == .onlyOnThisMac }
        let size = f.map { ByteFormat.string($0.totalBytes, lowerBound: $0.bytesIsLowerBound) } ?? ByteFormat.string(0)
        guard let space = size.lastIndex(of: " ") else { return (size, nil) }
        return (String(size[..<space]), String(size[size.index(after: space)...]))
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

/// Hover depth instead of table-row hover (MOTION.md §3.4): the well lifts and the chevron slides.
private struct FindingRow: View {
    let finding: Finding
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lift = hovering && !reduceMotion
        HStack(spacing: Space.s) {
            FindingWell(finding: finding, size: 28)
                .scaleEffect(lift ? 1.08 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.body.weight(.semibold))
                // The first sentence, whole: a row never cuts an explanation mid-sentence (DESIGN.md §7). The
                // finding page has the rest; VoiceOver and the tooltip get all of it here too.
                Text(firstSentence(finding.explanation))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(finding.explanation)
            }
            .help(finding.explanation)
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
        .padding(.horizontal, Space.m)   // 16 + 28 well + 12 = the 56 pt hairline inset
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(Motion.follow) { hovering = h } }
    }

    /// Foundation's sentence boundaries, so "e.g." or "1.2 GB" don't end a sentence early.
    private func firstSentence(_ text: String) -> String {
        var first = text
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, stop in
            if let sentence { first = sentence.trimmingCharacters(in: .whitespacesAndNewlines) }
            stop = true
        }
        return first
    }
}

/// A finding's category symbol (`RuleID.symbol`) in a neutral well, tinted by its severity: no filled orange tiles
/// (DESIGN.md §5.1). VoiceOver hears the severity word. With Differentiate Without Color the severity's own symbol
/// replaces the category's, so shape carries the severity as well as colour. Summary rows and the finding page.
struct FindingWell: View {
    let finding: Finding
    var size: CGFloat = 28
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        Image(systemName: differentiate ? finding.severity.symbol : finding.rule.symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(finding.severity.color)
            .accessibilityLabel(finding.severity.word)
            .well(.secondary, size: size)
    }
}

extension Text {
    /// A small-caps section header (DESIGN.md §2.2 labels, §3.1): 13 pt semibold, secondary, a heading to VoiceOver.
    /// Styling, not ALL CAPS copy: the text keeps its case.
    func smallCapsHeader() -> some View {
        font(.body.weight(.semibold).smallCaps())   // VERIFY small caps with SF
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

import Foundation

/// Plain-text diagnosis for Copy Diagnosis. Made to be pasted in a forum or support chat, so it names
/// no user or Mac: the home folder becomes "~" and "Desktop - <Mac name>" folders are masked.
public enum DiagnosisText {
    static let maxPathsPerFinding = 50

    public static func render(_ diagnosis: Diagnosis, items: [String: ItemRecord], os: OSVersion,
                              home: String = NSHomeDirectory()) -> String {
        let attention = diagnosis.findings.filter { $0.severity >= .warning }.count
        var lines = [
            "iCloud Drive diagnosis",
            "Scanned \(ISO8601DateFormatter().string(from: diagnosis.scannedAt)) · macOS \(os)",
            "Verdict: \(diagnosis.verdict == .ok ? "No problems found" : diagnosis.verdict.word)",
            "\(counted(diagnosis.checkedCount, "item")) checked · \(counted(attention, "finding")) \(pick(attention, "needs", "need")) attention · \(counted(diagnosis.unknownCount, "item")) with no sync status from macOS",
        ]
        for finding in diagnosis.findings {
            lines += ["", "[\(finding.severity.word)] \(finding.title)", finding.explanation]
            if !finding.steps.isEmpty {
                lines.append("What to try:")
                lines += finding.steps.enumerated().map { "  \($0.offset + 1). \($0.element)" }
            }
            if let command = finding.command {
                lines.append("Terminal command:")
                lines += command.split(separator: "\n").map { "  " + mask(redact(String($0), home: home)) }
            }
            if !finding.itemPaths.isEmpty {
                lines.append("Affected (\(grouped(finding.itemPaths.count))):")
                lines += finding.itemPaths.prefix(maxPathsPerFinding).map { (path: String) -> String in
                    let shown = items[path].map { "\($0.root.displayName)/\($0.relativePath)" } ?? redact(path, home: home)
                    return "  " + mask(shown)
                }
                let more = finding.itemPaths.count - maxPathsPerFinding
                if more > 0 { lines.append("  …and \(grouped(more)) more") }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// "/Users/jane/x" → "~/x". A quoted path in a command becomes ~/'x' so it still works when pasted.
    static func redact(_ text: String, home: String) -> String {
        guard home.count > 1 else { return text }
        return text.replacingOccurrences(of: "'\(home)/", with: "~/'").replacingOccurrences(of: home + "/", with: "~/")
    }

    /// "Desktop - Jane's MacBook Air" → "Desktop - …": macOS names these folders after the Mac.
    static func mask(_ path: String) -> String {
        path.components(separatedBy: "/").map { (part: String) -> String in
            for prefix in ["Desktop - ", "Documents - "] where part.hasPrefix(prefix) { return prefix + "…" }
            return part
        }.joined(separator: "/")
    }
}

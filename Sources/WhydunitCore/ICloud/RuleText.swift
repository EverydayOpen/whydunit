import Foundation

extension RuleID {
    /// Sidebar label, title case.
    public var shortName: String {
        switch self {
        case .onlyOnThisMac: "Only on This Mac"
        case .syncStalled: "Sync Stalled"
        case .storageFull: "iCloud Storage Full"
        case .serverUnreachable: "Can't Reach iCloud"
        case .uploadRejected: "Upload Errors"
        case .stuckItems: "Stuck Uploads"
        case .lockFlags: "Lock Flags"
        case .tooLarge: "Too Large for iCloud"
        case .conflicts: "Conflicts"
        case .storageDebt: "Not Enough Space"
        case .developerFolders: "Developer Folders"
        case .relocatedFiles: "Moved Files"
        case .excludedByDesign: "Not Synced by Design"
        case .unreadableFolders: "Folders Not Checked"
        case .permissionDenied: "Needs Permission"
        }
    }
}

// Copy helpers. English only in v1; no locale lookups so reports and tests are deterministic.

/// Singular or plural wording.
func pick(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? one : many }

/// "1 file", "12 files", "4,213 items".
func counted(_ n: Int, _ noun: String) -> String { "\(grouped(n)) \(noun)\(n == 1 ? "" : "s")" }

/// 4213 → "4,213".
func grouped(_ n: Int) -> String {
    let digits = Array(String(n.magnitude))
    var out = ""
    for (i, digit) in digits.enumerated() {
        if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
        out.append(digit)
    }
    return n < 0 ? "-" + out : out
}

/// " (1.2 GB)", " (at least 1.2 GB)", or "" when nothing is known.
func sizeNote(_ size: (total: Int64?, lower: Bool)) -> String {
    guard let total = size.total else { return "" }
    return " (\(size.lower ? "at least " : "")\(ByteFormat.string(total)))"
}

/// "90 seconds", "2 minutes", "2 hours", "3 days".
func duration(_ seconds: TimeInterval) -> String {
    if seconds < 90 { return counted(Int(seconds.rounded()), "second") }
    let minutes = Int((seconds / 60).rounded())
    if minutes < 120 { return counted(minutes, "minute") }
    let hours = Int((seconds / 3600).rounded())
    if hours < 48 { return counted(hours, "hour") }
    return counted(Int((seconds / 86_400).rounded()), "day")
}

/// "Desktop", "Desktop and Documents", "iCloud Drive, Desktop and Documents".
func listed(_ names: [String]) -> String {
    guard let last = names.last, names.count > 1 else { return names.first ?? "" }
    return names.dropLast().joined(separator: ", ") + " and " + last
}

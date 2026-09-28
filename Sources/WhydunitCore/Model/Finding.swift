import Foundation

/// Stable identity of a diagnosis rule. The raw value is used in routes, logs and reports.
/// Rule numbers (I1…I16) refer to docs/DECISIONS.md §2.2.
public enum RuleID: String, Codable, CaseIterable, Sendable {
    case onlyOnThisMac = "icloud.only-on-this-mac"        // I16
    case syncStalled = "icloud.sync-stalled"              // I11
    case storageFull = "icloud.storage-full"              // I1
    case serverUnreachable = "icloud.server-unreachable"  // I2
    case uploadRejected = "icloud.upload-rejected"        // I4
    case stuckItems = "icloud.stuck-items"                // I10
    case lockFlags = "icloud.lock-flags"                  // I5
    case tooLarge = "icloud.too-large"                    // I6
    case conflicts = "icloud.conflicts"                   // I8
    case storageDebt = "icloud.storage-debt"              // I13
    case developerFolders = "icloud.developer-folders"    // I14
    case relocatedFiles = "icloud.relocated-files"        // I15
    case excludedByDesign = "icloud.excluded-by-design"   // I7
    case unreadableFolders = "icloud.unreadable-folders"  // folders we could not list
    case permissionDenied = "icloud.permission-denied"    // a whole root was not readable
}

/// What the app can do about a finding. Each maps to one compiled-in code path in WhydunitMac;
/// nothing outside this list is ever executed.
public enum FixAction: String, Codable, CaseIterable, Sendable {
    /// L0: copy local-only items to a folder outside iCloud and verify each copy by SHA-256.
    case backUp
    /// L6b: move the item out of iCloud Drive and back in, one at a time. Requires a verified backup.
    case retryUpload
    /// L3: restart the user's own `bird` sync process (launchd starts it again).
    case restartSync
    /// Open System Settings › Apple Account › iCloud.
    case openICloudSettings
    /// Open System Settings › Privacy & Security › Files & Folders.
    case openPrivacySettings
    /// Reveal the affected items or folders in Finder.
    case showInFinder
    /// Copy a Terminal command (`Finding.command`) that the user runs themselves.
    case copyCommand
}

/// One plain-English conclusion with its evidence and next step.
public struct Finding: Identifiable, Codable, Hashable, Sendable {
    public var id: RuleID { rule }

    public var rule: RuleID
    public var severity: Severity
    /// The fact itself, sentence case, no trailing period: "12 files haven't uploaded to iCloud".
    public var title: String
    /// What we measured and why it matters. At most 3 sentences.
    public var explanation: String
    /// What to try, in order. At most 4 steps.
    public var steps: [String]
    /// Absolute paths of affected items (may be empty for Mac-wide findings).
    public var itemPaths: [String]
    /// Sum of logical sizes of affected items, when known.
    public var totalBytes: Int64?
    /// `totalBytes` is a lower bound because some sizes were unknown.
    public var bytesIsLowerBound: Bool
    /// The main action offered, if any.
    public var primaryAction: FixAction?
    /// Terminal command for `.copyCommand`. Never executed by the app.
    public var command: String?

    public init(
        rule: RuleID, severity: Severity, title: String, explanation: String,
        steps: [String] = [], itemPaths: [String] = [],
        totalBytes: Int64? = nil, bytesIsLowerBound: Bool = false,
        primaryAction: FixAction? = nil, command: String? = nil
    ) {
        self.rule = rule
        self.severity = severity
        self.title = title
        self.explanation = explanation
        self.steps = steps
        self.itemPaths = itemPaths
        self.totalBytes = totalBytes
        self.bytesIsLowerBound = bytesIsLowerBound
        self.primaryAction = primaryAction
        self.command = command
    }
}

/// Result of classifying one scan.
public struct Diagnosis: Codable, Hashable, Sendable {
    /// Sorted worst first; ties broken by `RuleID` declaration order.
    public var findings: [Finding]
    /// Number of items examined.
    public var checkedCount: Int
    /// Number of items whose sync state macOS didn't report.
    public var unknownCount: Int
    public var scannedAt: Date

    public init(findings: [Finding], checkedCount: Int, unknownCount: Int, scannedAt: Date) {
        self.findings = findings
        self.checkedCount = checkedCount
        self.unknownCount = unknownCount
        self.scannedAt = scannedAt
    }

    /// Worst severity that affects the verdict (`.info`/`.unknown` never do).
    public var verdict: Severity {
        findings.map(\.severity).filter { $0 >= .warning }.max() ?? .ok
    }

    /// The finding shown as the hero title, or nil when all clear.
    public var headline: Finding? { findings.first { $0.severity >= .warning } }
}

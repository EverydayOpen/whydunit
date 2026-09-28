import Foundation

/// Written as `manifest.json` inside every backup folder. A backup counts as safe only if every
/// entry is `verified` (the copy's SHA-256 matched the source's).
public struct BackupManifest: Codable, Hashable, Identifiable, Sendable {
    public var id: String { folder }

    public var version: Int
    public var created: Date
    /// Absolute path of the backup folder.
    public var folder: String
    public var entries: [Entry]

    public struct Entry: Codable, Hashable, Sendable {
        /// Absolute path of the original item when it was copied.
        public var source: String
        /// Absolute path of the copy.
        public var copy: String
        public var bytes: Int64
        /// Lowercase hex SHA-256. For packages/folders: hash of the sorted "relpath\0sha\n" lines.
        public var sha256: String
        public var verified: Bool

        public init(source: String, copy: String, bytes: Int64, sha256: String, verified: Bool) {
            self.source = source
            self.copy = copy
            self.bytes = bytes
            self.sha256 = sha256
            self.verified = verified
        }
    }

    public init(version: Int = 1, created: Date, folder: String, entries: [Entry]) {
        self.version = version
        self.created = created
        self.folder = folder
        self.entries = entries
    }

    public var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    public var isFullyVerified: Bool { !entries.isEmpty && entries.allSatisfy(\.verified) }

    /// The verified copy of `source`, if this backup holds one.
    public func verifiedEntry(for source: String) -> Entry? {
        entries.first { $0.source == source && $0.verified }
    }
}

/// One line of the activity log (`activity.jsonl`). Every change the app makes is recorded here.
public struct AuditEntry: Codable, Hashable, Identifiable, Sendable {
    public enum Outcome: String, Codable, Sendable { case succeeded, failed, skipped }

    public var id: UUID
    public var date: Date
    public var action: FixAction
    /// Item path, backup folder or process name the action touched.
    public var target: String
    public var outcome: Outcome
    /// Plain-English detail, e.g. "Uploaded after 42 s" or the error message.
    public var detail: String

    public init(id: UUID = UUID(), date: Date, action: FixAction, target: String, outcome: Outcome, detail: String) {
        self.id = id
        self.date = date
        self.action = action
        self.target = target
        self.outcome = outcome
        self.detail = detail
    }
}

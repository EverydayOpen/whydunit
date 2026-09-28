import Foundation
import WhydunitCore

/// Append-only JSON Lines log of every change the app makes.
public actor ActivityLog {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Whydunit/activity.jsonl")
    }

    public func append(_ entry: AuditEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var line = try? encoder.encode(entry) else { return }
        line.append(0x0A)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }

    /// Newest first. Lines that don't decode (a torn write, a future format) are skipped.
    public func all() -> [AuditEntry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n")
            .compactMap { try? decoder.decode(AuditEntry.self, from: Data($0.utf8)) }
            .reversed()
    }
}

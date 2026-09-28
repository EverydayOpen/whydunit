import CryptoKit
import Foundation
import WhydunitCore

public struct BackupProgress: Sendable {
    public var completed: Int
    public var total: Int
    public var currentName: String

    public init(completed: Int, total: Int, currentName: String) {
        self.completed = completed
        self.total = total
        self.currentName = currentName
    }
}

public enum BackupError: Error, LocalizedError {
    case destinationInsideICloud
    case notEnoughSpace(needed: Int64, available: Int64?)
    case itemNotLocal(String)
    case hashMismatch(String)
    case nothingToBackUp

    public var errorDescription: String? {
        switch self {
        case .destinationInsideICloud:
            "The backup folder is inside iCloud. Choose a folder that iCloud doesn't sync."
        case let .notEnoughSpace(needed, available):
            "Not enough free space. The backup needs \(ByteFormat.string(needed, lowerBound: false)) free and \(ByteFormat.string(available, lowerBound: false)) is available."
        case let .itemNotLocal(path):
            "“\((path as NSString).lastPathComponent)” isn't fully on this Mac, so it can't be backed up."
        case let .hashMismatch(path):
            "The copy of “\((path as NSString).lastPathComponent)” doesn't match the original, so the backup stopped. Copies already checked were kept."
        case .nothingToBackUp:
            "There's nothing to back up."
        }
    }
}

public struct BackupService: Sendable {
    let backupsRoot: URL
    let locations: ICloudLocations

    public init(backupsRoot: URL, locations: ICloudLocations) {
        self.backupsRoot = backupsRoot
        self.locations = locations
    }

    public static var defaultRoot: URL {
        SystemInfo.homeDirectory.appendingPathComponent("Whydunit Backups", isDirectory: true)
    }

    public func backUp(_ items: [ItemRecord], now: Date, progress: @escaping @Sendable (BackupProgress) -> Void) async throws -> BackupManifest {
        guard !items.isEmpty else { throw BackupError.nothingToBackUp }
        guard !Self.isInsideICloud(backupsRoot, locations: locations) else { throw BackupError.destinationInsideICloud }

        // A parent path sorts before its children, so a selected folder is copied before selected items inside it.
        let ordered = items.sorted { $0.path < $1.path }
        var sizes: [Int64] = []
        for item in ordered {
            guard !item.isDataless, let size = Self.localSize(item.path, isTree: item.isDirectory || item.isPackage) else {
                throw BackupError.itemNotLocal(item.path)
            }
            sizes.append(size)
        }
        let fm = FileManager.default
        try fm.createDirectory(at: backupsRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let needed = 2 * sizes.reduce(0, +)
        if let free = SystemInfo.freeBytes(at: backupsRoot), free < needed {
            throw BackupError.notEnoughSpace(needed: needed, available: free)
        }

        // Claim a folder of its own: two backups started in the same second must not share one (or its manifest).
        var folder = backupsRoot.appendingPathComponent(Self.folderName(now), isDirectory: true)
        for suffix in 2...100 {
            do {
                // Owner-only, like the folders the originals come from: this blocks every other user from the copies
                // and the manifest's path list (the copies keep their own 0644).
                try fm.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                break
            } catch CocoaError.fileWriteFileExists where suffix < 100 {
                folder = backupsRoot.appendingPathComponent("\(Self.folderName(now)) \(suffix)", isDirectory: true)
            }
        }
        var entries: [BackupManifest.Entry] = []
        var failure: Error?
        // Written now and every few seconds, so a quit or crash mid-backup leaves a folder the app lists
        // (and can trash), with the copies verified so far usable.
        try Self.write(BackupManifest(created: now, folder: folder.path, entries: []))
        var lastWrite = Date()
        for (index, item) in ordered.enumerated() {
            progress(BackupProgress(completed: index, total: ordered.count, currentName: item.name))
            do {
                try Task.checkCancellation()
                let isTree = item.isDirectory || item.isPackage
                let source = URL(fileURLWithPath: item.path, isDirectory: isTree)
                let copy = folder.appendingPathComponent(item.root.displayName, isDirectory: true)
                    .appendingPathComponent(item.relativePath, isDirectory: isTree)
                try fm.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
                let sourceHash = try Self.coordinatedCopy(source, to: copy, isTree: isTree)
                let copyHash = try Self.sha256(of: copy, isTree: isTree)
                entries.append(.init(source: item.path, copy: copy.path, bytes: sizes[index],
                                     sha256: sourceHash, verified: sourceHash == copyHash))
                if sourceHash != copyHash {
                    failure = BackupError.hashMismatch(item.path)
                    break
                }
                if Date().timeIntervalSince(lastWrite) > 5 {
                    try Self.write(BackupManifest(created: now, folder: folder.path, entries: entries))
                    lastWrite = Date()
                }
            } catch {
                failure = error
                break
            }
        }
        // Written even on failure, so the copies that did verify are recorded and usable.
        let manifest = BackupManifest(created: now, folder: folder.path, entries: entries)
        try Self.write(manifest)
        if let failure { throw failure }
        progress(BackupProgress(completed: ordered.count, total: ordered.count, currentName: ""))
        return manifest
    }

    public func listBackups() -> [BackupManifest] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backupsRoot.path)) ?? []
        return names.compactMap { name -> BackupManifest? in
            let folder = backupsRoot.appendingPathComponent(name, isDirectory: true)
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
                  var manifest = try? decoder.decode(BackupManifest.self, from: data) else { return nil }
            // Trust where the manifest is, not the paths written inside it: trashBackup acts on this folder,
            // and Retry Upload checks the copies, which moved with it if the user moved the backups folder.
            let old = manifest.folder
            manifest.folder = folder.path
            manifest.entries = manifest.entries.map {
                var e = $0
                if e.copy.hasPrefix(old + "/") { e.copy = folder.path + String(e.copy.dropFirst(old.count)) }
                return e
            }
            return manifest
        }
        .sorted { $0.created > $1.created }
    }

    public func trashBackup(_ manifest: BackupManifest) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: manifest.folder, isDirectory: true), resultingItemURL: nil)
    }

    // MARK: - Helpers (internal for tests)

    static func folderName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }

    /// True if `url` (which needn't exist yet) is in iCloud: backups there don't count, since iCloud can evict them
    /// or delete them along with the originals. Backing up (the folder) and Retry Upload (each copy) both check it.
    public static func isInsideICloud(_ url: URL, locations: ICloudLocations) -> Bool {
        // Resolve the part that exists, then add back the rest: resolvingSymlinksInPath may leave a path that
        // doesn't exist yet unresolved, and a symlinked parent must not hide an iCloud folder.
        let requested = url.standardizedFileURL
        var ancestor = requested
        while !FileManager.default.fileExists(atPath: ancestor.path) { ancestor.deleteLastPathComponent() }
        let resolved = ancestor.resolvingSymlinksInPath()
        let destination = requested.pathComponents.dropFirst(ancestor.pathComponents.count)
            .reduce(resolved) { $0.appendingPathComponent($1) }
        let mobileDocuments = SystemInfo.homeDirectory.appendingPathComponent("Library/Mobile Documents").resolvingSymlinksInPath()
        // Also ask the file system: `locations` may be stale, and its Desktop & Documents detection is unverified.
        return locations.contains(destination) || isInside(destination, mobileDocuments)
            || (try? resolved.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
    }

    /// Case-insensitive because APFS usually is.
    static func isInside(_ url: URL, _ folder: URL) -> Bool {
        let path = url.path.lowercased(), parent = folder.path.lowercased()
        return path == parent || path.hasPrefix(parent + "/")
    }

    /// Bytes of a file or folder tree (folder entries included, which only makes the 2x preflight stricter),
    /// or nil when it or anything inside it is missing or dataless.
    static func localSize(_ path: String, isTree: Bool) -> Int64? {
        var st = stat()
        guard lstat(path, &st) == 0, st.st_flags & BSDFlags.sfDataless == 0 else { return nil }
        var total = Int64(st.st_size)
        guard isTree, let enumerator = FileManager.default.enumerator(atPath: path) else { return total }
        while let relative = enumerator.nextObject() as? String {
            // A dataless folder can't be listed (EDEADLK); the enumerator skips its contents but still yields
            // the folder itself, whose SF_DATALESS flag is caught here. VERIFY on a real evicted package.
            guard lstat(path + "/" + relative, &st) == 0, st.st_flags & BSDFlags.sfDataless == 0 else { return nil }
            total += Int64(st.st_size)
        }
        return total
    }

    /// Copies (unless an earlier item of this backup already copied it inside a folder) and hashes the source
    /// within one coordinated read, so the hash describes exactly what was copied. Returns the source hash.
    static func coordinatedCopy(_ source: URL, to copy: URL, isTree: Bool) throws -> String {
        var coordinatorError: NSError?
        var result: Result<String, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinatorError) { url in
            result = Result {
                if !FileManager.default.fileExists(atPath: copy.path) {
                    try FileManager.default.copyItem(at: url, to: copy)
                }
                return try Self.sha256(of: url, isTree: isTree)
            }
        }
        if let coordinatorError { throw coordinatorError }
        return try result.get()
    }

    /// Lowercase hex SHA-256 of a file; for a folder or package, of its sorted "relativePath\0sha256\n" lines
    /// (regular files only).
    static func sha256(of url: URL, isTree: Bool) throws -> String {
        guard isTree else { return try fileSHA256(url) }
        guard let enumerator = FileManager.default.enumerator(atPath: url.path) else { throw CocoaError(.fileReadUnknown) }
        var lines: [String] = []
        while let relative = enumerator.nextObject() as? String {
            let file = url.appendingPathComponent(relative)
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let hash = try fileSHA256(file)
            lines.append(relative + "\0" + hash + "\n")
        }
        return hex(SHA256.hash(data: Data(lines.sorted().joined().utf8)))
    }

    static func fileSHA256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hex(hasher.finalize())
    }

    static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    static func write(_ manifest: BackupManifest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = URL(fileURLWithPath: manifest.folder, isDirectory: true).appendingPathComponent("manifest.json")
        try encoder.encode(manifest).write(to: url, options: .atomic)
    }
}

import Foundation
import os
import WhydunitCore

public enum RetryOutcome: Sendable, Equatable {
    case uploaded(seconds: Double)
    case stillWaiting
    case skipped(reason: String)
    case failed(reason: String)
}

public struct UploadRetrier: Sendable {
    /// Written into an item's staging folder before the move out, holding the item's original path.
    static let originFile = ".whydunit-original-path"

    let scanner: ICloudScanner
    let stagingRoot: URL
    /// `out` while an item is out of iCloud Drive; once `quitting` (set by Quit), no item moves out.
    let gate: OSAllocatedUnfairLock<(quitting: Bool, out: Bool)>

    public init(scanner: ICloudScanner, stagingRoot: URL,
                gate: OSAllocatedUnfairLock<(quitting: Bool, out: Bool)> = OSAllocatedUnfairLock(initialState: (quitting: false, out: false))) {
        self.scanner = scanner
        self.stagingRoot = stagingRoot
        self.gate = gate
    }

    public func retry(_ item: ItemRecord, rootURL: URL, backup: BackupManifest.Entry, waitAfterReturn: TimeInterval = 120) async -> RetryOutcome {
        guard !item.isDirectory || item.isPackage else { return .skipped(reason: "Folders aren't moved. Retry the files inside it.") }
        guard backup.verified, backup.source == item.path else { return .skipped(reason: "No checked backup of this item") }
        // The backups folder is the user's to edit: the copy must still be outside iCloud (it may have been moved in,
        // or Desktop & Documents turned on since), there, on this Mac, and unchanged.
        guard !BackupService.isInsideICloud(URL(fileURLWithPath: backup.copy), locations: .current()) else {
            return .skipped(reason: "The backup copy is inside iCloud now. Back up to a folder outside iCloud first.")
        }
        // A missing or dataless copy fails the hash (materialization is off).
        guard backup.copy != item.path,
              (try? BackupService.sha256(of: URL(fileURLWithPath: backup.copy), isTree: item.isDirectory || item.isPackage)) == backup.sha256 else {
            return .skipped(reason: "The backup copy changed or is missing. Back up again first.")
        }
        let url = URL(fileURLWithPath: item.path)
        // The iCloud keys are read here, not in the coordinated write: FileProvider serves them, and waiting on it
        // while this process holds a coordinated write on the item could deadlock.
        guard let current = scanner.record(at: url, root: item.root, rootURL: rootURL) else { return .skipped(reason: "It's no longer there") }
        guard current.modified == item.modified, current.logicalSize == item.logicalSize else {
            return .skipped(reason: "Changed since you reviewed it")
        }
        if current.isDataless { return .skipped(reason: "Only in iCloud") }
        // nil may mean it's already in iCloud and edited elsewhere; moving it out would delete it everywhere.
        guard current.isUploaded == false else {
            return .skipped(reason: current.isUploaded == true ? "Already uploaded" : "macOS didn't report its sync state")
        }
        if current.isUploading == true { return .skipped(reason: "Uploading now") }
        // Moving it out makes iCloud delete it, and with it another device's version, which the backup doesn't hold.
        if current.hasUnresolvedConflicts == true { return .skipped(reason: "It has a conflict with another device's version. Resolve that first.") }
        // VERIFY on a Mac: an ordinary stuck local edit reports .current, not .downloaded; if not, this blocks every retry.
        if current.downloadingStatus == .downloaded { return .skipped(reason: "iCloud has a newer version from another device") }
        // Moving a shared item, or an item in a shared folder, out of iCloud Drive stops sharing it for everyone.
        var level = url
        while true {
            if (try? level.resourceValues(forKeys: [.ubiquitousItemIsSharedKey]))?.ubiquitousItemIsShared == true {
                return .skipped(reason: "It's shared. Moving it out of iCloud Drive would stop sharing it.")
            }
            guard level.path.hasPrefix(rootURL.path + "/") else { break }
            level.deleteLastPathComponent()
        }
        let fm = FileManager.default
        // ponytail: each retry leaves its folder (holding only the origin file) in the hidden staging folder,
        // since trashItem would fill the user's Trash; prune them if they ever add up.
        let staging = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let staged = staging.appendingPathComponent(url.lastPathComponent)
        var destination = url
        do {
            defer { gate.withLock { $0.out = false } }   // item back (or failed): Quit needn't wait any longer
            // Plain file-system checks inside the coordinated write, so no one can save between them and the move.
            // What's left is a race: if it finishes uploading first, it leaves iCloud for ~10 s, with a verified backup.
            let skip = try Self.coordinatedMove(url, to: staged) {
                var st = stat()
                guard lstat(url.path, &st) == 0 else { return "It's no longer there" }
                if st.st_flags & BSDFlags.sfDataless != 0 { return "Only in iCloud" }
                // Catches any edit since the backup, including one after the checks above, and (materialization
                // off) evicted files inside a package.
                guard (try? BackupService.sha256(of: url, isTree: item.isDirectory || item.isPackage)) == backup.sha256 else {
                    return "Changed since it was backed up. Back up again first."
                }
                // Owner-only (the new .staging too): the item comes from folders other users can't open.
                try fm.createDirectory(at: staging, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                // Same volume makes both moves renames: nothing is copied, nothing can be half-written.
                guard Self.sameVolume(url, staging) else { return "The staging folder is on a different disk" }
                // Before the move, so an item stranded by a quit or crash is put back by recoverStaged.
                try Data(url.path.utf8).write(to: staging.appendingPathComponent(Self.originFile))
                // Atomic with the decision to move: once Quit has read `out`, nothing more moves out.
                return gate.withLock { state -> String? in
                    if state.quitting { return "Whydunit is quitting" }
                    state.out = true
                    return nil
                }
            }
            if let skip { return .skipped(reason: skip) }
            // ponytail: fixed 10 s for iCloud to notice the item left; make it adaptive if field reports need it.
            try? await Task.sleep(for: .seconds(10))
            if fm.fileExists(atPath: url.path) { destination = Self.restoredURL(for: url) }
            do {
                do { _ = try Self.coordinatedMove(staged, to: destination) }
                // Timed out (or failed) with the item still out: put it back uncoordinated rather than leave it out.
                catch where fm.fileExists(atPath: staged.path) { try fm.moveItem(at: staged, to: destination) }
            } catch {
                return .failed(reason: "Couldn't put it back (\(error.localizedDescription)). It is safe in \(staged.path)")
            }
        } catch {
            return .failed(reason: error.localizedDescription)
        }
        if destination != url {
            return .failed(reason: "Something new took its place while it was out, so it was put back as “\(destination.lastPathComponent)”")
        }

        let start = Date()
        while Date().timeIntervalSince(start) < waitAfterReturn {
            do { try await Task.sleep(for: .seconds(5)) } catch { break }
            if scanner.record(at: url, root: item.root, rootURL: rootURL)?.isUploaded == true {
                return .uploaded(seconds: Date().timeIntervalSince(start))
            }
        }
        return .stillWaiting
    }

    /// Puts back every item a quit, crash or failed move back left in staging: at its original path, or as
    /// "… (Whydunit restored)" beside it if that path is taken. Call at launch, before any retry.
    /// Returns where each item now is (its staging path if it couldn't be moved).
    public static func recoverStaged(in stagingRoot: URL) -> [String] {
        let fm = FileManager.default
        var paths: [String] = []
        for folder in (try? fm.contentsOfDirectory(at: stagingRoot, includingPropertiesForKeys: nil)) ?? [] {
            // Found by listing, not from the journal: after a power loss the rename can be on disk while the
            // journal (not fsynced) is empty or zero-filled.
            let names = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0 != originFile && $0 != ".DS_Store" }
            guard let name = names.first else { continue }   // already put back
            let staged = folder.appendingPathComponent(name)
            let journal = (try? Data(contentsOf: folder.appendingPathComponent(originFile))).map { String(decoding: $0, as: UTF8.self) } ?? ""
            guard journal.hasPrefix("/"), (journal as NSString).lastPathComponent == name else {
                paths.append(staged.path)   // where it came from is unknown: the launch alert reveals it
                continue
            }
            let journalURL = URL(fileURLWithPath: journal)
            func putBack() throws -> URL {
                let original = fm.fileExists(atPath: journalURL.path) ? restoredURL(for: journalURL) : journalURL
                do { _ = try coordinatedMove(staged, to: original) }
                catch where fm.fileExists(atPath: staged.path) { try fm.moveItem(at: staged, to: original) }
                return original
            }
            do {
                paths.append(try putBack().path)
            } catch {
                // Its folder may have been evicted since, and a dataless folder can't be looked up with materialization
                // off. Only as a second try: materializing it can block on a wedged fileproviderd.
                paths.append(((try? Materialization.allowingOnThisThread(putBack)) ?? staged).path)
            }
        }
        return paths
    }

    /// Moves with NSFileCoordinator, so apps that have the item open are told where it went. `ready` runs inside
    /// the coordinated write right before the move; it returns a reason not to move, or throws.
    /// Throws NSUserCancelledError, having moved nothing, if the coordination isn't granted within 30 s.
    static func coordinatedMove(_ source: URL, to destination: URL, ready: () throws -> String? = { nil }) throws -> String? {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        // A file presenter or FileProvider that never answers would otherwise block here for good. Once the block
        // runs, cancel() has no effect. ponytail: fixed 30 s; make it a parameter if field reports need it.
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) { coordinator.cancel() }
        var coordinatorError: NSError?
        var result: Result<String?, Error> = .failure(CocoaError(.fileWriteUnknown))
        coordinator.coordinate(writingItemAt: source, options: .forMoving, writingItemAt: destination, options: .forReplacing,
                               error: &coordinatorError) { from, to in
            result = Result {
                if let reason = try ready() { return reason }
                coordinator.item(at: from, willMoveTo: to)
                try FileManager.default.moveItem(at: from, to: to)
                coordinator.item(at: from, didMoveTo: to)
                return nil
            }
        }
        if let coordinatorError { throw coordinatorError }
        return try result.get()
    }

    static func sameVolume(_ a: URL, _ b: URL) -> Bool {
        guard let x = try? a.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier,
              let y = try? b.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier else { return false }
        return x.isEqual(y)
    }

    /// "Budget.numbers" → "Budget (Whydunit restored).numbers", or "Budget (Whydunit restored 2).numbers" … if taken.
    static func restoredURL(for url: URL) -> URL {
        let ext = url.pathExtension, base = url.deletingPathExtension().lastPathComponent
        for n in 1... {
            let name = base + " (Whydunit restored\(n == 1 ? "" : " \(n)"))" + (ext.isEmpty ? "" : "." + ext)
            let candidate = url.deletingLastPathComponent().appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        fatalError("unreachable")
    }
}

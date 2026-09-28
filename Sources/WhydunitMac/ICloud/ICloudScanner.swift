import Foundation
import os
import WhydunitCore

public struct ScanProgress: Sendable {
    public var phase: String
    public var itemsSeen: Int
    public var fraction: Double?
}

public struct ScanOutput: Sendable {
    public var items: [ItemRecord]
    public var deniedRoots: [ScanRoot]
}

/// Read-only inventory of the iCloud roots: names and metadata only, never file contents.
/// Relies on `Materialization.disableForProcess()` so no metadata read can download anything.
public final class ICloudScanner: Sendable {
    static let developerFolderNames: Set<String> = ["node_modules", ".git", ".build", "Pods", "DerivedData"]
    static let descendantCap = 10_000

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .fileSizeKey, .totalFileSizeKey,
        .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey, .addedToDirectoryDateKey,
        .isUbiquitousItemKey, .ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey,
        .ubiquitousItemDownloadingStatusKey, .ubiquitousItemUploadingErrorKey, .ubiquitousItemDownloadingErrorKey,
        .ubiquitousItemHasUnresolvedConflictsKey,
        // VERIFY: iCloud Drive doesn't support this key; reading is reported to return nil (never set it: it hangs).
        .ubiquitousItemIsExcludedFromSyncKey,
    ]

    public init() {}

    /// Enumerates each root (skipsPackageDescendants, NOT skipsHiddenFiles). Folders that can't be listed
    /// (EDEADLK = dataless, EPERM/EACCES = permission) get `listingFailed`; roots that can't be listed at all
    /// go to `deniedRoots`. Progress at most ~10×/s.
    public func scan(roots: [ScanRoot: URL], progress: @escaping @Sendable (ScanProgress) -> Void) async throws -> ScanOutput {
        // The enumeration blocks, for good on a wedged fileproviderd or an unanswered privacy prompt, so it runs on a
        // GCD thread, not the cooperative pool. Cancelling the caller stops it at the next item; this returns only then.
        let cancelled = OSAllocatedUnfairLock(initialState: false)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (done: CheckedContinuation<ScanOutput, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    done.resume(with: Result { try self.scanBlocking(roots: roots, isCancelled: { cancelled.withLock { $0 } },
                                                                     progress: progress) })
                }
            }
        } onCancel: {
            cancelled.withLock { $0 = true }
        }
    }

    /// Re-reads one item (used right before acting and while waiting for upload).
    public func record(at url: URL, root: ScanRoot, rootURL: URL) -> ItemRecord? {
        let path = url.path, base = rootURL.path
        let relative = path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : url.lastPathComponent
        return makeRecord(url, root: root, relativePath: relative)
    }

    private func scanBlocking(roots: [ScanRoot: URL], isCancelled: () -> Bool,
                              progress: @Sendable (ScanProgress) -> Void) throws -> ScanOutput {
        let fm = FileManager.default
        var items: [ItemRecord] = []
        var denied: [ScanRoot] = []
        var lastReport = 0.0

        for root in ScanRoot.allCases {
            guard let rootURL = roots[root] else { continue }
            if isCancelled() { throw CancellationError() }
            let phase = "Looking at \(root.displayName)…"
            progress(ScanProgress(phase: phase, itemsSeen: items.count, fraction: nil))

            var failed = Set<String>()
            // A root we can't list (usually Files & Folders permission) must be reported, never look empty.
            guard (try? fm.contentsOfDirectory(atPath: rootURL.path)) != nil,
                  let e = fm.enumerator(at: rootURL, includingPropertiesForKeys: [], options: [.skipsPackageDescendants],
                                        errorHandler: { url, _ in
                                            // VERIFY: called with the folder's URL after the folder itself was yielded.
                                            failed.insert(url.path)
                                            return true
                                        })
            else {
                // A dataless root (EDEADLK, e.g. a fresh Mac's ~/Documents) holds nothing local; not a permission problem.
                var st = stat()
                if lstat(rootURL.path, &st) == 0, st.st_flags & BSDFlags.sfDataless != 0 { continue }
                denied.append(root)
                continue
            }

            let first = items.count
            // Latest date added along the path, by depth (the enumeration is depth-first). The root seed is best effort:
            // since Sonoma ~/Desktop may stay put when Desktop & Documents is turned on, so its date may not change.
            let rootAdded = try? rootURL.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate
            var since: [Date?] = []
            for case let url as URL in e {
                if isCancelled() { throw CancellationError() }
                if root == .iCloudDrive, e.level == 1, [UploadProbe.folderName, ".Trash"].contains(url.lastPathComponent) {
                    e.skipDescendants()
                    continue
                }
                // Built from the enumerator's depth so a "/private" prefix on returned URLs can't break it.
                let relative = url.pathComponents.suffix(e.level).joined(separator: "/")
                let record = makeRecord(url, root: root, relativePath: relative)
                // iCloud never syncs inside it (node_modules.nosync can hold 10^5 files): its walked size is all I7 uses.
                if record?.isDirectory == true, ICloudClassifier.isExcludedName(url.lastPathComponent) { e.skipDescendants() }
                // Updated before the guard so a skipped item still holds its depth slot for its descendants.
                since = Array(since.prefix(e.level - 1))
                let arrived = [record?.inPlaceSince, since.last ?? rootAdded].compactMap { $0 }.max()
                since.append(arrived)
                guard var item = record else { continue }
                item.inPlaceSince = arrived
                items.append(item)
                let now = Date.timeIntervalSinceReferenceDate
                if now - lastReport >= 0.1 {
                    lastReport = now
                    progress(ScanProgress(phase: phase, itemsSeen: items.count, fraction: nil))
                }
            }
            for i in first..<items.count where items[i].isDirectory && failed.contains(items[i].path) {
                items[i].listingFailed = true
            }
            // Developer folders are counted from what was just listed, not walked again. The enumeration is
            // depth-first, so a folder's descendants follow it directly (minus package contents and unreadable
            // items, which is fine for a >5,000 threshold).
            for i in first..<items.count where items[i].descendantCount != nil {
                let prefix = items[i].path + "/"
                let count = items[(i + 1)...].prefix(while: { $0.path.hasPrefix(prefix) }).count
                items[i].descendantCount = count
            }
        }
        return ScanOutput(items: items, deniedRoots: denied)
    }

    private func makeRecord(_ url: URL, root: ScanRoot, relativePath: String) -> ItemRecord? {
        var url = url
        url.removeAllCachedResourceValues()
        // One failing key fails the whole read, and the ubiquity keys come from FileProvider, which is what's
        // wedged on the Macs we diagnose: keep the item with its iCloud state unknown rather than drop it.
        guard let v = (try? url.resourceValues(forKeys: Self.keys))
                ?? (try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .fileSizeKey,
                                                      .totalFileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey,
                                                      .contentModificationDateKey, .addedToDirectoryDateKey]))
        else { return nil }
        // Resource values don't follow a final symlink, so a link would pass as a file. Since Sonoma this also
        // skips CloudDocs/Desktop and CloudDocs/Documents, which link to ~/Desktop and ~/Documents.
        if v.isSymbolicLink == true { return nil }
        var st = stat()
        let flags: UInt32? = lstat(url.path, &st) == 0 ? st.st_flags : nil
        let isDirectory = v.isDirectory ?? false
        let isPackage = v.isPackage ?? false

        var logical = (v.totalFileSize ?? v.fileSize).map { Int64($0) }
        var allocated = (v.totalFileAllocatedSize ?? v.fileAllocatedSize).map { Int64($0) }
        if isDirectory && (isPackage || ICloudClassifier.isExcludedName(url.lastPathComponent)) && logical == nil {
            // VERIFY: the size keys are nil for bundles, so add up their files (metadata only, capped). The scan doesn't
            // list inside a package or an excluded folder, so this is the only size either gets.
            let sizes = walk(url)
            logical = sizes.logical
            allocated = sizes.allocated
        }
        // Only the outermost one: node_modules nest hundreds deep and the outer count already covers them.
        let isDeveloperFolder = isDirectory && Self.developerFolderNames.contains(url.lastPathComponent)
            && !relativePath.split(separator: "/").dropLast().contains { Self.developerFolderNames.contains(String($0)) }

        return ItemRecord(
            path: url.path, root: root, relativePath: relativePath,
            isDirectory: isDirectory, isPackage: isPackage,
            logicalSize: logical, allocatedSize: allocated, modified: v.contentModificationDate,
            // Only the item's own date added here; scanBlocking raises it to the latest along the path.
            // record(at:) keeps this lower bound, which errs toward "old" like before.
            inPlaceSince: v.addedToDirectoryDate,
            isUbiquitous: v.isUbiquitousItem, isUploaded: v.ubiquitousItemIsUploaded,
            isUploading: v.ubiquitousItemIsUploading,
            downloadingStatus: Self.downloading(v.ubiquitousItemDownloadingStatus),
            uploadingError: Self.itemError(v.ubiquitousItemUploadingError),
            downloadingError: Self.itemError(v.ubiquitousItemDownloadingError),
            hasUnresolvedConflicts: v.ubiquitousItemHasUnresolvedConflicts,
            isExcludedFromSync: v.ubiquitousItemIsExcludedFromSync,
            isDataless: (flags ?? 0) & BSDFlags.sfDataless != 0, bsdFlags: flags,
            // scanBlocking fills this in; record(at:) leaves it 0, harmless since only file-like items are retried.
            descendantCount: isDeveloperFolder ? 0 : nil
        )
    }

    /// Metadata-only walk below `url` that stops after `descendantCap` items.
    /// Sizes are nil unless every descendant was listed and sized.
    private func walk(_ url: URL) -> (count: Int, logical: Int64?, allocated: Int64?) {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey,
                                         .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        var complete = true
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys),
                                                     errorHandler: { _, _ in complete = false; return true })
        else { return (0, nil, nil) }
        var count = 0
        var logical: Int64? = 0, allocated: Int64? = 0
        for case let child as URL in e {
            count += 1
            if count >= Self.descendantCap { return (count, nil, nil) }
            let v = try? child.resourceValues(forKeys: keys)
            if v?.isDirectory == true { continue }
            let size = (v?.totalFileSize ?? v?.fileSize).map { Int64($0) }
            let alloc = (v?.totalFileAllocatedSize ?? v?.fileAllocatedSize).map { Int64($0) }
            logical = logical.flatMap { sum in size.map { sum + $0 } }
            allocated = allocated.flatMap { sum in alloc.map { sum + $0 } }
        }
        return complete ? (count, logical, allocated) : (count, nil, nil)
    }

    private static func downloading(_ status: URLUbiquitousItemDownloadingStatus?) -> DownloadingStatus? {
        guard let status else { return nil }
        switch status {
        case .current: return .current
        case .downloaded: return .downloaded
        case .notDownloaded: return .notDownloaded
        default: return nil
        }
    }

    /// The top-level error, or the one it wraps (NSUnderlyingErrorKey) when only that one is a code we know,
    /// so a generic Cocoa error around a full iCloud still reads as "storage full".
    static func itemError(_ error: NSError?) -> ItemError? {
        guard let top = error else { return nil }
        let t = ItemError(domain: top.domain, code: top.code, message: top.localizedDescription)
        if ErrorCatalog.reason(for: t) == nil, let u = top.userInfo[NSUnderlyingErrorKey] as? NSError {
            let ue = ItemError(domain: u.domain, code: u.code, message: top.localizedDescription)
            if ErrorCatalog.reason(for: ue) != nil { return ue }
        }
        return t
    }
}

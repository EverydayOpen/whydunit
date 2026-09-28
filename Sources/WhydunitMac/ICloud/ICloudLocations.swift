import Foundation
import WhydunitCore

public struct ICloudLocations: Sendable {
    /// ~/Library/Mobile Documents/com~apple~CloudDocs if it exists.
    public let cloudDocs: URL?
    /// iCloudDrive whenever cloudDocs exists; desktop/documents only when those folders are in iCloud.
    public let roots: [ScanRoot: URL]
    /// Existing folders where an update or setting change moved files.
    public let relocatedFolders: [String]

    public static func current() -> ICloudLocations {
        let fm = FileManager.default
        let home = SystemInfo.homeDirectory
        let docs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let cloudDocs = fm.fileExists(atPath: docs.path) ? docs : nil

        var roots: [ScanRoot: URL] = [:]
        roots[.iCloudDrive] = cloudDocs
        // "Desktop & Documents Folders" is one toggle; since Sonoma it makes CloudDocs/Documents a symlink to the real
        // ~/Documents (no TCC needed to read). A plain CloudDocs/Documents folder, left after turning it off, doesn't match.
        let documents = home.appendingPathComponent("Documents").resolvingSymlinksInPath().path
        let viaLink = cloudDocs.map { $0.appendingPathComponent("Documents").resolvingSymlinksInPath().path == documents } ?? false
        for (root, name) in [(ScanRoot.desktop, "Desktop"), (ScanRoot.documents, "Documents")] {
            // Normally ~/Desktop and ~/Documents are the real folders. If a layout has them the other way round,
            // the folder lives inside CloudDocs and the iCloud Drive scan covers it.
            let url = home.appendingPathComponent(name, isDirectory: true).resolvingSymlinksInPath()
            if let cloudDocs, url.path.hasPrefix(cloudDocs.path + "/") { continue }
            // Not isUbiquitousItem: it's also true under OneDrive, Dropbox or any other File Provider that took over
            // ~/Desktop or ~/Documents.
            if viaLink { roots[root] = url }
        }

        let shared = "/Users/Shared/Relocated Items"
        // A second Mac's "Desktop - <Mac>" folders are inside iCloud Drive's Desktop/Documents; the classifier finds those.
        var relocated = ((try? fm.contentsOfDirectory(atPath: home.path)) ?? [])
            .filter { $0.hasPrefix("iCloud Drive (Archive)") }
            .sorted()
            .map { home.appendingPathComponent($0).path }
        if fm.fileExists(atPath: shared) { relocated.append(shared) }
        return ICloudLocations(cloudDocs: cloudDocs, roots: roots, relocatedFolders: relocated)
    }

    /// True if `url` is inside ~/Library/Mobile Documents or any iCloud-synced root (used to refuse
    /// backup destinations). Compares both the literal and the symlink-resolved paths, case-insensitively,
    /// so "~/Library/Mobile Documents/com~apple~CloudDocs/Desktop/x" and "~/desktop/x" are both caught.
    public func contains(_ url: URL) -> Bool {
        // resolvingSymlinksInPath may leave a path that doesn't exist yet unresolved, so callers pass one whose
        // existing part is already resolved (BackupService does).
        func forms(_ u: URL) -> [String] {
            [u.standardizedFileURL.path, u.resolvingSymlinksInPath().path].map { $0.lowercased() }
        }
        let mobileDocuments = SystemInfo.homeDirectory.appendingPathComponent("Library/Mobile Documents", isDirectory: true)
        let bases = ([mobileDocuments] + Array(roots.values)).flatMap(forms)
        return forms(url).contains { path in bases.contains { path == $0 || path.hasPrefix($0 + "/") } }
    }
}

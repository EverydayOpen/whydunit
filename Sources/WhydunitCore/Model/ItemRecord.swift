import Foundation

/// Where a scanned item lives. Desktop and Documents count only when "Desktop & Documents" is in iCloud.
public enum ScanRoot: String, Codable, CaseIterable, Sendable {
    case iCloudDrive, desktop, documents

    public var displayName: String {
        switch self {
        case .iCloudDrive: "iCloud Drive"
        case .desktop: "Desktop"
        case .documents: "Documents"
        }
    }
}

/// `URLUbiquitousItemDownloadingStatus` without the Foundation-on-Darwin type.
public enum DownloadingStatus: String, Codable, Sendable {
    case current, downloaded, notDownloaded
}

/// An `NSError` flattened to plain values.
public struct ItemError: Codable, Hashable, Sendable {
    public var domain: String
    public var code: Int
    public var message: String

    public init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }
}

/// One file or folder seen by the scanner. Produced by WhydunitMac, classified by WhydunitCore.
///
/// Every ubiquity value is Optional: `nil` means "macOS didn't tell us", never "fine".
public struct ItemRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: String { path }

    /// Absolute path on this Mac.
    public var path: String
    public var root: ScanRoot
    /// Path relative to the root, e.g. "Finance/Budget 2026.numbers".
    public var relativePath: String
    public var isDirectory: Bool
    /// A bundle such as .pages or .app, treated as one item.
    public var isPackage: Bool

    public var logicalSize: Int64?
    public var allocatedSize: Int64?
    public var modified: Date?
    /// When the item arrived where it is: the latest date added of it or any folder above it. Moves and Finder
    /// copies keep `modified`, so an upload wait counts from the later of the two.
    public var inPlaceSince: Date?

    public var isUbiquitous: Bool?
    public var isUploaded: Bool?
    public var isUploading: Bool?
    public var downloadingStatus: DownloadingStatus?
    public var uploadingError: ItemError?
    public var downloadingError: ItemError?
    public var hasUnresolvedConflicts: Bool?
    public var isExcludedFromSync: Bool?

    /// `SF_DATALESS` is set: the content lives only in iCloud (evicted / "Optimize Mac Storage").
    public var isDataless: Bool
    /// Raw `st_flags` from `lstat`.
    public var bsdFlags: UInt32?
    /// For folders named like developer churn folders (node_modules, .git): descendant count, capped.
    public var descendantCount: Int?
    /// The folder could not be listed (dataless folder or permission error), so its contents are unknown.
    public var listingFailed: Bool

    public init(
        path: String, root: ScanRoot, relativePath: String,
        isDirectory: Bool = false, isPackage: Bool = false,
        logicalSize: Int64? = nil, allocatedSize: Int64? = nil, modified: Date? = nil, inPlaceSince: Date? = nil,
        isUbiquitous: Bool? = nil, isUploaded: Bool? = nil, isUploading: Bool? = nil,
        downloadingStatus: DownloadingStatus? = nil,
        uploadingError: ItemError? = nil, downloadingError: ItemError? = nil,
        hasUnresolvedConflicts: Bool? = nil, isExcludedFromSync: Bool? = nil,
        isDataless: Bool = false, bsdFlags: UInt32? = nil,
        descendantCount: Int? = nil, listingFailed: Bool = false
    ) {
        self.path = path
        self.root = root
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.modified = modified
        self.inPlaceSince = inPlaceSince
        self.isUbiquitous = isUbiquitous
        self.isUploaded = isUploaded
        self.isUploading = isUploading
        self.downloadingStatus = downloadingStatus
        self.uploadingError = uploadingError
        self.downloadingError = downloadingError
        self.hasUnresolvedConflicts = hasUnresolvedConflicts
        self.isExcludedFromSync = isExcludedFromSync
        self.isDataless = isDataless
        self.bsdFlags = bsdFlags
        self.descendantCount = descendantCount
        self.listingFailed = listingFailed
    }

    /// File name (last path component).
    public var name: String { (relativePath as NSString).lastPathComponent }

    /// "iCloud Drive › Finance" style location of the containing folder.
    public var displayFolder: String {
        let parent = (relativePath as NSString).deletingLastPathComponent
        let parts = [root.displayName] + parent.split(separator: "/").map(String.init)
        return parts.joined(separator: " › ")
    }
}

/// BSD file flags from `<sys/stat.h>`, defined here so Core stays portable.
public enum BSDFlags {
    public static let ufImmutable: UInt32 = 0x0000_0002 // uchg
    public static let ufAppend: UInt32 = 0x0000_0004    // uappnd
    public static let sfImmutable: UInt32 = 0x0002_0000 // schg
    public static let sfAppend: UInt32 = 0x0004_0000    // sappnd
    public static let sfDataless: UInt32 = 0x4000_0000  // dataless (content not on this Mac)
}

import Foundation
import WhydunitCore

public enum SystemInfo {
    public static func osVersion() -> OSVersion {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return OSVersion(v.majorVersion, v.minorVersion, v.patchVersion)
    }

    public static func freeBytes(at url: URL) -> Int64? {
        let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        return v?.volumeAvailableCapacityForImportantUsage ?? v?.volumeAvailableCapacity.map { Int64($0) }
    }

    /// The real home folder (the app is not sandboxed).
    public static var homeDirectory: URL { FileManager.default.homeDirectoryForCurrentUser }
}

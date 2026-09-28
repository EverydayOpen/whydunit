import Foundation

/// macOS version as numbers, e.g. 26.4.1.
public struct OSVersion: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (a: Self, b: Self) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }

    public var description: String { patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)" }
}

/// Outcome of writing a small probe file into iCloud Drive and watching whether it uploads.
/// Three-state on purpose: `unknown` must never be treated as a failure (it never starts a fix).
public enum ProbeResult: Codable, Hashable, Sendable {
    case notRun
    /// macOS reported the probe as uploaded after this many seconds.
    case uploaded(seconds: Double)
    /// macOS explicitly reported "not uploaded" for the whole wait.
    case notUploaded(waitedSeconds: Double)
    /// macOS never reported an upload state (nil), or the probe could not be written.
    case unknown(reason: String)
}

/// Everything the classifier needs besides the item list. Time is passed in; Core never reads a clock.
public struct ScanContext: Codable, Hashable, Sendable {
    public var now: Date
    public var os: OSVersion
    public var probe: ProbeResult
    /// Free space on the home volume ("important usage" capacity), when known.
    public var freeBytes: Int64?
    /// Roots that exist but could not be read (permission).
    public var deniedRoots: [ScanRoot]
    /// Absolute paths of folders where an update or setting change moved files
    /// ("iCloud Drive (Archive)", "Relocated Items"). The classifier adds a second Mac's "Desktop - <Mac>" folders.
    public var relocatedFolders: [String]
    /// An item that is not uploaded and older than this is "stuck".
    public var stuckAge: TimeInterval

    public init(
        now: Date, os: OSVersion, probe: ProbeResult = .notRun, freeBytes: Int64? = nil,
        deniedRoots: [ScanRoot] = [], relocatedFolders: [String] = [], stuckAge: TimeInterval = 2 * 3600
    ) {
        self.now = now
        self.os = os
        self.probe = probe
        self.freeBytes = freeBytes
        self.deniedRoots = deniedRoots
        self.relocatedFolders = relocatedFolders
        self.stuckAge = stuckAge
    }
}

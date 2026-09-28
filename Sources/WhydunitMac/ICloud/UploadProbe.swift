import Foundation
import WhydunitCore

public enum UploadProbe {
    /// Lives at the top of iCloud Drive; the scanner skips it.
    public static let folderName = "Whydunit Probe"

    /// Writes 1 MB of random bytes to "<cloudDocs>/Whydunit Probe/probe-<install id>-<uuid>.bin", polls isUploaded every 5 s
    /// up to `timeout`, then trashes the probe (and the folder if empty). Only an explicit `false` at every
    /// poll gives `.notUploaded`; any nil, any poll that saw it uploading, or an upload error still reported at
    /// the end gives `.unknown`, which never starts a fix.
    public static func run(cloudDocs: URL, timeout: TimeInterval = 120) async -> ProbeResult {
        let fm = FileManager.default
        let folder = cloudDocs.appendingPathComponent(folderName, isDirectory: true)
        // Per-install prefix: the folder syncs, so the app's launch sweep trashes only this Mac's probes
        // (key shared with AppDelegate.trashLeftoverProbe).
        let defaults = UserDefaults.standard
        let installID = defaults.string(forKey: "probeInstallID") ?? UUID().uuidString
        defaults.set(installID, forKey: "probeInstallID")
        var file = folder.appendingPathComponent("probe-\(installID)-\(UUID().uuidString).bin")
        defer {
            try? fm.trashItem(at: file, resultingItemURL: nil)
            // Finder may leave a .DS_Store behind; the folder is still ours and otherwise empty.
            if let rest = try? fm.contentsOfDirectory(atPath: folder.path), rest.allSatisfy({ $0.hasPrefix(".") }) {
                try? fm.trashItem(at: folder, resultingItemURL: nil)
            }
        }

        do {
            // Never create CloudDocs itself: if iCloud Drive was turned off since the scan started, a folder made
            // here would pass for iCloud Drive from then on. Missing, this throws fileNoSuchFile.
            do { try fm.createDirectory(at: folder, withIntermediateDirectories: false) } catch CocoaError.fileWriteFileExists {}
            // Probes left by a quit or crash mid-check; an hour old can't belong to a running check.
            for name in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasPrefix("probe-") && name.hasSuffix(".bin") {
                let stale = folder.appendingPathComponent(name)
                if let date = try? stale.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   Date().timeIntervalSince(date) > 3600 {
                    try? fm.trashItem(at: stale, resultingItemURL: nil)
                }
            }
            // Random so nothing along the way can dedupe or compress the upload away.
            try Data((0..<(1 << 20)).map { _ in UInt8.random(in: .min ... .max) }).write(to: file)
        } catch {
            return .unknown(reason: "Couldn't write the test file: \(error.localizedDescription)")
        }

        let start = Date()
        var answeredEveryPoll = true, sawUploading = false
        while true {
            // Sleep first: right after the write, iCloud may not have seen the file yet.
            do { try await Task.sleep(for: .seconds(5)) } catch { return .unknown(reason: "The check was stopped.") }
            file.removeAllCachedResourceValues()
            // On a GCD thread, not the cooperative pool: FileProvider serves this read and can block it for good.
            let v: URLResourceValues? = await withCheckedContinuation { done in
                DispatchQueue.global(qos: .userInitiated).async { [file] in
                    done.resume(returning: try? file.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey,
                                                                              .ubiquitousItemUploadingErrorKey]))
                }
            }
            let waited = Date().timeIntervalSince(start)
            if v?.ubiquitousItemIsUploaded == true { return .uploaded(seconds: waited) }
            if v?.ubiquitousItemIsUploaded == nil { answeredEveryPoll = false }
            if v?.ubiquitousItemIsUploading == true { sawUploading = true }
            if waited >= timeout {
                // Judged only at the end (a brief error then an upload is a success). Full storage or no network
                // is not a stalled sync, and restarting sync wouldn't help.
                if let error = v?.ubiquitousItemUploadingError {
                    return .unknown(reason: "iCloud reported an error for the test file: \(error.localizedDescription)")
                }
                // Moving, just slowly (a big first upload, a slow uplink): busy, not stalled. A probe only queued
                // behind a backlog may never report uploading, so this covers slow uploads, not a deep queue.
                if sawUploading {
                    return .unknown(reason: "iCloud was still uploading the test file; it may be busy with other files.")
                }
                return answeredEveryPoll
                    ? .notUploaded(waitedSeconds: waited)
                    : .unknown(reason: "macOS didn't report whether the test file uploaded.")
            }
        }
    }
}

import Foundation

public enum SyncService {
    /// Signals only this user's own `bird`; launchd starts it again.
    public static func restartBird() async throws -> Bool {
        let result = try await ProcessRunner.run("/usr/bin/pkill", ["-TERM", "-x", "-U", String(getuid()), "bird"])
        switch (result.timedOut, result.status) {
        case (false, 0): return true    // signalled
        case (false, 1): return false   // no bird process was running
        default:
            let detail = result.timedOut ? "timed out" : "exit \(result.status) \(result.stderr)"
            throw NSError(domain: "Whydunit.SyncService", code: Int(result.status),
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't restart iCloud sync (pkill \(detail))."])
        }
    }
}

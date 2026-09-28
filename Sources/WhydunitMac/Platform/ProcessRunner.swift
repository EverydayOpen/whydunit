import Foundation
import os

public struct ProcessResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String
    public let timedOut: Bool
}

public enum ProcessRunner {
    /// Absolute executable path + args; drains stdout/stderr concurrently (no 64 KB pipe deadlock);
    /// terminates on timeout; caps captured output at `maxOutputBytes`. Never runs a shell.
    public static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 30,
                           maxOutputBytes: Int = 4 << 20) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let out = Sink(), err = Sink()
        let timedOut = OSAllocatedUnfairLock(initialState: false)
        let group = DispatchGroup()

        return try await withCheckedThrowingContinuation { continuation in
            group.enter()
            process.terminationHandler = { _ in group.leave() }
            // leave() here too: a DispatchGroup freed while entered is a libdispatch crash.
            do { try process.run() } catch { group.leave(); continuation.resume(throwing: error); return }

            for (pipe, sink) in [(outPipe, out), (errPipe, err)] {
                group.enter()
                DispatchQueue.global().async {
                    sink.drain(pipe.fileHandleForReading, cap: maxOutputBytes)
                    group.leave()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                timedOut.withLock { $0 = true }
                process.terminate()
                // A child that ignores SIGTERM would otherwise keep the caller waiting forever.
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
            group.notify(queue: .global()) {
                continuation.resume(returning: ProcessResult(
                    status: process.terminationStatus, stdout: out.string, stderr: err.string,
                    timedOut: timedOut.withLock { $0 }))
            }
        }
    }
}

/// Written by one drain thread and read only after the DispatchGroup reports that thread done,
/// so the group orders every access.
private final class Sink: @unchecked Sendable {
    private var data = Data()
    var string: String { String(decoding: data, as: UTF8.self) }

    func drain(_ handle: FileHandle, cap: Int) {
        // Keep reading past the cap so the child never blocks on a full pipe.
        // VERIFY: read(upToCount:) returns what it has at EOF (empty/nil once the child's end closes).
        while let chunk = try? handle.read(upToCount: 1 << 16), !chunk.isEmpty {
            if data.count < cap { data.append(chunk.prefix(cap - data.count)) }
        }
    }
}

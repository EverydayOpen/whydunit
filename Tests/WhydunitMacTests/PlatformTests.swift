import Foundation
import WhydunitCore
@testable import WhydunitMac
import XCTest

final class PlatformTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func testMaterializationPolicyIsAccepted() {
        XCTAssertTrue(Materialization.disableForProcess())
    }

    func testRunsEcho() async throws {
        let result = try await ProcessRunner.run("/bin/echo", ["hello", "world"])
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "hello world\n")
        XCTAssertEqual(result.stderr, "")
        XCTAssertFalse(result.timedOut)
    }

    func testTimeoutTerminates() async throws {
        let start = Date()
        let result = try await ProcessRunner.run("/bin/sleep", ["30"], timeout: 0.5)
        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    func testLargeOutputDrainsAndCaps() async throws {
        let full = try await ProcessRunner.run("/usr/bin/seq", ["1", "200000"]) // ~1.3 MB, far past the 64 KB pipe buffer
        XCTAssertEqual(full.status, 0)
        XCTAssertFalse(full.timedOut)
        XCTAssertTrue(full.stdout.hasSuffix("\n200000\n"))
        let capped = try await ProcessRunner.run("/usr/bin/seq", ["1", "200000"], maxOutputBytes: 1000)
        XCTAssertEqual(capped.status, 0)
        XCTAssertEqual(capped.stdout.utf8.count, 1000)
    }

    func testMissingExecutableThrows() async {
        do {
            _ = try await ProcessRunner.run("/nonexistent/whydunit-tool", [])
            XCTFail("expected an error")
        } catch {}
    }

    func testContainsCatchesEveryWayIntoARoot() throws {
        let base = try tempDir()
        let drive = base.appendingPathComponent("Drive"), desktop = base.appendingPathComponent("Desktop")
        for url in [drive, desktop] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        let shortcut = base.appendingPathComponent("Shortcut")
        try FileManager.default.createSymbolicLink(at: shortcut, withDestinationURL: drive)
        let locations = ICloudLocations(cloudDocs: drive, roots: [.iCloudDrive: drive, .desktop: desktop], relocatedFolders: [])

        XCTAssertTrue(locations.contains(drive))
        XCTAssertTrue(locations.contains(desktop.appendingPathComponent("Backups/not yet created")))
        XCTAssertTrue(locations.contains(URL(fileURLWithPath: desktop.path.uppercased())))
        XCTAssertTrue(locations.contains(base.appendingPathComponent("Desktop/../Drive/x")))
        XCTAssertTrue(locations.contains(shortcut))
        XCTAssertTrue(locations.contains(SystemInfo.homeDirectory.appendingPathComponent("Library/Mobile Documents/iCloud~com~example")))
        XCTAssertFalse(locations.contains(base.appendingPathComponent("Desktop Backups")))
        XCTAssertFalse(locations.contains(base))
        XCTAssertFalse(locations.contains(SystemInfo.homeDirectory.appendingPathComponent("Whydunit Backups")))
    }

    func testScannerReadsMetadataAndSkipsWhatItShould() async throws {
        let base = try tempDir()
        let drive = base.appendingPathComponent("Drive"), desktop = base.appendingPathComponent("Desktop")
        try write("hello", to: drive.appendingPathComponent("a.txt"))
        try write("x", to: drive.appendingPathComponent("node_modules/pkg/index.js"))
        try write("y", to: drive.appendingPathComponent("node_modules/b.js"))
        try write("abc", to: drive.appendingPathComponent("Thing.app/Contents/Info.plist"))
        try write("p", to: drive.appendingPathComponent("Whydunit Probe/probe-1.bin"))
        try write("nm", to: drive.appendingPathComponent("deps.nosync/pkg/a.js"))
        try write("d", to: desktop.appendingPathComponent("note.txt"))
        // Sonoma layout: iCloud Drive's Desktop is a symlink to the real ~/Desktop, which is its own root.
        try FileManager.default.createSymbolicLink(at: drive.appendingPathComponent("Desktop"), withDestinationURL: desktop)
        let missing = base.appendingPathComponent("Missing")

        let out = try await ICloudScanner().scan(roots: [.iCloudDrive: drive, .desktop: desktop, .documents: missing]) { _ in }
        let items = Dictionary(out.items.map { ("\($0.root.rawValue)/\($0.relativePath)", $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(items["iCloudDrive/a.txt"]?.logicalSize, 5)
        XCTAssertEqual(items["iCloudDrive/a.txt"]?.isDataless, false)
        XCTAssertNotNil(items["iCloudDrive/a.txt"]?.bsdFlags)
        XCTAssertEqual(items["iCloudDrive/node_modules"]?.descendantCount, 3)
        XCTAssertNotNil(items["iCloudDrive/node_modules/pkg/index.js"])
        XCTAssertEqual(items["iCloudDrive/Thing.app"]?.isPackage, true)
        XCTAssertEqual(items["iCloudDrive/Thing.app"]?.logicalSize, 3)
        XCTAssertEqual(items["iCloudDrive/deps.nosync"]?.logicalSize, 2)   // sized, not listed item by item
        XCTAssertNotNil(items["desktop/note.txt"])
        XCTAssertFalse(items.keys.contains {
            $0.hasPrefix("iCloudDrive/Thing.app/") || $0.hasPrefix("iCloudDrive/Whydunit Probe") || $0 == "iCloudDrive/Desktop"
                || $0.hasPrefix("iCloudDrive/deps.nosync/")
        })
        XCTAssertEqual(out.deniedRoots, [.documents])

        let again = ICloudScanner().record(at: drive.appendingPathComponent("a.txt"), root: .iCloudDrive, rootURL: drive)
        XCTAssertEqual(again?.relativePath, "a.txt")
    }

    func testItemErrorUsesAKnownUnderlyingError() {
        let quota = NSError(domain: "NSFileProviderErrorDomain", code: -1003)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: [NSUnderlyingErrorKey: quota])
        XCTAssertEqual(ICloudScanner.itemError(wrapped)?.domain, "NSFileProviderErrorDomain")
        XCTAssertEqual(ICloudScanner.itemError(wrapped)?.code, -1003)
        let unknownInside = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: [NSUnderlyingErrorKey: NSError(domain: "X", code: 1)])
        XCTAssertEqual(ICloudScanner.itemError(unknownInside)?.code, 512)
        XCTAssertNil(ICloudScanner.itemError(nil))
    }

    func testProbeOutsideICloudNeverReportsUploadAndCleansUp() async throws {
        let drive = try tempDir()
        let result = await UploadProbe.run(cloudDocs: drive, timeout: 0)
        if case .uploaded = result { XCTFail("a plain folder can't upload") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: drive.appendingPathComponent(UploadProbe.folderName).path))
    }

    func testProbeIsUnknownWhenItCannotWrite() async throws {
        // iCloud Drive turned off since the scan started: the probe must not recreate its folder.
        let gone = try tempDir().appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
        let result = await UploadProbe.run(cloudDocs: gone, timeout: 0)
        guard case .unknown = result else { return XCTFail("got \(result)") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: gone.path))
    }
}

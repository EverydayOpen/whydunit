import CryptoKit
import Foundation
import WhydunitCore
@testable import WhydunitMac
import XCTest

final class ActionsTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sha(_ text: String) -> String {
        BackupService.hex(SHA256.hash(data: Data(text.utf8)))
    }

    private func permissions(_ url: URL) throws -> Int? {
        try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
    }

    // MARK: - BackupService

    func testBackupCopiesVerifiesAndLists() async throws {
        let tmp = try tempDir()
        let src = tmp.appendingPathComponent("src/Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: src.appendingPathComponent("Doc.pages/Data"), withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: src.appendingPathComponent("a.txt"))
        try Data("page".utf8).write(to: src.appendingPathComponent("Doc.pages/Index.xml"))
        try Data("img".utf8).write(to: src.appendingPathComponent("Doc.pages/Data/p.png"))
        let filePath = src.appendingPathComponent("a.txt").path
        let packagePath = src.appendingPathComponent("Doc.pages").path
        let items = [
            ItemRecord(path: filePath, root: .iCloudDrive, relativePath: "Folder/a.txt", logicalSize: 5),
            ItemRecord(path: packagePath, root: .iCloudDrive, relativePath: "Folder/Doc.pages", isDirectory: true, isPackage: true),
        ]
        let service = BackupService(backupsRoot: tmp.appendingPathComponent("Backups", isDirectory: true), locations: .current())
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let manifest = try await service.backUp(items, now: now, progress: { _ in })

        XCTAssertTrue(manifest.isFullyVerified)
        XCTAssertEqual(manifest.entries.count, 2)
        XCTAssertEqual(manifest.verifiedEntry(for: filePath)?.sha256, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        let expectedTree = sha("Data/p.png\0\(sha("img"))\nIndex.xml\0\(sha("page"))\n")
        XCTAssertEqual(manifest.verifiedEntry(for: packagePath)?.sha256, expectedTree)
        let copy = URL(fileURLWithPath: manifest.folder).appendingPathComponent("iCloud Drive/Folder/a.txt")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "hello")
        XCTAssertEqual(try permissions(URL(fileURLWithPath: manifest.folder)), 0o700)   // other users can't read the copies
        XCTAssertEqual(try permissions(tmp.appendingPathComponent("Backups")), 0o700)   // or list the backups

        let listed = service.listBackups()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.created, now)
        XCTAssertEqual(listed.first?.entries, manifest.entries)

        // A second backup in the same second gets its own folder instead of sharing (and overwriting) this one.
        let again = try await service.backUp(items, now: now, progress: { _ in })
        XCTAssertEqual((again.folder as NSString).lastPathComponent, BackupService.folderName(now) + " 2")
        XCTAssertEqual(service.listBackups().count, 2)
    }

    func testBackupRefusesICloudDestination() async throws {
        // Also behind a symlinked parent, with the backup folder not created yet.
        let tmp = try tempDir()
        let cloud = tmp.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: tmp.appendingPathComponent("Link"), withDestinationURL: cloud)
        let services = [
            BackupService(
                backupsRoot: SystemInfo.homeDirectory.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Backups"),
                locations: .current()),
            BackupService(backupsRoot: tmp.appendingPathComponent("Link/Whydunit", isDirectory: true),
                          locations: ICloudLocations(cloudDocs: cloud, roots: [.iCloudDrive: cloud], relocatedFolders: [])),
        ]
        let item = ItemRecord(path: "/nonexistent/a.txt", root: .iCloudDrive, relativePath: "a.txt")
        for service in services {
            do {
                _ = try await service.backUp([item], now: Date(), progress: { _ in })
                XCTFail("expected destinationInsideICloud")
            } catch BackupError.destinationInsideICloud {
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    func testBackupRefusesDatalessItem() async throws {
        let tmp = try tempDir()
        let file = tmp.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: file)
        let item = ItemRecord(path: file.path, root: .iCloudDrive, relativePath: "a.txt", isDataless: true)
        let service = BackupService(backupsRoot: tmp.appendingPathComponent("Backups"), locations: .current())
        do {
            _ = try await service.backUp([item], now: Date(), progress: { _ in })
            XCTFail("expected itemNotLocal")
        } catch BackupError.itemNotLocal(let path) {
            XCTAssertEqual(path, file.path)
        } catch {
            XCTFail("\(error)")
        }
    }

    // MARK: - UploadRetrier

    func testRetryNeedsVerifiedBackupOfThatItem() async throws {
        let item = ItemRecord(path: "/tmp/whydunit-test/x.txt", root: .iCloudDrive, relativePath: "x.txt")
        let retrier = UploadRetrier(scanner: ICloudScanner(), stagingRoot: URL(fileURLWithPath: "/tmp/whydunit-test/.staging"))
        let unverified = BackupManifest.Entry(source: item.path, copy: "/b/x.txt", bytes: 1, sha256: "", verified: false)
        let otherItem = BackupManifest.Entry(source: "/tmp/whydunit-test/y.txt", copy: "/b/y.txt", bytes: 1, sha256: "", verified: true)
        for entry in [unverified, otherItem] {
            let outcome = await retrier.retry(item, rootURL: URL(fileURLWithPath: "/tmp/whydunit-test"), backup: entry)
            guard case .skipped = outcome else { return XCTFail("\(outcome)") }
        }
        // A plain folder is never moved out, even with a verified backup of it.
        let dir = ItemRecord(path: "/tmp/whydunit-test/Dir", root: .iCloudDrive, relativePath: "Dir", isDirectory: true)
        let dirBackup = BackupManifest.Entry(source: dir.path, copy: "/b/Dir", bytes: 1, sha256: "", verified: true)
        let dirOutcome = await retrier.retry(dir, rootURL: URL(fileURLWithPath: "/tmp/whydunit-test"), backup: dirBackup)
        XCTAssertEqual(dirOutcome, .skipped(reason: "Folders aren't moved. Retry the files inside it."))
        // Outside iCloud the sync state is nil, which must never be moved out.
        let tmp = try tempDir()
        let file = tmp.appendingPathComponent("x.txt"), copy = tmp.appendingPathComponent("copy.txt")
        for url in [file, copy] { try Data("x".utf8).write(to: url) }
        let scanned = try XCTUnwrap(ICloudScanner().record(at: file, root: .iCloudDrive, rootURL: tmp))
        let local = UploadRetrier(scanner: ICloudScanner(), stagingRoot: tmp.appendingPathComponent(".staging"))
        let present = BackupManifest.Entry(source: file.path, copy: copy.path, bytes: 1, sha256: sha("x"), verified: true)
        var missing = present
        missing.copy = tmp.appendingPathComponent("gone.txt").path
        let unknown = await local.retry(scanned, rootURL: tmp, backup: present)
        XCTAssertEqual(unknown, .skipped(reason: "macOS didn't report its sync state"))
        var inCloud = present
        inCloud.copy = SystemInfo.homeDirectory.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Backups/x.txt").path
        let cloudCopy = await local.retry(scanned, rootURL: tmp, backup: inCloud)
        XCTAssertEqual(cloudCopy, .skipped(reason: "The backup copy is inside iCloud now. Back up to a folder outside iCloud first."))
        let noCopy = await local.retry(scanned, rootURL: tmp, backup: missing)
        XCTAssertEqual(noCopy, .skipped(reason: "The backup copy changed or is missing. Back up again first."))
        try Data("edited".utf8).write(to: copy)
        let editedCopy = await local.retry(scanned, rootURL: tmp, backup: present)
        XCTAssertEqual(editedCopy, .skipped(reason: "The backup copy changed or is missing. Back up again first."))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(UploadRetrier.restoredURL(for: URL(fileURLWithPath: "/a/Budget.numbers")).lastPathComponent,
                       "Budget (Whydunit restored).numbers")
        XCTAssertEqual(UploadRetrier.restoredURL(for: URL(fileURLWithPath: "/a/README")).lastPathComponent,
                       "README (Whydunit restored)")
    }

    func testRecoverStagedPutsItemsBack() throws {
        let tmp = try tempDir()
        let staging = tmp.appendingPathComponent(".staging", isDirectory: true)
        func strand(_ name: String) throws {
            let folder = staging.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(tmp.appendingPathComponent(name).path.utf8).write(to: folder.appendingPathComponent(UploadRetrier.originFile))
            try Data(name.utf8).write(to: folder.appendingPathComponent(name))
        }
        try strand("a.txt")
        try strand("b.txt")
        try Data("new".utf8).write(to: tmp.appendingPathComponent("b.txt"))   // something new took b's place
        try strand("c.txt")
        for taken in ["c.txt", "c (Whydunit restored).txt"] { try Data("new".utf8).write(to: tmp.appendingPathComponent(taken)) }
        // Power loss: the rename reached the disk, the journal's contents didn't.
        let lost = staging.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: lost, withIntermediateDirectories: true)
        try Data(count: 16).write(to: lost.appendingPathComponent(UploadRetrier.originFile))
        try Data("d".utf8).write(to: lost.appendingPathComponent("d.txt"))

        let recovered = UploadRetrier.recoverStaged(in: staging)

        XCTAssertEqual(Set(recovered.map { ($0 as NSString).lastPathComponent }),
                       ["a.txt", "b (Whydunit restored).txt", "c (Whydunit restored 2).txt", "d.txt"])
        XCTAssertTrue(recovered.contains { $0.hasSuffix("/\(lost.lastPathComponent)/d.txt") })   // reported where it is
        XCTAssertEqual(try String(contentsOf: tmp.appendingPathComponent("a.txt"), encoding: .utf8), "a.txt")
        XCTAssertEqual(try String(contentsOf: tmp.appendingPathComponent("b (Whydunit restored).txt"), encoding: .utf8), "b.txt")
        XCTAssertEqual(try String(contentsOf: tmp.appendingPathComponent("c (Whydunit restored 2).txt"), encoding: .utf8), "c.txt")
        XCTAssertEqual(UploadRetrier.recoverStaged(in: staging).map { ($0 as NSString).lastPathComponent }, ["d.txt"])
    }

    // MARK: - ActivityLog

    func testActivityLogRoundTrip() async throws {
        let url = try tempDir().appendingPathComponent("Whydunit/activity.jsonl")
        let log = ActivityLog(url: url)
        let first = AuditEntry(date: Date(timeIntervalSince1970: 1_000), action: .backUp, target: "/a", outcome: .succeeded, detail: "ok")
        let second = AuditEntry(date: Date(timeIntervalSince1970: 2_000), action: .restartSync, target: "bird", outcome: .failed, detail: "two\nlines")
        await log.append(first)
        let handle = try FileHandle(forWritingTo: url)
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data("not json\n".utf8))
        try handle.close()
        await log.append(second)

        let all = await log.all()
        XCTAssertEqual(all, [second, first])
        XCTAssertEqual(try permissions(url), 0o600)
    }
}

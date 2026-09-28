import XCTest
@testable import WhydunitCore

// Fixed clock: tests never read Date().
let now = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21T14:13:20Z
let day: TimeInterval = 86_400
let home = "/Users/jane"
let cloud = home + "/Library/Mobile Documents/com~apple~CloudDocs"

/// An uploaded, local, day-old 1 KB file in iCloud Drive unless told otherwise.
func item(_ rel: String, uploaded: Bool? = true, uploading: Bool? = false, size: Int64? = 1_000,
          age: TimeInterval = day, dataless: Bool = false, dir: Bool = false, error: ItemError? = nil,
          flags: UInt32? = 0, conflicts: Bool? = false, descendants: Int? = nil,
          listingFailed: Bool = false) -> ItemRecord {
    ItemRecord(path: cloud + "/" + rel, root: .iCloudDrive, relativePath: rel, isDirectory: dir,
               logicalSize: size, modified: now.addingTimeInterval(-age),
               isUbiquitous: true, isUploaded: uploaded, isUploading: uploading,
               uploadingError: error, hasUnresolvedConflicts: conflicts,
               isDataless: dataless, bsdFlags: flags, descendantCount: descendants, listingFailed: listingFailed)
}

func err(_ domain: String, _ code: Int) -> ItemError { ItemError(domain: domain, code: code, message: "test") }

func classify(_ items: [ItemRecord], probe: ProbeResult = .uploaded(seconds: 12), free: Int64? = nil,
              denied: [ScanRoot] = [], relocated: [String] = []) -> Diagnosis {
    ICloudClassifier.classify(items, context: ScanContext(
        now: now, os: OSVersion(26, 4, 1), probe: probe, freeBytes: free,
        deniedRoots: denied, relocatedFolders: relocated))
}

extension Diagnosis {
    func finding(_ rule: RuleID) -> Finding? { findings.first { $0.rule == rule } }
}

final class ICloudClassifierTests: XCTestCase {
    func testAllClear() {
        let d = classify([item("a.txt"), item("Report.pages")])
        XCTAssertEqual(d.findings, [])
        XCTAssertEqual(d.verdict, .ok)
        XCTAssertEqual(d.checkedCount, 2)
        XCTAssertEqual(d.unknownCount, 0)
        XCTAssertEqual(d.scannedAt, now)
    }

    // I16
    func testOnlyOnThisMacWarnsWhenOld() throws {
        let d = classify([item("old.txt", uploaded: false, size: 1_500_000), item("new.txt", uploaded: false, age: 60), item("ok.txt")])
        let f = try XCTUnwrap(d.finding(.onlyOnThisMac))
        XCTAssertEqual(f.severity, .warning)
        XCTAssertEqual(f.title, "2 items (1.5 MB) exist only on this Mac")
        XCTAssertEqual(f.itemPaths, [cloud + "/old.txt", cloud + "/new.txt"])
        XCTAssertEqual(f.totalBytes, 1_501_000)
        XCTAssertEqual(f.primaryAction, .backUp)
        XCTAssertTrue(f.steps[0].hasPrefix("Don't sign out"))
    }

    func testOnlyOnThisMacIsInfoWhenRecent() throws {
        let f = try XCTUnwrap(classify([item("new.txt", uploaded: false, age: 60)]).finding(.onlyOnThisMac))
        XCTAssertEqual(f.severity, .info)
        XCTAssertEqual(f.title, "1 item (1 KB) exists only on this Mac")
    }

    func testNilUploadIsUnknownNeverOK() throws {
        let d = classify([item("mystery.txt", uploaded: nil)])
        XCTAssertEqual(d.unknownCount, 1)
        let f = try XCTUnwrap(d.finding(.onlyOnThisMac))
        XCTAssertEqual(f.itemPaths, [cloud + "/mystery.txt"])
        XCTAssertTrue(f.explanation.contains("didn't report a sync state for 1 item"))
        XCTAssertEqual(d.verdict, .warning)
        XCTAssertNil(d.finding(.stuckItems), "I10 needs an explicit false")
    }

    // I7
    func testExcludedAndDatalessItemsAreNeverStuck() throws {
        let d = classify([
            item("cloud.mov", uploaded: nil, dataless: true),
            // The scanner lists no children of a folder excluded by name; its walked size covers them.
            item("Build.nosync", uploaded: false, size: 5_000, dir: true),
            item(".DS_Store", uploaded: nil),
            item("draft.tmp", uploaded: false),
            item("Work/~$Report.docx", uploaded: false),
        ])
        XCTAssertNil(d.finding(.onlyOnThisMac))
        XCTAssertNil(d.finding(.stuckItems))
        XCTAssertEqual(d.unknownCount, 0)
        XCTAssertEqual(d.verdict, .ok)
        let f = try XCTUnwrap(d.finding(.excludedByDesign))
        XCTAssertEqual(f.severity, .info)
        XCTAssertEqual(f.itemPaths, [cloud + "/Build.nosync", cloud + "/draft.tmp"])
        XCTAssertEqual(f.title, "2 items aren't synced by design (6 KB)")
        XCTAssertEqual(ICloudClassifier.status(of: item("Build.nosync/out.o")), .notSyncedByDesign)
    }

    // I10
    func testStuckItemsNeedProbeProof() throws {
        let stuck = item("stuck.txt", uploaded: false)
        let f = try XCTUnwrap(classify([stuck]).finding(.stuckItems))
        XCTAssertEqual(f.severity, .warning)
        XCTAssertEqual(f.title, "1 file hasn't uploaded to iCloud (1 KB)")
        XCTAssertEqual(f.primaryAction, .retryUpload)
        XCTAssertTrue(f.explanation.contains("over 2 hours"))

        for probe in [ProbeResult.notRun, .unknown(reason: "macOS returned nil"), .notUploaded(waitedSeconds: 120)] {
            XCTAssertNil(classify([stuck], probe: probe).finding(.stuckItems))
        }
        let notStuck = [
            item("busy.txt", uploaded: false, uploading: true),
            item("young.txt", uploaded: false, age: 60),
            item("nil.txt", uploaded: nil),
            item("error.txt", uploaded: false, error: err("NSFileProviderErrorDomain", -2005)),
            item("conflict.txt", uploaded: false, conflicts: true),
        ]
        for record in notStuck {
            XCTAssertNil(classify([record]).finding(.stuckItems), record.relativePath)
        }
    }

    // A move or Finder copy into iCloud Drive keeps the old modification date; the wait starts on arrival.
    func testMovedInFileIsNotOld() throws {
        var moved = item("moved.txt", uploaded: false, age: 3 * day)
        moved.inPlaceSince = now.addingTimeInterval(-5 * 60)
        let d = classify([moved])
        XCTAssertNil(d.finding(.stuckItems))
        XCTAssertEqual(try XCTUnwrap(d.finding(.onlyOnThisMac)).severity, .info)
    }

    // I11
    func testSyncStalledOnlyOnExplicitNotUploaded() throws {
        let d = classify([item("a.txt")], probe: .notUploaded(waitedSeconds: 120))
        let f = try XCTUnwrap(d.findings.first)
        XCTAssertEqual(f.rule, .syncStalled)
        XCTAssertEqual(f.severity, .critical)
        XCTAssertEqual(f.primaryAction, .restartSync)
        XCTAssertTrue(f.explanation.contains("2 minutes"))
        XCTAssertTrue(f.explanation.contains("Don't move, rename or retry individual files yet"))
        XCTAssertEqual(d.verdict, .critical)

        let unknown = classify([item("a.txt"), item("s.txt", uploaded: false)], probe: .unknown(reason: "no answer"))
        XCTAssertNil(unknown.finding(.syncStalled))
        XCTAssertNil(unknown.finding(.stuckItems))
        XCTAssertNotNil(unknown.finding(.onlyOnThisMac))
        XCTAssertEqual(classify([item("a.txt")], probe: .unknown(reason: "no answer")).findings, [])
    }

    // I11: another file uploading means iCloud is busy, not stalled.
    func testNoSyncStalledWhileSomethingUploads() {
        let busy = classify([item("big.mov", uploaded: false, uploading: true, age: 60)], probe: .notUploaded(waitedSeconds: 120))
        XCTAssertNil(busy.finding(.syncStalled))
    }

    // I1, I2, I4
    func testUploadErrorsMapToRules() throws {
        let d = classify([
            item("q1.txt", uploaded: false, error: err("NSCocoaErrorDomain", 4354)),
            item("q2.txt", uploaded: false, error: err("NSFileProviderErrorDomain", -1003)),
            item("s1.txt", uploaded: false, error: err("NSCocoaErrorDomain", 4355)),
            item("s2.txt", uploaded: false, error: err("NSFileProviderErrorDomain", -1004)),
            item("r1.txt", uploaded: false, error: err("NSFileProviderErrorDomain", -2005)),
        ])
        let full = try XCTUnwrap(d.finding(.storageFull))
        XCTAssertEqual(full.itemPaths, [cloud + "/q1.txt", cloud + "/q2.txt"])
        XCTAssertEqual(full.severity, .critical)
        XCTAssertEqual(full.title, "iCloud storage is full, so 2 items can't upload (2 KB)")
        XCTAssertEqual(full.primaryAction, .openICloudSettings)

        let offline = try XCTUnwrap(d.finding(.serverUnreachable))
        XCTAssertEqual(offline.itemPaths, [cloud + "/s1.txt", cloud + "/s2.txt"])
        XCTAssertEqual(offline.title, "iCloud couldn't be reached for 2 items (2 KB)")

        let rejected = try XCTUnwrap(d.finding(.uploadRejected))
        XCTAssertEqual(rejected.itemPaths, [cloud + "/r1.txt"])
        XCTAssertEqual(rejected.title, "1 item couldn't upload: rejected by iCloud (1 KB)")
        XCTAssertEqual(rejected.primaryAction, .retryUpload)
        XCTAssertEqual(ICloudClassifier.status(of: item("r1.txt", error: err("NSFileProviderErrorDomain", -2005))), .uploadFailed)
    }

    func testUploadErrorTitleWithoutCommonReason() throws {
        let d = classify([
            item("a.txt", uploaded: false, error: err("NSFileProviderErrorDomain", -2005)),
            item("b.txt", uploaded: false, error: err("SomeDomain", 7)),
        ])
        XCTAssertEqual(try XCTUnwrap(d.finding(.uploadRejected)).title, "2 items couldn't upload to iCloud (2 KB)")
        XCTAssertNil(d.finding(.storageFull))
        XCTAssertNil(d.finding(.serverUnreachable))
    }

    // I5
    func testLockFlagsGiveCopyableCommand() throws {
        let d = classify([
            item("a b.txt", flags: BSDFlags.ufAppend),
            item("it's.txt", flags: BSDFlags.sfImmutable | BSDFlags.ufImmutable),
            item("locked.txt", flags: BSDFlags.ufImmutable),
        ])
        let f = try XCTUnwrap(d.finding(.lockFlags))
        XCTAssertEqual(f.itemPaths, [cloud + "/a b.txt", cloud + "/it's.txt"])
        XCTAssertEqual(f.title, "2 items have lock flags that block iCloud sync")
        XCTAssertEqual(f.primaryAction, .copyCommand)
        XCTAssertEqual(f.command, """
            chflags nouchg,nouappnd '\(cloud)/a b.txt'
            sudo chflags noschg,nosappnd,nouchg,nouappnd '\(cloud)/it'\\''s.txt'
            """)
        XCTAssertNil(classify([item("locked.txt", flags: BSDFlags.ufImmutable)]).finding(.lockFlags), "uchg alone doesn't block sync")
    }

    // I6
    func testTooLarge() throws {
        let f = try XCTUnwrap(classify([item("disk.dmg", uploaded: false, size: 50_000_000_001)]).finding(.tooLarge))
        XCTAssertEqual(f.title, "1 file is too large for iCloud (50 GB)")
        XCTAssertNil(classify([item("disk.dmg", size: 50_000_000_000)]).finding(.tooLarge))
    }

    // I8
    func testConflicts() throws {
        let f = try XCTUnwrap(classify([item("notes.txt", conflicts: true)]).finding(.conflicts))
        XCTAssertEqual(f.title, "1 item has conflicting versions")
        XCTAssertEqual(f.primaryAction, .showInFinder)
        XCTAssertNil(classify([item("notes.txt", conflicts: nil)]).finding(.conflicts))
    }

    // I13
    func testStorageDebtUsesAtLeastWording() throws {
        let items = [item("movie.mov", size: 2_000, dataless: true), item("unknown.mov", size: nil, dataless: true)]
        let f = try XCTUnwrap(classify(items, free: 1_000).finding(.storageDebt))
        XCTAssertEqual(f.severity, .warning)
        XCTAssertEqual(f.totalBytes, 2_000)
        XCTAssertTrue(f.bytesIsLowerBound)
        XCTAssertEqual(f.title, "iCloud-only files need at least 2 KB; only 1 KB is free")
        XCTAssertNil(classify(items, free: 5_000).finding(.storageDebt))
        XCTAssertNil(classify(items, free: nil).finding(.storageDebt))
    }

    // I14
    func testDeveloperFoldersReportOutermostOnly() throws {
        let d = classify([
            item("proj/node_modules", dir: true, descendants: 10_000),
            item("proj/node_modules/a/node_modules", dir: true, descendants: 6_000),
            item("site/.git", dir: true, descendants: 5_000),
        ])
        let f = try XCTUnwrap(d.finding(.developerFolders))
        XCTAssertEqual(f.itemPaths, [cloud + "/proj/node_modules"])
        XCTAssertEqual(f.severity, .info)
        XCTAssertEqual(f.title, "1 developer folder in iCloud Drive holds thousands of files")
    }

    // I15
    func testRelocatedFolders() throws {
        let folders = [home + "/iCloud Drive (Archive)", "/Users/Shared/Relocated Items"]
        let f = try XCTUnwrap(classify([], relocated: folders).finding(.relocatedFiles))
        XCTAssertEqual(f.itemPaths, folders)
        XCTAssertEqual(f.severity, .info)
        XCTAssertEqual(f.title, "2 folders may hold files moved by macOS")
        XCTAssertNil(classify([]).finding(.relocatedFiles))
    }

    func testSecondMacFoldersAreRelocated() throws {
        let archive = home + "/iCloud Drive (Archive)"
        let d = classify([
            item("Desktop/Desktop - Jane's MacBook", dir: true),
            item("Documents/Documents - iMac", dir: true),
            item("Documents/Desktop - wrong folder", dir: true),
            item("Desktop - top level", dir: true),
            item("Desktop/Desktop - a file.txt"),
            ItemRecord(path: home + "/Documents/Documents - Old Mac", root: .documents,
                       relativePath: "Documents - Old Mac", isDirectory: true),
        ], relocated: [archive])
        let f = try XCTUnwrap(d.finding(.relocatedFiles))
        XCTAssertEqual(f.itemPaths, [archive, cloud + "/Desktop/Desktop - Jane's MacBook", cloud + "/Documents/Documents - iMac",
                                     home + "/Documents/Documents - Old Mac"])
        XCTAssertEqual(f.title, "4 folders may hold files moved by macOS")
    }

    func testUnreadableFoldersAreUnknownNotAVerdict() throws {
        let d = classify([item("Archive", dir: true, listingFailed: true), item("Readable", dir: true)])
        let f = try XCTUnwrap(d.finding(.unreadableFolders))
        XCTAssertEqual(f.severity, .unknown)
        XCTAssertEqual(f.title, "1 folder couldn't be checked")
        XCTAssertEqual(d.verdict, .ok)
        XCTAssertNil(classify([item("Cloud", dataless: true, dir: true, listingFailed: true)]).finding(.unreadableFolders))
    }

    func testPermissionDenied() throws {
        let f = try XCTUnwrap(classify([], denied: [.desktop, .documents]).finding(.permissionDenied))
        XCTAssertEqual(f.title, "Desktop and Documents couldn't be checked")
        XCTAssertEqual(f.primaryAction, .openPrivacySettings)
        XCTAssertEqual(f.itemPaths, [])
        XCTAssertNil(classify([]).finding(.permissionDenied))
    }

    func testFindingsSortWorstFirstThenRuleOrder() {
        let d = classify(stalledScenario, probe: .notUploaded(waitedSeconds: 120), denied: [.desktop])
        XCTAssertEqual(d.findings.map(\.rule),
                       [.syncStalled, .storageFull, .onlyOnThisMac, .lockFlags, .permissionDenied, .excludedByDesign, .unreadableFolders])
    }

    func testCopyFollowsToneRules() {
        let diagnoses = [
            classify(stalledScenario, probe: .notUploaded(waitedSeconds: 120), denied: [.desktop]),
            classify(busyScenario, free: 1_000, relocated: [home + "/iCloud Drive (Archive)"]),
        ]
        XCTAssertEqual(Set(diagnoses.flatMap(\.findings).map(\.rule)), Set(RuleID.allCases))
        for f in diagnoses.flatMap(\.findings) {
            XCTAssertLessThanOrEqual(f.title.count, 60, f.title)
            XCTAssertFalse(f.title.hasSuffix("."), f.title)
            XCTAssertFalse(f.title.contains("!") || f.explanation.contains("!"), f.title)
            XCTAssertLessThanOrEqual(f.explanation.components(separatedBy: ". ").count, 3, f.explanation)
            XCTAssertTrue((1...4).contains(f.steps.count), f.title)
        }
    }

    func testStatusLabels() {
        let labels = [
            item("a", uploaded: false), item("b", uploaded: false, uploading: true),
            item("c", uploaded: false, error: err("SomeDomain", 1)), item("d", dataless: true), item("e"),
            item("f.nosync"), item("g", conflicts: true), item("h", uploaded: nil),
        ].map { ICloudClassifier.status(of: $0).label }
        XCTAssertEqual(labels, ["Waiting to upload", "Uploading", "Upload failed", "Only in iCloud", "Synced",
                                "Not synced by design", "Has conflicts", "Unknown"])
    }

    func testSafeToPreselect() {
        XCTAssertTrue(ICloudClassifier.isSafeToPreselect(item("old.txt"), now: now))
        XCTAssertFalse(ICloudClassifier.isSafeToPreselect(item("recent.txt", age: 5 * 60), now: now))
        XCTAssertFalse(ICloudClassifier.isSafeToPreselect(item("cloud.txt", dataless: true), now: now))
        XCTAssertFalse(ICloudClassifier.isSafeToPreselect(item("Folder", dir: true, listingFailed: true), now: now))
        let undated = ItemRecord(path: cloud + "/x", root: .iCloudDrive, relativePath: "x", isUploaded: false)
        XCTAssertFalse(ICloudClassifier.isSafeToPreselect(undated, now: now))
    }

    func testShortNamesAreDistinct() {
        XCTAssertEqual(Set(RuleID.allCases.map(\.shortName)).count, RuleID.allCases.count)
    }

    // MARK: - Scenarios

    /// Triggers I11 (with the probe), I1, I16, I5, permissionDenied (with a denied root), I7, unreadableFolders.
    private var stalledScenario: [ItemRecord] {
        [
            item("local.txt", uploaded: false),
            item("full.txt", uploaded: false, error: err("NSCocoaErrorDomain", 4354)),
            item("lock.txt", flags: BSDFlags.ufAppend),
            item("x.nosync"),
            item("Archive", dir: true, listingFailed: true),
        ]
    }

    /// Triggers I10, I16 (with an unknown), I2, I4, I6, I8, I13, I14 and, with a relocated folder, I15.
    private var busyScenario: [ItemRecord] {
        [
            item("stuck.txt", uploaded: false),
            item("mystery.txt", uploaded: nil),
            item("offline.txt", uploaded: false, error: err("NSCocoaErrorDomain", 4355)),
            item("odd.txt", uploaded: false, error: err("NSFileProviderErrorDomain", -2015)),
            item("big.dmg", uploaded: false, size: 60_000_000_000),
            item("notes.txt", conflicts: true),
            item("cloud.mov", size: 2_000, dataless: true),
            item("proj/node_modules", dir: true, descendants: 9_000),
        ]
    }
}

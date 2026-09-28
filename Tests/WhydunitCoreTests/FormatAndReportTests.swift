import XCTest
@testable import WhydunitCore

final class FormatAndReportTests: XCTestCase {
    func testByteFormat() {
        let cases: [(Int64?, Bool, String)] = [
            (nil, false, "Unknown"), (nil, true, "Unknown"),
            (0, false, "0 bytes"), (1, false, "1 byte"), (999, false, "999 bytes"),
            (1_000, false, "1 KB"), (1_500, false, "2 KB"), (999_999, false, "1 MB"),
            (1_234_567, false, "1.2 MB"), (99_940_000, false, "99.9 MB"), (99_960_000, false, "100 MB"),
            (123_456_789, false, "123 MB"), (62_300_000_000, false, "62.3 GB"),
            (1_200_000_000, true, "At least 1.2 GB"), (5_000_000_000_000_000, false, "5000 TB"),
        ]
        for (bytes, lower, expected) in cases {
            XCTAssertEqual(ByteFormat.string(bytes, lowerBound: lower), expected)
        }
    }

    func testShellQuote() {
        XCTAssertEqual(ShellQuote.quote("/Users/jane/a b.txt"), "'/Users/jane/a b.txt'")
        XCTAssertEqual(ShellQuote.quote("it's"), "'it'\\''s'")
    }

    func testGroupedNumbers() {
        XCTAssertEqual([0, 999, 1_000, 4_213, 1_234_567, -12_000].map(grouped), ["0", "999", "1,000", "4,213", "1,234,567", "-12,000"])
    }

    func testCSVQuotesPerRFC4180() {
        let items = [
            ItemRecord(path: cloud + "/Work/a,\"b\".txt", root: .iCloudDrive, relativePath: "Work/a,\"b\".txt",
                       modified: now, isUploaded: true),
            ItemRecord(path: home + "/Desktop/line\nbreak.txt", root: .desktop, relativePath: "line\nbreak.txt",
                       logicalSize: 42, isUploaded: false),
        ]
        let expected = [
            "Name,Folder,Size bytes,Status,Modified ISO8601,Path",
            "\"a,\"\"b\"\".txt\",iCloud Drive › Work,,Synced,2026-09-21T14:13:20Z,\"\(cloud)/Work/a,\"\"b\"\".txt\"",
            "\"line\nbreak.txt\",Desktop,42,Waiting to upload,,\"\(home)/Desktop/line\nbreak.txt\"",
        ].map { $0 + "\r\n" }.joined()
        XCTAssertEqual(CSVExport.render(items), expected)
        XCTAssertEqual(CSVExport.render([]), "Name,Folder,Size bytes,Status,Modified ISO8601,Path\r\n")
        // A name a spreadsheet would run as a formula gets a leading ' (and quotes); one merely containing = doesn't.
        let formula = ItemRecord(path: cloud + "/=HYPERLINK(\"x\").txt", root: .iCloudDrive, relativePath: "=HYPERLINK(\"x\").txt")
        XCTAssertTrue(CSVExport.render([formula]).contains("\r\n\"'=HYPERLINK(\"\"x\"\").txt\","))
        XCTAssertEqual(["-1", "+1", "@a", "\tx", "a=b"].map(CSVExport.field), ["\"'-1\"", "\"'+1\"", "\"'@a\"", "\"'\tx\"", "a=b"])
    }

    func testDiagnosisTextRedactsHomeAndMacName() {
        var items = (1...60).map { item("Finance/f\($0).txt", uploaded: false) }
        items.append(item("lock.txt", flags: BSDFlags.ufAppend))
        let d = classify(items, relocated: [home + "/Desktop - Jane’s MacBook Air"])
        let byPath = Dictionary(uniqueKeysWithValues: items.map { ($0.path, $0) })
        let text = DiagnosisText.render(d, items: byPath, os: OSVersion(26, 4, 1), home: home)

        XCTAssertFalse(text.contains(home))
        XCTAssertFalse(text.lowercased().contains("jane"))
        XCTAssertTrue(text.contains("macOS 26.4.1"))
        XCTAssertTrue(text.contains("Verdict: Worth a look"))
        XCTAssertTrue(text.contains("61 items checked"))
        XCTAssertTrue(text.contains("[Worth a look] 60 items (60 KB) exist only on this Mac"))
        XCTAssertTrue(text.contains("  1. Don't sign out"))
        XCTAssertTrue(text.contains("  iCloud Drive/Finance/f50.txt"))
        XCTAssertFalse(text.contains("f51.txt"))
        XCTAssertTrue(text.contains("  …and 10 more"))
        XCTAssertTrue(text.contains("  chflags nouchg,nouappnd ~/'Library/Mobile Documents/com~apple~CloudDocs/lock.txt'"))
        XCTAssertTrue(text.contains("  ~/Desktop - …"))
    }

    func testDiagnosisTextAllClear() {
        let text = DiagnosisText.render(classify([item("a.txt")]), items: [:], os: OSVersion(15, 6), home: home)
        XCTAssertTrue(text.contains("Verdict: No problems found"))
        XCTAssertTrue(text.contains("1 item checked · 0 findings need attention · 0 items with no sync status from macOS"))
        XCTAssertTrue(text.contains("macOS 15.6"))
    }
}

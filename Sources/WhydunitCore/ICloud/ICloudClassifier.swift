import Foundation

/// Plain-English sync state of one item, shown in the Status column.
public enum ItemStatus: CaseIterable, Sendable {
    case waitingToUpload, uploading, uploadFailed, onlyInICloud, synced, notSyncedByDesign, hasConflicts, unknown

    public var label: String {
        switch self {
        case .waitingToUpload: "Waiting to upload"
        case .uploading: "Uploading"
        case .uploadFailed: "Upload failed"
        case .onlyInICloud: "Only in iCloud"
        case .synced: "Synced"
        case .notSyncedByDesign: "Not synced by design"
        case .hasConflicts: "Has conflicts"
        case .unknown: "Unknown"
        }
    }
}

/// The v1 iCloud Drive rules (docs/BUILD_PLAN.md §2). Pure: time and system state come in through `ScanContext`.
public enum ICloudClassifier {
    static let tooLargeBytes: Int64 = 50_000_000_000  // Apple's per-item limit ("Ineligible" in Finder)
    static let developerFolderLimit = 5_000

    public static func classify(_ items: [ItemRecord], context: ScanContext) -> Diagnosis {
        let live = items.filter { !isExcluded($0) }
        // Sync-state rules look at files and packages; a plain folder's own state adds nothing but double counts.
        let files = live.filter(isFileLike)
        var findings: [Finding] = []

        // I16: nil counts as "maybe only here", never as uploaded.
        let localOnly = files.filter { $0.isUploaded != true && !$0.isDataless }
        if !localOnly.isEmpty {
            let n = localOnly.count, bytes = size(localOnly)
            let unknown = localOnly.filter { $0.isUploaded == nil }.count
            var explanation = "iCloud hasn't confirmed it has a copy of \(pick(n, "this item", "these items")), so this Mac may hold the only one. Signing out, turning off iCloud Drive or resetting sync now could lose \(pick(n, "it", "them"))."
            if unknown > 0 {
                explanation += " macOS didn't report a sync state for \(counted(unknown, "item")), so \(pick(unknown, "it's", "they're")) included to be safe."
            }
            findings.append(Finding(
                rule: .onlyOnThisMac,
                severity: localOnly.contains { isOld($0, context) } ? .warning : .info,
                title: "\(counted(n, "item"))\(sizeNote(bytes)) \(pick(n, "exists", "exist")) only on this Mac",
                explanation: explanation,
                steps: [
                    "Don't sign out of iCloud, turn off iCloud Drive or reset anything yet.",
                    "Back up \(pick(n, "this item", "these items")) to a folder outside iCloud.",
                    "Scan again later to check whether iCloud has caught up.",
                ],
                itemPaths: localOnly.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower,
                primaryAction: .backUp))
        }

        // I10: only when the probe proved iCloud itself is uploading.
        if case .uploaded = context.probe {
            let stuck = files.filter {
                $0.isUploaded == false && $0.isUploading != true && $0.uploadingError == nil
                    && $0.hasUnresolvedConflicts != true && !$0.isDataless && isOld($0, context)
            }
            if !stuck.isEmpty {
                let n = stuck.count, bytes = size(stuck)
                findings.append(Finding(
                    rule: .stuckItems, severity: .warning,
                    title: "\(counted(n, "file")) \(pick(n, "hasn't", "haven't")) uploaded to iCloud\(sizeNote(bytes))",
                    explanation: "A test file uploaded normally, so iCloud is working, but \(pick(n, "this file hasn't", "these files haven't")) uploaded in over \(duration(context.stuckAge)) and macOS reports no error. \(pick(n, "It's", "They're")) still safe on this Mac.",
                    steps: [
                        "If a file is open in an app, close it and scan again.",
                        "Back up \(pick(n, "the file", "the files")) first.",
                        "Use Retry Upload to move each file out of iCloud Drive and back, one at a time.",
                        "If \(pick(n, "it still doesn't", "they still don't")) upload, restart your Mac and scan again.",
                    ],
                    itemPaths: stuck.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower,
                    primaryAction: .retryUpload))
            }
        }

        // I11: an explicit "not uploaded" for the whole wait, and nothing else uploading (then iCloud is only busy).
        // `.unknown` never gets here.
        if case .notUploaded(let waited) = context.probe, !files.contains(where: { $0.isUploading == true }) {
            findings.append(Finding(
                rule: .syncStalled, severity: .critical,
                title: "iCloud Drive sync looks stalled on this Mac",
                explanation: "A small test file waited \(duration(waited)) without uploading, so the problem is iCloud sync as a whole, not your files. Don't move, rename or retry individual files yet. Restarting iCloud sync usually gets it moving again.",
                steps: [
                    "Check that this Mac is online and signed in to iCloud.",
                    "Restart iCloud Sync, wait a few minutes, then scan again.",
                    "If it's still stalled, restart your Mac and scan again.",
                    "If it keeps happening, copy the diagnosis and contact Apple Support.",
                ],
                primaryAction: .restartSync))
        }

        // I1
        let full = live.filter { errorKind($0) == .quota }
        if !full.isEmpty {
            let n = full.count, bytes = size(full)
            findings.append(Finding(
                rule: .storageFull, severity: .critical,
                title: "iCloud storage is full, so \(counted(n, "item")) can't upload\(sizeNote(bytes))",
                explanation: "macOS reports that your iCloud storage has no room left. New and changed files stay on this Mac and won't upload until there's space.",
                steps: [
                    "Open iCloud settings to see what's using your storage.",
                    "Free up iCloud storage, or choose a bigger plan.",
                    "Scan again once there's room.",
                ],
                itemPaths: full.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower,
                primaryAction: .openICloudSettings))
        }

        // I2
        let offline = live.filter { errorKind($0) == .serverUnreachable }
        if !offline.isEmpty {
            let n = offline.count, bytes = size(offline)
            findings.append(Finding(
                rule: .serverUnreachable, severity: .warning,
                title: "iCloud couldn't be reached for \(counted(n, "item"))\(sizeNote(bytes))",
                explanation: "macOS couldn't reach Apple's iCloud servers when uploading \(pick(n, "this item", "these items")). \(pick(n, "It's", "They're")) safe on this Mac and should upload once the connection is back.",
                steps: [
                    "Check that this Mac is online by opening a website.",
                    "If you use a VPN, firewall or content filter, pause it and scan again.",
                    "Check Apple's System Status page for iCloud Drive.",
                ],
                itemPaths: offline.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower))
        }

        // I4: every other upload error.
        let rejected = live.filter { errorKind($0) == .other }
        if !rejected.isEmpty {
            let n = rejected.count, bytes = size(rejected)
            let reasons = rejected.map { $0.uploadingError.flatMap(ErrorCatalog.reason) }
            let reason = reasons.allSatisfy { $0 == reasons[0] } ? reasons[0] : nil
            findings.append(Finding(
                rule: .uploadRejected, severity: .warning,
                title: "\(counted(n, "item")) couldn't upload\(reason.map { ": \($0)" } ?? " to iCloud")\(sizeNote(bytes))",
                explanation: "macOS reported an upload error for \(pick(n, "this item", "these items")), so iCloud doesn't have \(pick(n, "its", "their")) latest version. \(pick(n, "It's", "They're")) still on this Mac. The exact error is in the technical details.",
                steps: [
                    "Back up \(pick(n, "this item", "these items")) first.",
                    "Use Retry Upload to move each item out of iCloud Drive and back, one at a time.",
                    "If an item still won't upload, copy the diagnosis and contact Apple Support.",
                ],
                itemPaths: rejected.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower,
                primaryAction: .retryUpload))
        }

        // I5: uchg alone is stripped silently, so only these three block sync (Oakley 2026-06-02).
        let blocking = BSDFlags.ufAppend | BSDFlags.sfImmutable | BSDFlags.sfAppend
        let locked = live.filter { ($0.bsdFlags ?? 0) & blocking != 0 }
        if !locked.isEmpty {
            let n = locked.count
            let system = BSDFlags.sfImmutable | BSDFlags.sfAppend
            let needsRoot = locked.filter { ($0.bsdFlags ?? 0) & system != 0 }
            let userOnly = locked.filter { ($0.bsdFlags ?? 0) & system == 0 }
            func paths(_ items: [ItemRecord]) -> String { items.map { ShellQuote.quote($0.path) }.joined(separator: " ") }
            // ponytail: one line per group, however many paths; split into batches if ARG_MAX ever bites.
            var lines: [String] = []
            if !userOnly.isEmpty { lines.append("chflags nouchg,nouappnd \(paths(userOnly))") }
            if !needsRoot.isEmpty { lines.append("sudo chflags noschg,nosappnd,nouchg,nouappnd \(paths(needsRoot))") }
            findings.append(Finding(
                rule: .lockFlags, severity: .warning,
                title: "\(counted(n, "item")) \(pick(n, "has a lock flag that blocks", "have lock flags that block")) iCloud sync",
                explanation: "\(pick(n, "This item carries", "These items carry")) a file flag, such as append-only, that stops iCloud Drive from syncing \(pick(n, "it", "them")). The fix is a Terminal command you run yourself; this app never changes file flags.",
                steps: [
                    "Copy the command.",
                    "Paste it into Terminal and press Return. A command that starts with sudo asks for your Mac password.",
                    "Scan again.",
                ],
                itemPaths: locked.map(\.path), primaryAction: .copyCommand, command: lines.joined(separator: "\n")))
        }

        // I6
        let huge = files.filter { ($0.logicalSize ?? 0) > tooLargeBytes }
        if !huge.isEmpty {
            let n = huge.count, bytes = size(huge)
            findings.append(Finding(
                rule: .tooLarge, severity: .warning,
                title: "\(counted(n, "file")) \(pick(n, "is", "are")) too large for iCloud\(sizeNote(bytes))",
                explanation: "iCloud Drive doesn't sync any single item larger than 50 GB, and Finder shows \(pick(n, "it", "them")) as Ineligible. \(pick(n, "It stays", "They stay")) on this Mac only.",
                steps: [
                    "Move \(pick(n, "it", "them")) to a folder or drive that isn't in iCloud Drive.",
                    "Or split \(pick(n, "it", "them")) into parts smaller than 50 GB.",
                ],
                itemPaths: huge.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower,
                primaryAction: .showInFinder))
        }

        // I8
        let conflicted = live.filter { $0.hasUnresolvedConflicts == true }
        if !conflicted.isEmpty {
            let n = conflicted.count, bytes = size(conflicted)
            findings.append(Finding(
                rule: .conflicts, severity: .warning,
                title: "\(counted(n, "item")) \(pick(n, "has", "have")) conflicting versions",
                explanation: "\(pick(n, "This item was", "These items were")) changed on more than one device before syncing, so iCloud kept more than one version. When you pick the version to keep, the others are deleted everywhere.",
                steps: [
                    "Back up anything you might need first.",
                    "Open each item and choose the version to keep when asked.",
                    "Scan again.",
                ],
                itemPaths: conflicted.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower,
                primaryAction: .showInFinder))
        }

        // I13: can't prove debt without a free-space reading, and unknown sizes only make the sum a lower bound.
        let dataless = live.filter(\.isDataless)
        let datalessFiles = dataless.filter(isFileLike)
        var debt = size(datalessFiles)
        if dataless.count > datalessFiles.count { debt.lower = true }  // a dataless folder hides more
        if let free = context.freeBytes, let total = debt.total, total > free {
            let n = datalessFiles.count
            findings.append(Finding(
                rule: .storageDebt, severity: .warning,
                title: "iCloud-only files need \(debt.lower ? "at least " : "")\(ByteFormat.string(total)); only \(ByteFormat.string(free)) is free",
                explanation: "\(counted(n, "file")) \(pick(n, "is", "are")) stored in iCloud and not downloaded to this Mac. Turning off Optimize Mac Storage would try to download \(pick(n, "it", "all of them")), and there isn't room. Leave it on until you free up space.",
                steps: [
                    "Leave Optimize Mac Storage turned on.",
                    "Free up space on this Mac before downloading large folders.",
                ],
                itemPaths: datalessFiles.map(\.path), totalBytes: total, bytesIsLowerBound: debt.lower))
        }

        // I14: report only the outermost folder; nested node_modules add nothing.
        let busy = live.filter { $0.isDirectory && ($0.descendantCount ?? 0) > developerFolderLimit }
        let developer = busy.filter { folder in !busy.contains { folder.path.hasPrefix($0.path + "/") } }
        if !developer.isEmpty {
            let n = developer.count
            findings.append(Finding(
                rule: .developerFolders, severity: .info,
                title: "\(counted(n, "developer folder")) in iCloud Drive \(pick(n, "holds", "hold")) thousands of files",
                explanation: "Folders like node_modules and .git change thousands of small files at once, which can keep iCloud busy for hours. Keeping projects outside iCloud Drive usually helps.",
                steps: [
                    "Move the project to a folder that isn't in iCloud Drive, such as a Developer folder in your home folder.",
                    "Scan again once it's moved.",
                ],
                itemPaths: developer.map(\.path), primaryAction: .showInFinder))
        }

        // I15
        let relocated = context.relocatedFolders + live.filter { $0.isDirectory && isSecondMacFolder($0) }.map(\.path)
        if !relocated.isEmpty {
            let n = relocated.count
            findings.append(Finding(
                rule: .relocatedFiles, severity: .info,
                title: "\(pick(n, "A folder", "\(n) folders")) may hold files moved by macOS",
                explanation: "macOS moves files into folders like “iCloud Drive (Archive)” or “Relocated Items” when iCloud Drive is turned off, Desktop & Documents syncing changes, or an update runs. When Desktop & Documents is turned on for a second Mac, its files go in a folder named after that Mac inside iCloud Drive's Desktop or Documents folder. Anything you're missing may be there.",
                steps: [
                    "Open \(pick(n, "the folder", "each folder")) in Finder and look for files you're missing.",
                    "Copy back anything you need. The folder itself is safe to keep.",
                ],
                itemPaths: relocated, primaryAction: .showInFinder))
        }

        // I7: list what the user named or placed on purpose, not hidden clutter like .DS_Store.
        let excluded = items.filter(isExcluded)
        let shown = excluded.filter { !excludedByAncestor($0) && !isClutter($0.name) }
        if !shown.isEmpty {
            let n = shown.count
            let roots = Set(shown.map(\.path))
            let inside = excluded.filter {
                var p = $0.path
                while p.count > 1 {
                    if roots.contains(p) { return true }
                    p = (p as NSString).deletingLastPathComponent
                }
                return false
            }
            let bytes = size(inside)
            findings.append(Finding(
                rule: .excludedByDesign, severity: .info,
                title: "\(counted(n, "item")) \(pick(n, "isn't", "aren't")) synced by design\(sizeNote(bytes))",
                explanation: "iCloud Drive never syncs names ending in .nosync or .tmp, or a few special folders such as photo libraries. \(pick(n, "This item stays", "These items stay")) on this Mac on purpose and \(pick(n, "isn't", "aren't")) stuck.",
                steps: [
                    "Nothing needs fixing.",
                    "To sync an item, remove .nosync or .tmp from the end of its name, or of the folder it's in.",
                ],
                itemPaths: shown.map(\.path), totalBytes: bytes.total, bytesIsLowerBound: bytes.lower))
        }

        // Folders whose contents we never saw. A dataless folder has nothing local to hide, so it isn't one.
        let unreadable = live.filter { $0.listingFailed && !$0.isDataless }
        if !unreadable.isEmpty {
            let n = unreadable.count
            findings.append(Finding(
                rule: .unreadableFolders, severity: .unknown,
                title: "\(counted(n, "folder")) couldn't be checked",
                explanation: "macOS didn't let \(pick(n, "this folder", "these folders")) be listed, usually because \(pick(n, "it needs", "they need")) permission. Files inside \(pick(n, "it", "them")) weren't checked.",
                steps: [
                    "Open \(pick(n, "the folder", "each folder")) in Finder so macOS can list its contents.",
                    "Scan again.",
                ],
                itemPaths: unreadable.map(\.path), primaryAction: .showInFinder))
        }

        // Whole roots we couldn't read.
        if !context.deniedRoots.isEmpty {
            let names = listed(context.deniedRoots.map(\.displayName))
            let n = context.deniedRoots.count
            findings.append(Finding(
                rule: .permissionDenied, severity: .warning,
                title: "\(names) couldn't be checked",
                explanation: "macOS hasn't given this app permission to read \(pick(n, "this folder", "these folders")), so files in \(pick(n, "it", "them")) weren't checked. The scan reads file status only, never file contents.",
                steps: [
                    "Open Privacy Settings.",
                    "Under Files & Folders, allow this app to use \(names).",
                    "If it isn't listed there, add this app under Full Disk Access.",
                    "Scan again.",
                ],
                primaryAction: .openPrivacySettings))
        }

        findings.sort { $0.severity != $1.severity ? $0.severity > $1.severity : rank($0.rule) < rank($1.rule) }
        let unknown = files.filter { $0.isUploaded == nil && !$0.isDataless }.count
        return Diagnosis(findings: findings, checkedCount: items.count, unknownCount: unknown, scannedAt: context.now)
    }

    /// Plain words for the Status column.
    public static func status(of item: ItemRecord) -> ItemStatus {
        if isExcluded(item) { return .notSyncedByDesign }
        if item.hasUnresolvedConflicts == true { return .hasConflicts }
        if item.uploadingError != nil { return .uploadFailed }
        if item.isDataless { return .onlyInICloud }
        if item.isUploading == true { return .uploading }
        if item.isUploaded == true { return .synced }
        if item.isUploaded == false { return .waitingToUpload }
        return .unknown
    }

    /// Rows that start selected: settled for 10 minutes, content on this Mac, and a folder we could list.
    public static func isSafeToPreselect(_ item: ItemRecord, now: Date) -> Bool {
        guard let modified = item.modified, now.timeIntervalSince(modified) >= 10 * 60 else { return false }
        return !item.isDataless && !(item.isDirectory && item.listingFailed)
    }

    // MARK: - Exclusions (I7)

    // Howard Oakley, "Exclude or include items in backup, search, iCloud Drive and QuickLook preview",
    // eclecticlight.co, 2026-01-06 (docs/research/tech-icloud.md §1.4, competitors-icloud.md).
    // ponytail: his "~ with an extension of 3+ characters" rule is ambiguous and left out; such items show as unsynced.
    // VERIFY: iCloud's matching may be case-sensitive; we compare lowercased.
    static let excludedSuffixes = [
        ".nosync", ".tmp", ".photoslibrary", ".photolibrary", ".aplibrary",
        ".migratedaplibrary", ".migratedphotolibrary", ".migratedaperturelibrary",
    ]
    static let excludedNames: Set = ["iphoto library", "photos library", "dropbox", ".dropbox", ".dropbox.attr", "microsoft user data"]
    static let clutterNames: Set = [".ds_store", "desktop.ini", "$recycle.bin", "icon\r"]

    /// Hidden system files iCloud skips; excluded like the rest but not worth listing.
    static func isClutter(_ name: String) -> Bool {
        let n = name.lowercased()
        return clutterNames.contains(n) || n.hasPrefix("~$") || n.hasPrefix("(a document being saved")
            || n.hasSuffix(".ubd") || n.contains(".weakpkg")
    }

    public static func isExcludedName(_ name: String) -> Bool {
        let n = name.lowercased()
        return isClutter(n) || excludedNames.contains(n) || excludedSuffixes.contains { n.hasSuffix($0) }
    }

    /// Excluded by its own name, by an enclosing folder's name, or because macOS says so.
    static func isExcluded(_ item: ItemRecord) -> Bool {
        item.isExcludedFromSync == true || item.relativePath.split(separator: "/").contains { isExcludedName(String($0)) }
    }

    static func excludedByAncestor(_ item: ItemRecord) -> Bool {
        item.relativePath.split(separator: "/").dropLast().contains { isExcludedName(String($0)) }
    }

    // MARK: - Helpers

    /// Another Mac's Desktop & Documents folder, e.g. "Desktop - Jane's MacBook", inside iCloud Drive's Desktop or
    /// Documents folder (seen through ~/Desktop and ~/Documents when this Mac syncs them too).
    static func isSecondMacFolder(_ item: ItemRecord) -> Bool {
        let parts = item.relativePath.split(separator: "/").map(String.init)
        switch (item.root, parts.count) {
        case (.desktop, 1): return parts[0].hasPrefix("Desktop - ")
        case (.documents, 1): return parts[0].hasPrefix("Documents - ")
        case (.iCloudDrive, 2): return ["Desktop", "Documents"].contains(parts[0]) && parts[1].hasPrefix(parts[0] + " - ")
        default: return false
        }
    }

    static func isFileLike(_ item: ItemRecord) -> Bool { !item.isDirectory || item.isPackage }

    /// Waiting since the later of the last edit and the arrival in place. Unknown modification date is not "old":
    /// we don't claim what we can't show.
    static func isOld(_ item: ItemRecord, _ context: ScanContext) -> Bool {
        guard let modified = item.modified else { return false }
        return context.now.timeIntervalSince(max(modified, item.inPlaceSince ?? modified)) > context.stuckAge
    }

    static func errorKind(_ item: ItemRecord) -> ErrorCatalog.Kind? { item.uploadingError.map(ErrorCatalog.kind) }

    /// Sum of known logical sizes of files and packages; `lower` when some sizes were unknown.
    static func size(_ items: [ItemRecord]) -> (total: Int64?, lower: Bool) {
        // The scanner doesn't list inside a folder excluded by name; its walked size stands for its contents.
        let sized = items.filter { isFileLike($0) || ($0.isDirectory && isExcludedName($0.name)) }
        let known = sized.compactMap(\.logicalSize)
        guard !known.isEmpty else { return (nil, false) }
        return (known.reduce(0, +), known.count < sized.count)
    }

    static func rank(_ rule: RuleID) -> Int { RuleID.allCases.firstIndex(of: rule) ?? 0 }
}

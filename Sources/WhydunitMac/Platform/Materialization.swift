import Darwin

/// Stops this process from downloading ("materializing") dataless iCloud files, so no scan or
/// metadata read can pull content down from iCloud. Reading a dataless file then fails with
/// EDEADLK instead (TN3150).
public enum Materialization {
    // Values from <sys/resource.h>, spelled out so we don't depend on how the C macros import.
    private static let typeMaterializeDatalessFiles: Int32 = 3 // IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES
    private static let scopeProcess: Int32 = 0                 // IOPOL_SCOPE_PROCESS
    private static let materializeOff: Int32 = 1               // IOPOL_MATERIALIZE_DATALESS_FILES_OFF
    private static let scopeThread: Int32 = 1                  // IOPOL_SCOPE_THREAD
    private static let materializeOn: Int32 = 2                // IOPOL_MATERIALIZE_DATALESS_FILES_ON

    @discardableResult
    public static func disableForProcess() -> Bool {
        setiopolicy_np(typeMaterializeDatalessFiles, scopeProcess, materializeOff) == 0
    }

    /// Runs `body` with materialization allowed on this thread only (a thread setting overrides the process one;
    /// xnu vfs_context_dataless_materialization_is_prevented), for user-chosen destinations such as an exported CSV.
    /// Never call it from scanner or probe code, or around a read of an item's content; recoverStaged uses it only to
    /// reach an evicted folder when putting an item back.
    public static func allowingOnThisThread<T>(_ body: () throws -> T) rethrows -> T {
        let old = getiopolicy_np(typeMaterializeDatalessFiles, scopeThread)
        _ = setiopolicy_np(typeMaterializeDatalessFiles, scopeThread, materializeOn)
        defer { _ = setiopolicy_np(typeMaterializeDatalessFiles, scopeThread, old >= 0 ? old : 0) }  // 0 = DEFAULT, back to the process policy
        return try body()
    }
}

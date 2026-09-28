/// Plain meaning of the upload errors macOS reports through `ubiquitousItemUploadingError`.
/// Codes: docs/research/tech-icloud.md §6 and the `NSFileProviderError.Code` raw values in the FileProvider headers.
public enum ErrorCatalog {
    enum Kind { case quota, serverUnreachable, other }

    // VERIFY: that iCloud Drive reports these top-level domains rather than wrapping them in NSUnderlyingError.
    static func kind(of error: ItemError) -> Kind {
        switch (error.domain, error.code) {
        // NSUbiquitousFileNotUploadedDueToQuotaError, NSFileProviderError.insufficientQuota
        case ("NSCocoaErrorDomain", 4354), ("NSFileProviderErrorDomain", -1003): .quota
        // NSUbiquitousFileUbiquityServerNotAvailable, NSFileProviderError.serverUnreachable
        case ("NSCocoaErrorDomain", 4355), ("NSFileProviderErrorDomain", -1004): .serverUnreachable
        default: .other
        }
    }

    /// Short reason that reads after "couldn't upload: ", or nil when the code isn't one we know.
    public static func reason(for error: ItemError) -> String? {
        switch (error.domain, error.code) {
        case ("NSCocoaErrorDomain", 4354), ("NSFileProviderErrorDomain", -1003): "iCloud storage is full"
        case ("NSCocoaErrorDomain", 4355), ("NSFileProviderErrorDomain", -1004): "iCloud can't be reached"
        case ("NSCocoaErrorDomain", 4353): "not available in iCloud"          // NSUbiquitousFileUnavailableError
        case ("NSFileProviderErrorDomain", -1000): "not signed in to iCloud"   // notAuthenticated
        case ("NSFileProviderErrorDomain", -1001): "name already in use"       // filenameCollision
        case ("NSFileProviderErrorDomain", -2005): "rejected by iCloud"        // cannotSynchronize (DTS-confirmed)
        case ("NSFileProviderErrorDomain", -2010): "excluded from sync"        // VERIFY: excludedFromSync raw value is not in our sources
        case ("NSFileProviderErrorDomain", -2011): "iCloud Drive is turned off" // domainDisabled
        case ("NSFileProviderErrorDomain", -2012): "iCloud Drive is busy"      // providerDomainTemporarilyUnavailable
        case ("NSFileProviderErrorDomain", -2015): "iCloud has a different copy" // localVersionConflictingWithServer
        default: nil
        }
    }
}

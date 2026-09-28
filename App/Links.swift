import Foundation

/// The website's pages, on GitHub Pages (BUILD_PLAN §10.2).
/// tools/doctor.sh checks `website` matches site/site.json's baseURL and Info.plist's SUFeedURL.
enum Links {
    static let website = URL(string: "https://everydayopen.github.io/whydunit")!
    static let privacy = website.appending(path: "privacy/")
    static let terms = website.appending(path: "terms/")
    /// GitHub Issues and Copy Diagnosis; "Whydunit Help" opens it.
    static let support = website.appending(path: "support/")
    static let changelog = website.appending(path: "changelog/")
}

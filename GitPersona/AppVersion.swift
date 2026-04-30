import Foundation

enum AppVersion {
    /// CFBundleShortVersionString — semver shown to users.
    static var marketingVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    /// CFBundleVersion — build number from Xcode.
    static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }

    static var fullDescription: String {
        "\(marketingVersion) (\(buildNumber))"
    }
}

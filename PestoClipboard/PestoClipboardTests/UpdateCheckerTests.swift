import Testing
import Foundation
@testable import Pesto_Clipboard

@MainActor
struct UpdateCheckerTests {

    init() {
        // Clear any persisted state that might affect tests
        UserDefaults.standard.removeObject(forKey: "dismissedUpdateVersion")
        UserDefaults.standard.removeObject(forKey: "lastUpdateCheck")
    }

    // MARK: - Version Comparison Tests

    @Test func newerMajorVersion() {
        let checker = UpdateChecker(testVersion: "1.0.0")
        #expect(checker.isNewerVersion("2.0.0", than: "1.0.0"))
    }

    @Test func newerMinorVersion() {
        let checker = UpdateChecker(testVersion: "1.0.0")
        #expect(checker.isNewerVersion("1.1.0", than: "1.0.0"))
    }

    @Test func newerPatchVersion() {
        let checker = UpdateChecker(testVersion: "1.0.0")
        #expect(checker.isNewerVersion("1.0.1", than: "1.0.0"))
    }

    @Test func sameVersionNotNewer() {
        let checker = UpdateChecker(testVersion: "1.0.0")
        #expect(!checker.isNewerVersion("1.0.0", than: "1.0.0"))
    }

    @Test func olderVersionNotNewer() {
        let checker = UpdateChecker(testVersion: "2.0.0")
        #expect(!checker.isNewerVersion("1.0.0", than: "2.0.0"))
    }

    @Test func olderMinorVersionNotNewer() {
        let checker = UpdateChecker(testVersion: "1.5.0")
        #expect(!checker.isNewerVersion("1.4.0", than: "1.5.0"))
    }

    @Test func differentLengthVersions() {
        let checker = UpdateChecker(testVersion: "1.0")
        #expect(checker.isNewerVersion("1.0.1", than: "1.0"))
        #expect(checker.isNewerVersion("1.0.1", than: "1.0.0"))
    }

    @Test func versionWithExtraComponents() {
        let checker = UpdateChecker(testVersion: "1.0.0.0")
        #expect(checker.isNewerVersion("1.0.0.1", than: "1.0.0.0"))
    }

    // MARK: - Nightly Build Detection Tests

    @Test func nightlyVersionDetected() {
        let checker = UpdateChecker(testVersion: "1.0.0-nightly")
        #expect(checker.isNightlyBuild)
    }

    @Test func alphaVersionDetected() {
        let checker = UpdateChecker(testVersion: "1.0.0-alpha")
        #expect(checker.isNightlyBuild)
    }

    @Test func betaVersionDetected() {
        let checker = UpdateChecker(testVersion: "1.0.0-beta")
        #expect(checker.isNightlyBuild)
    }

    @Test func dateStampVersionDetected() {
        let checker = UpdateChecker(testVersion: "1.0.0-20240115")
        #expect(checker.isNightlyBuild)
    }

    @Test func stableVersionNotNightly() {
        let checker = UpdateChecker(testVersion: "1.0.0")
        #expect(!checker.isNightlyBuild)
    }

    @Test func stableVersionWithDotsNotNightly() {
        let checker = UpdateChecker(testVersion: "1.2.3")
        #expect(!checker.isNightlyBuild)
    }

    // MARK: - Install Source Tests

    @Test func installSourceRawValues() {
        #expect(InstallSource.appStore.rawValue == "App Store")
        #expect(InstallSource.homebrew.rawValue == "Homebrew")
        #expect(InstallSource.direct.rawValue == "Direct Download")
    }

    @Test func installSourceLocalizedNames() {
        // Just verify they exist and are non-empty
        #expect(!InstallSource.appStore.localizedName.isEmpty)
        #expect(!InstallSource.homebrew.localizedName.isEmpty)
        #expect(!InstallSource.direct.localizedName.isEmpty)
    }

    // MARK: - Update Checking Enabled Tests

    @Test func updateCheckingEnabledForDirectStable() {
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .direct)
        #expect(checker.updateCheckingEnabled)
    }

    @Test func updateCheckingDisabledForNightly() {
        let checker = UpdateChecker(testVersion: "1.0.0-nightly", installSource: .direct)
        #expect(!checker.updateCheckingEnabled)
    }

    @Test func updateCheckingDisabledForAppStore() {
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .appStore)
        #expect(!checker.updateCheckingEnabled)
    }

    @Test func updateCheckingEnabledForHomebrew() {
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .homebrew)
        #expect(checker.updateCheckingEnabled)
    }

    @Test func updateCheckingDisabledForHomebrewNightly() {
        let checker = UpdateChecker(testVersion: "1.0.0-nightly", installSource: .homebrew)
        #expect(!checker.updateCheckingEnabled)
    }

    // MARK: - Process Release Tests

    @Test func processReleaseWithNewerVersion() {
        UserDefaults.standard.removeObject(forKey: "dismissedUpdateVersion")
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "v2.0.0",
            name: "Version 2.0.0",
            body: "New features!",
            htmlURL: "https://github.com/test/test/releases/tag/v2.0.0",
            publishedAt: "2024-01-15T12:00:00Z",
            prerelease: false,
            assets: [
                GitHubAsset(name: "App.dmg", browserDownloadURL: "https://example.com/App.dmg")
            ]
        )

        checker.processRelease(release)

        #expect(checker.updateAvailable)
        #expect(checker.availableUpdate?.version == "2.0.0")
        #expect(checker.availableUpdate?.releaseNotes == "New features!")
        #expect(checker.availableUpdate?.downloadURL?.absoluteString == "https://example.com/App.dmg")
        #expect(checker.availableUpdate?.isNightly == false)
    }

    @Test func processReleaseWithOlderVersion() {
        let checker = UpdateChecker(testVersion: "3.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "v2.0.0",
            name: "Version 2.0.0",
            body: "Old version",
            htmlURL: "https://github.com/test/test/releases/tag/v2.0.0",
            publishedAt: nil,
            prerelease: false,
            assets: []
        )

        checker.processRelease(release)

        #expect(!checker.updateAvailable)
        #expect(checker.availableUpdate == nil)
    }

    @Test func processReleaseWithSameVersion() {
        let checker = UpdateChecker(testVersion: "2.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "v2.0.0",
            name: "Version 2.0.0",
            body: "Same version",
            htmlURL: "https://github.com/test/test/releases/tag/v2.0.0",
            publishedAt: nil,
            prerelease: false,
            assets: []
        )

        checker.processRelease(release)

        #expect(!checker.updateAvailable)
        #expect(checker.availableUpdate == nil)
    }

    @Test func processReleasePrerelease() {
        UserDefaults.standard.removeObject(forKey: "dismissedUpdateVersion")
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "v2.0.0-beta",
            name: "Version 2.0.0 Beta",
            body: "Beta release",
            htmlURL: "https://github.com/test/test/releases/tag/v2.0.0-beta",
            publishedAt: nil,
            prerelease: true,
            assets: []
        )

        checker.processRelease(release)

        #expect(checker.updateAvailable)
        #expect(checker.availableUpdate?.isNightly == true)
    }

    @Test func processReleaseStripsVersionPrefix() {
        UserDefaults.standard.removeObject(forKey: "dismissedUpdateVersion")
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "V2.0.0",  // uppercase V
            name: "Version 2.0.0",
            body: nil,
            htmlURL: "https://github.com/test/test/releases/tag/V2.0.0",
            publishedAt: nil,
            prerelease: false,
            assets: []
        )

        checker.processRelease(release)

        #expect(checker.updateAvailable)
        #expect(checker.availableUpdate?.version == "2.0.0")
    }

    @Test func processReleaseFallsBackToHtmlURL() {
        UserDefaults.standard.removeObject(forKey: "dismissedUpdateVersion")
        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "v2.0.0",
            name: "Version 2.0.0",
            body: nil,
            htmlURL: "https://github.com/test/test/releases/tag/v2.0.0",
            publishedAt: nil,
            prerelease: false,
            assets: []  // No DMG asset
        )

        checker.processRelease(release)

        #expect(checker.updateAvailable)
        #expect(checker.availableUpdate?.downloadURL?.absoluteString == "https://github.com/test/test/releases/tag/v2.0.0")
    }

    // MARK: - Dismiss Update Tests

    @Test func dismissUpdateClearsState() {
        // Ensure clean state
        UserDefaults.standard.removeObject(forKey: "dismissedUpdateVersion")

        let checker = UpdateChecker(testVersion: "1.0.0", installSource: .direct)

        let release = GitHubRelease(
            tagName: "v2.0.0",
            name: "Version 2.0.0",
            body: "New version",
            htmlURL: "https://github.com/test/test/releases/tag/v2.0.0",
            publishedAt: nil,
            prerelease: false,
            assets: []
        )

        checker.processRelease(release)
        #expect(checker.updateAvailable)

        checker.dismissUpdate()
        #expect(!checker.updateAvailable)
        #expect(checker.availableUpdate == nil)
    }

    // MARK: - UpdateInfo Tests

    @Test func updateInfoEquatable() {
        let info1 = UpdateInfo(
            version: "2.0.0",
            releaseNotes: "Notes",
            downloadURL: URL(string: "https://example.com"),
            publishedAt: nil,
            isNightly: false
        )

        let info2 = UpdateInfo(
            version: "2.0.0",
            releaseNotes: "Notes",
            downloadURL: URL(string: "https://example.com"),
            publishedAt: nil,
            isNightly: false
        )

        let info3 = UpdateInfo(
            version: "3.0.0",
            releaseNotes: "Notes",
            downloadURL: URL(string: "https://example.com"),
            publishedAt: nil,
            isNightly: false
        )

        #expect(info1 == info2)
        #expect(info1 != info3)
    }
}

// MARK: - GitHub API Types Tests

struct GitHubReleaseTests {

    @Test func decodeGitHubRelease() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "name": "Version 1.0.0",
            "body": "Release notes here",
            "html_url": "https://github.com/owner/repo/releases/tag/v1.0.0",
            "published_at": "2024-01-15T10:00:00Z",
            "prerelease": false,
            "assets": [
                {
                    "name": "App.dmg",
                    "browser_download_url": "https://example.com/App.dmg"
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        #expect(release.tagName == "v1.0.0")
        #expect(release.name == "Version 1.0.0")
        #expect(release.body == "Release notes here")
        #expect(release.htmlURL == "https://github.com/owner/repo/releases/tag/v1.0.0")
        #expect(release.publishedAt == "2024-01-15T10:00:00Z")
        #expect(release.prerelease == false)
        #expect(release.assets.count == 1)
        #expect(release.assets[0].name == "App.dmg")
        #expect(release.assets[0].browserDownloadURL == "https://example.com/App.dmg")
    }

    @Test func decodeGitHubReleaseWithNullOptionals() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "name": null,
            "body": null,
            "html_url": "https://github.com/owner/repo/releases/tag/v1.0.0",
            "published_at": null,
            "prerelease": true,
            "assets": []
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        #expect(release.tagName == "v1.0.0")
        #expect(release.name == nil)
        #expect(release.body == nil)
        #expect(release.publishedAt == nil)
        #expect(release.prerelease == true)
        #expect(release.assets.isEmpty)
    }
}

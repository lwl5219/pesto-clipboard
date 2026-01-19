import Foundation
import Combine
import AppKit

/// Represents how the app was installed
enum InstallSource: String {
    case appStore = "App Store"
    case homebrew = "Homebrew"
    case direct = "Direct Download"

    /// Localized display name for the install source
    var localizedName: String {
        switch self {
        case .appStore:
            return String(localized: "Installed via App Store")
        case .homebrew:
            return String(localized: "Installed via Homebrew")
        case .direct:
            return String(localized: "Installed via direct download")
        }
    }

    /// Detect installation source
    static func detect() -> InstallSource {
        // Check for App Store receipt
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receiptURL.path) {
            // Verify it's not a sandbox receipt (used during development)
            if !receiptURL.path.contains("sandboxReceipt") {
                return .appStore
            }
        }

        // Check for Homebrew installation paths
        let appPath = Bundle.main.bundlePath
        let homebrewPaths = [
            "/opt/homebrew/Caskroom",
            "/usr/local/Caskroom",
            "/Applications" // Homebrew cask symlinks here, check for Homebrew marker
        ]

        for path in homebrewPaths {
            if appPath.contains(path) && appPath.contains("Caskroom") {
                return .homebrew
            }
        }

        // Check for Homebrew marker file (created during cask install)
        let homebrewMarker = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent(".homebrew")
        if FileManager.default.fileExists(atPath: homebrewMarker.path) {
            return .homebrew
        }

        return .direct
    }
}

/// Information about an available update
struct UpdateInfo: Equatable {
    let version: String
    let releaseNotes: String?
    let downloadURL: URL?
    let publishedAt: Date?
    let isNightly: Bool
}

/// Checks for app updates from GitHub releases
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    /// Whether an update is available
    @Published private(set) var updateAvailable: Bool = false

    /// Information about the available update
    @Published private(set) var availableUpdate: UpdateInfo?

    /// The detected installation source
    @Published private(set) var installSource: InstallSource

    /// Whether update checking is enabled for this installation
    var updateCheckingEnabled: Bool {
        (installSource == .direct || installSource == .homebrew) && !isNightlyBuild
    }

    /// Whether automatic update checking is enabled (respects user setting)
    var automaticUpdateCheckingEnabled: Bool {
        updateCheckingEnabled && SettingsManager.shared.checkForUpdatesAutomatically
    }

    /// Whether this is a nightly build
    var isNightlyBuild: Bool {
        let version = currentVersion
        return version.contains("nightly") ||
               version.contains("alpha") ||
               version.contains("beta") ||
               version.contains("-") // e.g., 1.0.0-20240115
    }

    /// Current app version
    var currentVersion: String {
        _testVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Current build number
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    // GitHub repository info
    private let repoOwner = "matthewpick"
    private let repoName = "pesto-clipboard"

    // Minimum interval between checks (24 hours)
    private let minimumCheckInterval: TimeInterval = 24 * 60 * 60

    private var cancellables = Set<AnyCancellable>()

    /// Override version for testing
    private var _testVersion: String?

    private init() {
        self.installSource = InstallSource.detect()

        // Check for updates on launch if appropriate
        if automaticUpdateCheckingEnabled {
            checkForUpdatesIfNeeded()
        }
    }

    /// Testable initializer for unit tests
    init(testVersion: String, installSource: InstallSource = .direct) {
        self._testVersion = testVersion
        self.installSource = installSource
    }

    /// Check for updates if enough time has passed since last check
    func checkForUpdatesIfNeeded() {
        guard automaticUpdateCheckingEnabled else { return }

        let lastCheck = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        let now = Date().timeIntervalSince1970

        if now - lastCheck >= minimumCheckInterval {
            checkForUpdates()
        }
    }

    /// Force check for updates
    func checkForUpdates() {
        guard updateCheckingEnabled else { return }

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GitHubRelease.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Update check failed: \(error.localizedDescription)")
                    }
                    // Record check time even on failure to avoid hammering the API
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
                },
                receiveValue: { [weak self] release in
                    self?.processRelease(release)
                }
            )
            .store(in: &cancellables)
    }

    /// Process a GitHub release (internal for testing)
    func processRelease(_ release: GitHubRelease) {
        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

        // Check if this version was dismissed by user
        let dismissedVersion = UserDefaults.standard.string(forKey: "dismissedUpdateVersion")
        if dismissedVersion == latestVersion {
            return
        }

        // Compare versions
        if isNewerVersion(latestVersion, than: currentVersion) {
            let downloadURL: URL?
            if let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                downloadURL = URL(string: asset.browserDownloadURL)
            } else {
                downloadURL = URL(string: release.htmlURL)
            }

            let dateFormatter = ISO8601DateFormatter()
            let publishedAt = release.publishedAt.flatMap { dateFormatter.date(from: $0) }

            availableUpdate = UpdateInfo(
                version: latestVersion,
                releaseNotes: release.body,
                downloadURL: downloadURL,
                publishedAt: publishedAt,
                isNightly: latestVersion.contains("nightly") || release.prerelease
            )
            updateAvailable = true
        } else {
            updateAvailable = false
            availableUpdate = nil
        }
    }

    /// Compare semantic versions (internal for testing)
    func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        // Pad arrays to same length
        let maxLength = max(newComponents.count, currentComponents.count)
        let paddedNew = newComponents + Array(repeating: 0, count: maxLength - newComponents.count)
        let paddedCurrent = currentComponents + Array(repeating: 0, count: maxLength - currentComponents.count)

        for (n, c) in zip(paddedNew, paddedCurrent) {
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }

    /// Dismiss the current update (user chose to skip this version)
    func dismissUpdate() {
        if let version = availableUpdate?.version {
            UserDefaults.standard.set(version, forKey: "dismissedUpdateVersion")
        }
        updateAvailable = false
        availableUpdate = nil
    }

    /// Open the download page for the update
    func openDownloadPage() {
        guard let url = availableUpdate?.downloadURL else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - GitHub API Response Types

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: String
    let publishedAt: String?
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case prerelease
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

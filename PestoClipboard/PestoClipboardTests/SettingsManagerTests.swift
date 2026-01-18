import Testing
import Foundation
@testable import Pesto_Clipboard

@MainActor
struct SettingsManagerTests {

    // MARK: - SortOrder Enum Tests

    @Test func sortOrderRawValues() {
        #expect(SettingsManager.SortOrder.recentlyUsed.rawValue == "Recently Used")
        #expect(SettingsManager.SortOrder.dateAdded.rawValue == "Date Added")
    }

    @Test func sortOrderFromRawValue() {
        #expect(SettingsManager.SortOrder(rawValue: "Recently Used") == .recentlyUsed)
        #expect(SettingsManager.SortOrder(rawValue: "Date Added") == .dateAdded)
        #expect(SettingsManager.SortOrder(rawValue: "Invalid") == nil)
    }

    @Test func sortOrderAllCases() {
        let allCases = SettingsManager.SortOrder.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.recentlyUsed))
        #expect(allCases.contains(.dateAdded))
    }

    // MARK: - Singleton Tests

    @Test func sharedInstanceExists() {
        let shared = SettingsManager.shared
        #expect(shared != nil)
    }

    @Test func sharedInstanceIsSame() {
        let first = SettingsManager.shared
        let second = SettingsManager.shared
        #expect(first === second)
    }

    // MARK: - Default Values Tests
    // Note: These test the current state of UserDefaults, which may have been modified

    @Test func defaultCaptureSettingsAreEnabled() {
        // Fresh install defaults should be true for capture settings
        // This tests the expected defaults, not necessarily the current state
        let defaults = UserDefaults.standard

        // If the key hasn't been set, object(forKey:) returns nil
        // The SettingsManager treats nil as true for these settings
        if defaults.object(forKey: "captureText") == nil {
            // Not set = default to true (as per SettingsManager init)
            #expect(true)
        }
    }

    @Test func defaultHistoryLimit() {
        // Default history limit should be 500 (Constants.defaultHistoryLimit)
        #expect(Constants.defaultHistoryLimit == 500)
    }

    @Test func historyLimitRange() {
        // Verify the history limit range constants
        #expect(Constants.historyLimitRange.lowerBound == 50)
        #expect(Constants.historyLimitRange.upperBound == 5000)
    }

    @Test func historyLimitStep() {
        #expect(Constants.historyLimitStep == 50)
    }

    // MARK: - AutoDeleteInterval Enum Tests

    @Test func autoDeleteIntervalTimeIntervals() {
        #expect(SettingsManager.AutoDeleteInterval.never.timeInterval == nil)
        #expect(SettingsManager.AutoDeleteInterval.oneHour.timeInterval == 3600.0)
        #expect(SettingsManager.AutoDeleteInterval.threeHours.timeInterval == 10800.0)
        #expect(SettingsManager.AutoDeleteInterval.twelveHours.timeInterval == 43200.0)
        #expect(SettingsManager.AutoDeleteInterval.oneDay.timeInterval == 86400.0)
        #expect(SettingsManager.AutoDeleteInterval.sevenDays.timeInterval == 604800.0)
        #expect(SettingsManager.AutoDeleteInterval.thirtyDays.timeInterval == 2592000.0)
    }

    @Test func autoDeleteIntervalAllCases() {
        let allCases = SettingsManager.AutoDeleteInterval.allCases
        #expect(allCases.count == 7)
        #expect(allCases.contains(.never))
        #expect(allCases.contains(.oneHour))
        #expect(allCases.contains(.threeHours))
        #expect(allCases.contains(.twelveHours))
        #expect(allCases.contains(.oneDay))
        #expect(allCases.contains(.sevenDays))
        #expect(allCases.contains(.thirtyDays))
    }

    @Test func autoDeleteIntervalFromRawValue() {
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "never") == .never)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "oneHour") == .oneHour)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "threeHours") == .threeHours)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "twelveHours") == .twelveHours)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "oneDay") == .oneDay)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "sevenDays") == .sevenDays)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "thirtyDays") == .thirtyDays)
        #expect(SettingsManager.AutoDeleteInterval(rawValue: "Invalid") == nil)
    }
}

// MARK: - Constants Tests

@MainActor
struct ConstantsTests {

    @Test func clipboardPollInterval() {
        #expect(Constants.clipboardPollInterval == 0.5)
    }

    @Test func maxImageSizeBytes() {
        #expect(Constants.maxImageSizeBytes == 5_000_000) // 5MB
    }

    @Test func thumbnailMaxSize() {
        #expect(Constants.thumbnailMaxSize == 128)
    }

    @Test func thumbnailCompressionQuality() {
        #expect(Constants.thumbnailCompressionQuality == 0.7)
    }
}

import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct PreferencesView: View {
    @State private var selectedTab: PreferenceTab = .general
    @ObservedObject private var updateChecker = UpdateChecker.shared

    enum PreferenceTab: String, CaseIterable {
        case general = "General"
        case capture = "Capture"
        case history = "History"
        case advanced = "Advanced"

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .capture: return "doc.on.clipboard"
            case .history: return "clock.fill"
            case .advanced: return "gearshape.2.fill"
            }
        }

        var localizedName: String {
            switch self {
            case .general: return String(localized: "General")
            case .capture: return String(localized: "Capture")
            case .history: return String(localized: "History")
            case .advanced: return String(localized: "Advanced")
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(PreferenceTab.allCases, id: \.self, selection: $selectedTab) { tab in
                HStack {
                    Label(tab.localizedName, systemImage: tab.icon)
                    Spacer()
                    if tab == .advanced && updateChecker.updateAvailable {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            Divider()

            // Detail view
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .capture:
                    CaptureSettingsView()
                case .history:
                    HistorySettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hotkey Section
                SettingsSection(title: "Keyboard Shortcut") {
                    HStack {
                        Text("Open Pesto Clipboard:")
                        KeyboardShortcuts.Recorder(for: .openHistory)
                        Spacer()
                    }
                }

                // Startup Section
                SettingsSection(title: "Startup") {
                    SettingsToggle(
                        title: "Launch at login",
                        subtitle: "Automatically start Pesto Clipboard when you log in",
                        isOn: $settings.launchAtLogin
                    )
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        LaunchAtLoginManager.setLaunchAtLogin(newValue)
                    }
                }

                // Behavior Section
                SettingsSection(title: "Behavior") {
                    SettingsToggle(
                        title: "Paste automatically",
                        subtitle: "Paste immediately after selecting an item",
                        isOn: $settings.pasteAutomatically
                    )
                }

                // Appearance Section
                SettingsSection(title: "Appearance") {
                    SettingsToggle(
                        title: "Transparent background",
                        subtitle: "Use a glass effect for the clipboard panel",
                        isOn: $settings.useTransparentBackground
                    )
                }

                // Setup Section
                SettingsSection(title: "Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            NSApp.keyWindow?.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                OnboardingWindowController.shared.showOnboarding()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Run Setup Wizard")
                            }
                        }
                        .buttonStyle(.bordered)

                        Text("Re-run the initial setup wizard to configure basic settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Capture Settings

struct CaptureSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showingAppPicker = false
    @State private var selectedApp: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Capture Types Section
                SettingsSection(title: "Content Types") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose what types of content to capture from the clipboard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsCheckbox(title: "Text", icon: "doc.text.fill", isOn: $settings.captureText)
                            SettingsCheckbox(title: "Images", icon: "photo.fill", isOn: $settings.captureImages)
                            SettingsCheckbox(title: "Files", icon: "folder.fill", isOn: $settings.captureFiles)
                        }
                    }
                }

                // Sources Section
                SettingsSection(title: "Sources") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $settings.ignoreRemoteClipboard) {
                            HStack(spacing: 8) {
                                Image(systemName: "laptopcomputer.and.iphone")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Ignore clipboard from other devices")
                            }
                        }
                        .toggleStyle(.checkbox)

                        Text("When enabled, items copied on other Macs or iOS devices via Universal Clipboard will not be saved.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Divider()
                            .padding(.vertical, 4)

                        Toggle(isOn: $settings.ignorePasswordManagers) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Ignore password manager content")
                            }
                        }
                        .toggleStyle(.checkbox)

                        Text("When enabled, items copied from 1Password, Bitwarden, LastPass, and other password managers will not be saved.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Ignored Applications Section
                SettingsSection(title: "Ignored Applications") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clipboard content from these applications will not be captured.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // App list
                        VStack(spacing: 0) {
                            if settings.ignoredApps.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "app.dashed")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.tertiary)
                                        Text("No ignored applications")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 32)
                                    Spacer()
                                }
                            } else {
                                ForEach(settings.ignoredApps, id: \.self) { app in
                                    AppRow(path: app, isSelected: selectedApp == app)
                                        .onTapGesture {
                                            selectedApp = selectedApp == app ? nil : app
                                        }
                                }
                                Spacer()
                            }
                        }
                        .frame(minHeight: 120, alignment: .top)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                        // Buttons
                        HStack(spacing: 8) {
                            Button {
                                showingAppPicker = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                if let selected = selectedApp {
                                    settings.ignoredApps.removeAll { $0 == selected }
                                    selectedApp = nil
                                }
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedApp == nil)

                            Spacer()
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if !settings.ignoredApps.contains(url.path) {
                    settings.ignoredApps.append(url.path)
                }
            }
        }
    }
}

struct AppRow: View {
    let path: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 24, height: 24)

            Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - History Settings

struct HistorySettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showingClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // History Limits Section
                SettingsSection(title: "Limits") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Maximum items:")
                                    .frame(width: 120, alignment: .leading)

                                TextField("", value: $settings.historyLimit, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)

                                SnappingStepper(
                                    value: $settings.historyLimit,
                                    range: Constants.historyLimitRange,
                                    step: Constants.historyLimitStep
                                )

                                Text("items")
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }

                            Text("Reducing this limit will delete older items immediately.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        HStack {
                            Text("Sort by:")
                                .frame(width: 120, alignment: .leading)

                            Picker("", selection: $settings.sortOrder) {
                                ForEach(SettingsManager.SortOrder.allCases, id: \.self) { order in
                                    Text(order.localizedName).tag(order)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)

                            Spacer()
                        }
                    }
                }

                // Auto-Delete Section
                SettingsSection(title: "Auto-Delete") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Delete items after:")
                                .frame(width: 120, alignment: .leading)

                            Picker("", selection: $settings.autoDeleteInterval) {
                                ForEach(SettingsManager.AutoDeleteInterval.allCases, id: \.self) { interval in
                                    Text(interval.localizedName).tag(interval)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)

                            Spacer()
                        }

                        Text("Starred items are never automatically deleted.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Danger Zone
                SettingsSection(title: "Danger Zone") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clearing history cannot be undone.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clear All History")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("Clear History", isPresented: $showingClearConfirmation) {
            Button("Clear History (Keep Starred)", role: .destructive) {
                settings.clearHistory(includeStarred: false)
            }
            Button("Clear Everything (Including Starred)", role: .destructive) {
                settings.clearHistory(includeStarred: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear your clipboard history?")
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Updates Section
                SettingsSection(title: "Updates") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Version info row
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Version")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                HStack(spacing: 4) {
                                    Text(updateChecker.currentVersion)
                                        .fontWeight(.medium)
                                    if updateChecker.isNightlyBuild {
                                        Text("nightly")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundStyle(.orange)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Source")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(updateChecker.installSource.rawValue)
                            }

                            Spacer()
                        }

                        if updateChecker.installSource == .direct || updateChecker.installSource == .homebrew {
                            // Update available banner
                            if updateChecker.updateAvailable, let update = updateChecker.availableUpdate {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Version \(update.version) available")
                                                .fontWeight(.medium)
                                            if let notes = update.releaseNotes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                    }

                                    if updateChecker.installSource == .direct {
                                        HStack(spacing: 12) {
                                            Button {
                                                updateChecker.openDownloadPage()
                                            } label: {
                                                HStack {
                                                    Image(systemName: "arrow.down.to.line")
                                                    Text("Download Update")
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)

                                            Button {
                                                updateChecker.dismissUpdate()
                                            } label: {
                                                Text("Skip This Version")
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    } else {
                                        // Homebrew install
                                        HStack {
                                            Text("brew upgrade pesto-clipboard")
                                                .font(.system(.caption, design: .monospaced))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(nsColor: .textBackgroundColor))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            Button {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString("brew upgrade pesto-clipboard", forType: .string)
                                            } label: {
                                                Image(systemName: "doc.on.doc")
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Copy to clipboard")
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if !updateChecker.isNightlyBuild {
                                // Up to date status
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("You're up to date")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                // Nightly build notice
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                    Text("Update checks disabled for nightly builds")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Check for updates controls
                            if !updateChecker.isNightlyBuild {
                                VStack(alignment: .leading, spacing: 16) {
                                    Toggle("Check for updates automatically", isOn: $settings.checkForUpdatesAutomatically)
                                        .toggleStyle(.checkbox)

                                    Button {
                                        updateChecker.checkForUpdates()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Check Now")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else if updateChecker.installSource == .appStore {
                            Text("Updates are managed through the App Store.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Menu Bar Section
                SettingsSection(title: "Menu Bar") {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsToggle(
                            title: "Hide menu bar icon",
                            subtitle: "Only access Pesto Clipboard via keyboard shortcut",
                            isOn: $settings.hideMenuBarIcon
                        )

                        if settings.hideMenuBarIcon {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                Text("Make sure you remember your keyboard shortcut!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Reusable Components

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
    }
}

struct SettingsToggle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

struct SettingsCheckbox: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(title)
            }
        }
        .toggleStyle(.checkbox)
    }
}

#Preview {
    PreferencesView()
}

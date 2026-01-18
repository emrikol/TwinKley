import AppKit
import TwinKleyCore
#if !APP_STORE
import Sparkle
#endif

class PreferencesWindowController: NSWindowController {
	private let settingsManager: SettingsManager
	#if !APP_STORE
	private let updaterController: SPUStandardUpdaterController?
	#endif

	// UI Controls
	private var liveSyncCheckbox: NSButton!
	private var timedSyncCheckbox: NSButton!
	private var intervalSlider: NSSlider!
	private var intervalLabel: NSTextField!
	private var pauseOnBatteryCheckbox: NSButton!
	private var pauseOnLowBatteryCheckbox: NSButton!
	private var gammaSlider: NSSlider!
	private var gammaLabel: NSTextField!
	#if !APP_STORE
	private var autoCheckUpdatesCheckbox: NSButton!
	#endif

	#if !APP_STORE
	init(settingsManager: SettingsManager, updaterController: SPUStandardUpdaterController?) {
		self.settingsManager = settingsManager
		self.updaterController = updaterController

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Preferences"
		window.center()

		super.init(window: window)

		setupUI()
	}
	#else
	init(settingsManager: SettingsManager) {
		self.settingsManager = settingsManager

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Preferences"
		window.center()

		super.init(window: window)

		setupUI()
	}
	#endif

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupUI() {
		let contentView = NSView(frame: window!.contentView!.bounds)
		contentView.autoresizingMask = [.width, .height]
		window!.contentView = contentView

		// Create tabbed interface
		let tabView = NSTabView(frame: NSRect(x: 20, y: 20, width: 480, height: 440))
		tabView.autoresizingMask = [.width, .height]

		// Tab 1: Sync Settings
		let syncTab = NSTabViewItem(identifier: "sync")
		syncTab.label = "Sync"
		syncTab.view = createSyncTab()
		tabView.addTabViewItem(syncTab)

		// Tab 2: Advanced
		let advancedTab = NSTabViewItem(identifier: "advanced")
		advancedTab.label = "Advanced"
		advancedTab.view = createAdvancedTab()
		tabView.addTabViewItem(advancedTab)

		// Tab 3: Updates & Privacy
		let updatesTab = NSTabViewItem(identifier: "updates")
		updatesTab.label = "Updates & Privacy"
		updatesTab.view = createUpdatesTab()
		tabView.addTabViewItem(updatesTab)

		contentView.addSubview(tabView)
	}

	private func createSyncTab() -> NSView {
		let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 400))

		var yPos: CGFloat = 360

		// Live Sync section
		let liveSyncLabel = NSTextField(labelWithString: "Live Sync")
		liveSyncLabel.font = NSFont.boldSystemFont(ofSize: 13)
		liveSyncLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		view.addSubview(liveSyncLabel)
		yPos -= 30

		liveSyncCheckbox = NSButton(
			checkboxWithTitle: "Enable live sync (responds to brightness changes instantly)",
			target: self,
			action: #selector(settingChanged)
		)
		liveSyncCheckbox.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		liveSyncCheckbox.state = settingsManager.settings.liveSyncEnabled ? .on : .off
		view.addSubview(liveSyncCheckbox)
		yPos -= 30

		let liveSyncHelp = NSTextField(wrappingLabelWithString:
			"Monitors brightness key presses, Control Center slider, and Touch Bar. " +
				"Instant response, no polling."
		)
		liveSyncHelp.font = NSFont.systemFont(ofSize: 11)
		liveSyncHelp.textColor = .secondaryLabelColor
		liveSyncHelp.frame = NSRect(x: 40, y: yPos, width: 420, height: 32)
		view.addSubview(liveSyncHelp)
		yPos -= 50

		// Timed Sync section
		let timedSyncLabel = NSTextField(labelWithString: "Timed Sync (Safety Net)")
		timedSyncLabel.font = NSFont.boldSystemFont(ofSize: 13)
		timedSyncLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		view.addSubview(timedSyncLabel)
		yPos -= 30

		let intervalRow = NSView(frame: NSRect(x: 20, y: yPos, width: 440, height: 20))

		timedSyncCheckbox = NSButton(
			checkboxWithTitle: "Enable background check every:",
			target: self,
			action: #selector(settingChanged)
		)
		timedSyncCheckbox.frame = NSRect(x: 0, y: 0, width: 220, height: 20)
		timedSyncCheckbox.state = settingsManager.settings.timedSyncEnabled ? .on : .off
		intervalRow.addSubview(timedSyncCheckbox)

		intervalSlider = NSSlider(
			value: Double(settingsManager.settings.timedSyncIntervalMs),
			minValue: Double(Settings.intervalMin),
			maxValue: Double(Settings.intervalMax),
			target: self,
			action: #selector(intervalChanged)
		)
		intervalSlider.frame = NSRect(x: 220, y: 0, width: 150, height: 20)
		intervalRow.addSubview(intervalSlider)

		intervalLabel = NSTextField(labelWithString: formatInterval(settingsManager.settings.timedSyncIntervalMs))
		intervalLabel.frame = NSRect(x: 380, y: 0, width: 60, height: 20)
		intervalLabel.alignment = .right
		intervalRow.addSubview(intervalLabel)

		view.addSubview(intervalRow)
		yPos -= 30

		let timedSyncHelp = NSTextField(wrappingLabelWithString:
			"Catches rare cases where apps change brightness without notifying the system. " +
				"Can be disabled if Live Sync works perfectly."
		)
		timedSyncHelp.font = NSFont.systemFont(ofSize: 11)
		timedSyncHelp.textColor = .secondaryLabelColor
		timedSyncHelp.frame = NSRect(x: 40, y: yPos, width: 420, height: 44)
		view.addSubview(timedSyncHelp)
		yPos -= 60

		// Battery options
		let batteryLabel = NSTextField(labelWithString: "Battery Options")
		batteryLabel.font = NSFont.boldSystemFont(ofSize: 13)
		batteryLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		view.addSubview(batteryLabel)
		yPos -= 30

		pauseOnBatteryCheckbox = NSButton(
			checkboxWithTitle: "Pause timed sync when on battery power",
			target: self,
			action: #selector(settingChanged)
		)
		pauseOnBatteryCheckbox.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		pauseOnBatteryCheckbox.state = settingsManager.settings.pauseTimedSyncOnBattery ? .on : .off
		view.addSubview(pauseOnBatteryCheckbox)
		yPos -= 25

		pauseOnLowBatteryCheckbox = NSButton(
			checkboxWithTitle: "Pause timed sync when battery is below 20%",
			target: self,
			action: #selector(settingChanged)
		)
		pauseOnLowBatteryCheckbox.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		pauseOnLowBatteryCheckbox.state = settingsManager.settings.pauseTimedSyncOnLowBattery ? .on : .off
		view.addSubview(pauseOnLowBatteryCheckbox)

		return view
	}

	private func createAdvancedTab() -> NSView {
		let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 400))

		var yPos: CGFloat = 360

		// Gamma correction section
		let gammaTitle = NSTextField(labelWithString: "Brightness Gamma Correction")
		gammaTitle.font = NSFont.boldSystemFont(ofSize: 13)
		gammaTitle.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		view.addSubview(gammaTitle)
		yPos -= 30

		let gammaRow = NSView(frame: NSRect(x: 20, y: yPos, width: 440, height: 20))

		gammaSlider = NSSlider(
			value: settingsManager.settings.brightnessGamma,
			minValue: Settings.gammaMin,
			maxValue: Settings.gammaMax,
			target: self,
			action: #selector(gammaChanged)
		)
		gammaSlider.frame = NSRect(x: 0, y: 0, width: 360, height: 20)
		gammaRow.addSubview(gammaSlider)

		gammaLabel = NSTextField(labelWithString: String(format: "%.1f", settingsManager.settings.brightnessGamma))
		gammaLabel.frame = NSRect(x: 370, y: 0, width: 70, height: 20)
		gammaLabel.alignment = .right
		gammaRow.addSubview(gammaLabel)

		view.addSubview(gammaRow)
		yPos -= 30

		let gammaHelp = NSTextField(wrappingLabelWithString:
			"Controls how keyboard brightness responds to display brightness. " +
				"Higher values dim the keyboard more at low display levels.\n\n" +
				"• 1.0 = Linear (keyboard matches display 1:1)\n" +
				"• 1.5 = Mild correction (default, recommended)\n" +
				"• 2.0 = Moderate correction\n" +
				"• 2.2 = sRGB-like (aggressive dimming)"
		)
		gammaHelp.font = NSFont.systemFont(ofSize: 11)
		gammaHelp.textColor = .secondaryLabelColor
		gammaHelp.frame = NSRect(x: 40, y: yPos - 100, width: 420, height: 110)
		view.addSubview(gammaHelp)

		return view
	}

	private func createUpdatesTab() -> NSView {
		let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 400))

		var yPos: CGFloat = 360

		#if !APP_STORE
		// Auto-update preferences
		let updatesLabel = NSTextField(labelWithString: "Software Updates")
		updatesLabel.font = NSFont.boldSystemFont(ofSize: 13)
		updatesLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		view.addSubview(updatesLabel)
		yPos -= 30

		autoCheckUpdatesCheckbox = NSButton(
			checkboxWithTitle: "Automatically check for updates on launch",
			target: self,
			action: #selector(updateCheckSettingChanged)
		)
		autoCheckUpdatesCheckbox.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		autoCheckUpdatesCheckbox.state = updaterController?.updater.automaticallyChecksForUpdates ?? false ? .on : .off
		view.addSubview(autoCheckUpdatesCheckbox)
		yPos -= 30

		let updateHelp = NSTextField(wrappingLabelWithString:
			"When enabled, \(AppInfo.shortName) will check for updates when it starts. " +
				"You control when to install updates.\n\n" +
				"When disabled, use 'Check for Updates' in the menu bar to manually check."
		)
		updateHelp.font = NSFont.systemFont(ofSize: 11)
		updateHelp.textColor = .secondaryLabelColor
		updateHelp.frame = NSRect(x: 40, y: yPos - 60, width: 420, height: 70)
		view.addSubview(updateHelp)
		yPos -= 90
		#endif

		// Privacy section
		let privacyLabel = NSTextField(labelWithString: "Privacy")
		privacyLabel.font = NSFont.boldSystemFont(ofSize: 13)
		privacyLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
		view.addSubview(privacyLabel)
		yPos -= 30

		let privacyText = NSTextField(wrappingLabelWithString:
			"\(AppInfo.shortName) collects zero user data. Everything runs locally on your Mac.\n\n" +
				"• No analytics or telemetry\n" +
				"• No crash reports\n" +
				"• No network connections (except update checks)\n" +
				"• Settings stored locally in ~/.twinkley.json"
		)
		privacyText.font = NSFont.systemFont(ofSize: 11)
		privacyText.frame = NSRect(x: 40, y: yPos - 105, width: 420, height: 115)
		view.addSubview(privacyText)
		yPos -= 135

		let privacyButton = NSButton(title: "Read Full Privacy Policy", target: self, action: #selector(openPrivacyPolicy))
		privacyButton.bezelStyle = .rounded
		privacyButton.frame = NSRect(x: 20, y: yPos, width: 200, height: 30)
		view.addSubview(privacyButton)

		return view
	}

	// MARK: - Actions

	@objc
	private func settingChanged() {
		settingsManager.update { settings in
			settings.liveSyncEnabled = liveSyncCheckbox.state == .on
			settings.timedSyncEnabled = timedSyncCheckbox.state == .on
			settings.timedSyncIntervalMs = Int(intervalSlider.doubleValue)
			settings.pauseTimedSyncOnBattery = pauseOnBatteryCheckbox.state == .on
			settings.pauseTimedSyncOnLowBattery = pauseOnLowBatteryCheckbox.state == .on
			settings.brightnessGamma = gammaSlider.doubleValue
		}

		// Post notification so AppDelegate can update its state
		NotificationCenter.default.post(name: .settingsChanged, object: nil)
	}

	@objc
	private func intervalChanged() {
		let value = Int(intervalSlider.doubleValue)
		intervalLabel.stringValue = formatInterval(value)
		settingChanged()
	}

	@objc
	private func gammaChanged() {
		let value = gammaSlider.doubleValue
		gammaLabel.stringValue = String(format: "%.1f", value)
		settingChanged()
	}

	#if !APP_STORE
	@objc
	private func updateCheckSettingChanged() {
		updaterController?.updater.automaticallyChecksForUpdates = autoCheckUpdatesCheckbox.state == .on
	}
	#endif

	@objc
	private func openPrivacyPolicy() {
		if let url = URL(string: "\(AppInfo.githubURL)/blob/main/PRIVACY.md") {
			NSWorkspace.shared.open(url)
		}
	}

	// MARK: - Helpers

	private func formatInterval(_ ms: Int) -> String {
		if ms < 1_000 {
			return "\(ms)ms"
		} else {
			let seconds = Double(ms) / 1_000.0
			return String(format: "%.1fs", seconds)
		}
	}
}

// Notification for settings changes
extension Notification.Name {
	static let settingsChanged = Notification.Name("settingsChanged")
}

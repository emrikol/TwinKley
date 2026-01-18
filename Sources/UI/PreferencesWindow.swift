import AppKit
import TwinKleyCore

/// Preferences window controller - dynamically loaded UI component
@objc public class PreferencesWindowController: NSWindowController, PreferencesWindowProtocol {
	// Context with all dependencies (protocol-based)
	private var context: UIContext?

	// UI Controls
	private var liveSyncCheckbox: NSButton!
	private var timedSyncCheckbox: NSButton!
	private var intervalSlider: NSSlider!
	private var intervalLabel: NSTextField!
	private var pauseOnBatteryCheckbox: NSButton!
	private var pauseOnLowBatteryCheckbox: NSButton!
	private var gammaSlider: NSSlider!
	private var gammaLabel: NSTextField!
	private var autoCheckUpdatesCheckbox: NSButton!
	private var tabView: NSTabView!

	public override init(window: NSWindow?) {
		super.init(window: window)
	}

	@objc public required convenience init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Preferences"
		window.center()

		self.init(window: window)
		setupUI()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	/// Set the context with all dependencies
	@objc public func setContext(_ context: Any) {
		guard let ctx = context as? UIContext else { return }
		self.context = ctx
		// Update UI to reflect current settings
		if let settings = ctx.settingsManager?.settings {
			liveSyncCheckbox?.state = settings.liveSyncEnabled ? .on : .off
			timedSyncCheckbox?.state = settings.timedSyncEnabled ? .on : .off
			intervalSlider?.doubleValue = Double(settings.timedSyncIntervalMs)
			intervalLabel?.stringValue = formatInterval(settings.timedSyncIntervalMs)
			pauseOnBatteryCheckbox?.state = settings.pauseTimedSyncOnBattery ? .on : .off
			pauseOnLowBatteryCheckbox?.state = settings.pauseTimedSyncOnLowBattery ? .on : .off
			gammaSlider?.doubleValue = settings.brightnessGamma
			gammaLabel?.stringValue = String(format: "%.1f", settings.brightnessGamma)
		}
		// Update auto-update checkbox
		autoCheckUpdatesCheckbox?.state = (ctx.getAutoUpdateEnabled?() ?? false) ? .on : .off
	}

	/// Show the window
	@objc public func showWindow() {
		window?.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}

	private func setupUI() {
		let contentView = NSView(frame: window!.contentView!.bounds)
		contentView.autoresizingMask = [.width, .height]
		window!.contentView = contentView

		// Create segmented control for tab switching
		let tabLabels = ["Sync", "Advanced", "Updates & Privacy"]
		let segmentedControl = NSSegmentedControl(labels: tabLabels, trackingMode: .selectOne, target: self, action: #selector(tabChanged(_:)))
		segmentedControl.segmentStyle = .automatic
		segmentedControl.selectedSegment = 0
		segmentedControl.frame = NSRect(x: 20, y: 430, width: 480, height: 24)
		segmentedControl.autoresizingMask = [.width, .minYMargin]
		contentView.addSubview(segmentedControl)

		// Create tab view without visible tabs (content only)
		tabView = NSTabView(frame: NSRect(x: 20, y: 20, width: 480, height: 400))
		tabView.autoresizingMask = [.width, .height]
		tabView.tabViewType = .noTabsNoBorder

		// Tab 1: Sync Settings
		let syncTab = NSTabViewItem(identifier: "sync")
		syncTab.view = createSyncTab()
		tabView.addTabViewItem(syncTab)

		// Tab 2: Advanced
		let advancedTab = NSTabViewItem(identifier: "advanced")
		advancedTab.view = createAdvancedTab()
		tabView.addTabViewItem(advancedTab)

		// Tab 3: Updates & Privacy
		let updatesTab = NSTabViewItem(identifier: "updates")
		updatesTab.view = createUpdatesTab()
		tabView.addTabViewItem(updatesTab)

		contentView.addSubview(tabView)
	}

	@objc
	private func tabChanged(_ sender: NSSegmentedControl) {
		tabView.selectTabViewItem(at: sender.selectedSegment)
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

		timedSyncCheckbox = NSButton(
			checkboxWithTitle: "Enable background check every:",
			target: self,
			action: #selector(settingChanged)
		)
		timedSyncCheckbox.frame = NSRect(x: 20, y: yPos, width: 230, height: 20)
		view.addSubview(timedSyncCheckbox)

		intervalSlider = NSSlider(
			value: Double(Settings.intervalDefault),
			minValue: Double(Settings.intervalMin),
			maxValue: Double(Settings.intervalMax),
			target: self,
			action: #selector(intervalChanged)
		)
		intervalSlider.frame = NSRect(x: 250, y: yPos, width: 140, height: 20)
		view.addSubview(intervalSlider)

		intervalLabel = NSTextField(labelWithString: formatInterval(Settings.intervalDefault))
		intervalLabel.frame = NSRect(x: 400, y: yPos, width: 60, height: 20)
		intervalLabel.alignment = .right
		view.addSubview(intervalLabel)
		yPos -= 30

		let timedSyncHelp = NSTextField(wrappingLabelWithString:
			"Catches rare cases where apps change brightness without notifying the system. " +
				"Can be disabled if Live Sync works perfectly."
		)
		timedSyncHelp.font = NSFont.systemFont(ofSize: 11)
		timedSyncHelp.textColor = .secondaryLabelColor
		timedSyncHelp.frame = NSRect(x: 40, y: yPos - 14, width: 420, height: 44)
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
		view.addSubview(pauseOnBatteryCheckbox)
		yPos -= 25

		pauseOnLowBatteryCheckbox = NSButton(
			checkboxWithTitle: "Pause timed sync when battery is below 20%",
			target: self,
			action: #selector(settingChanged)
		)
		pauseOnLowBatteryCheckbox.frame = NSRect(x: 20, y: yPos, width: 440, height: 20)
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
			value: Settings.gammaDefault,
			minValue: Settings.gammaMin,
			maxValue: Settings.gammaMax,
			target: self,
			action: #selector(gammaChanged)
		)
		gammaSlider.frame = NSRect(x: 0, y: 0, width: 360, height: 20)
		gammaRow.addSubview(gammaSlider)

		gammaLabel = NSTextField(labelWithString: String(format: "%.1f", Settings.gammaDefault))
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
				"• Settings stored locally in ~/.twinkley.json"
		)
		privacyText.font = NSFont.systemFont(ofSize: 11)
		privacyText.frame = NSRect(x: 40, y: yPos - 75, width: 420, height: 85)
		view.addSubview(privacyText)
		yPos -= 105

		let updatePrivacyNote = NSTextField(wrappingLabelWithString:
			"Update checks connect to GitHub. Your IP address and basic system info " +
				"(macOS version, app version) are sent to GitHub's servers. " +
				"We do not control GitHub's privacy practices."
		)
		updatePrivacyNote.font = NSFont.systemFont(ofSize: 11)
		updatePrivacyNote.textColor = .secondaryLabelColor
		updatePrivacyNote.frame = NSRect(x: 40, y: yPos - 45, width: 420, height: 55)
		view.addSubview(updatePrivacyNote)
		yPos -= 65

		let privacyButton = NSButton(title: "Read Full Privacy Policy", target: self, action: #selector(openPrivacyPolicy))
		privacyButton.bezelStyle = .rounded
		privacyButton.frame = NSRect(x: 20, y: yPos, width: 200, height: 30)
		view.addSubview(privacyButton)

		return view
	}

	// MARK: - Actions

	@objc
	private func settingChanged() {
		context?.settingsManager?.update { settings in
			settings.liveSyncEnabled = liveSyncCheckbox.state == .on
			settings.timedSyncEnabled = timedSyncCheckbox.state == .on
			settings.timedSyncIntervalMs = Int(intervalSlider.doubleValue)
			settings.pauseTimedSyncOnBattery = pauseOnBatteryCheckbox.state == .on
			settings.pauseTimedSyncOnLowBattery = pauseOnLowBatteryCheckbox.state == .on
			settings.brightnessGamma = gammaSlider.doubleValue
		}
		context?.onSettingsChanged?()
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

	@objc
	private func updateCheckSettingChanged() {
		context?.setAutoUpdateEnabled?(autoCheckUpdatesCheckbox.state == .on)
	}

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

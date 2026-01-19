// swiftlint:disable file_length
// Rationale: DebugWindow is a self-contained diagnostic UI with many controls.
// Splitting would complicate the already-lazy-loaded UI module architecture.

import AppKit
import TwinKleyCore

// Rationale: Debug window contains extensive diagnostic UI - all controls are related.
// The class is already isolated in a lazy-loaded module to minimize main app footprint.
/// Debug window controller - dynamically loaded UI component
@objc public class DebugWindowController: NSWindowController, DebugWindowProtocol { // swiftlint:disable:this type_body_length
	// UI Controls
	private var debugToggle: NSButton!
	private var syncHistoryToggle: NSButton!
	private var logPathLabel: NSTextField!
	private var captureButton: NSButton!
	private var captureTimePopup: NSPopUpButton!
	private var captureWarningLabel: NSTextField!
	private var captureResultsView: NSScrollView!
	private var captureResultsText: NSTextView!
	private var countdownLabel: NSTextField!

	// Diagnostics labels
	private var macModelLabel: NSTextField!
	private var macOSVersionLabel: NSTextField!
	private var displayBrightnessLabel: NSTextField!
	private var keyboardBrightnessLabel: NSTextField!
	private var eventTapStatusLabel: NSTextField!
	private var frameworkStatusLabel: NSTextField!
	private var accessibilityStatusLabel: NSTextField!
	private var powerStateLabel: NSTextField!
	private var keyboardIDsLabel: NSTextField!

	// Capture state
	private var isCapturing = false
	private var captureStartTime: Date?
	private var captureDuration: Int = 30
	private var captureTimer: Timer?
	private var capturedEvents: [(Date, String)] = []

	// Context with all dependencies (protocol-based)
	private var context: UIContext?

	// Track current debug state (updated from AppDelegate)
	public var isDebugModeEnabled = false {
		didSet {
			debugToggle?.state = isDebugModeEnabled ? .on : .off
		}
	}

	override public init(window: NSWindow?) {
		super.init(window: window)
	}

	@objc public required convenience init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 620, height: 800),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Debug & Diagnostics"
		window.center()

		self.init(window: window)
		setupUI()
		startDiagnosticsRefresh()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	/// Set the context with all dependencies
	@objc public func setContext(_ context: Any) {
		guard let ctx = context as? UIContext else { return }
		self.context = ctx
	}

	/// Show the window
	@objc public func showWindow() {
		window?.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		refreshDiagnostics()
	}

	// Rationale: UI setup code creates all controls in a single logical flow.
	// Splitting would scatter related UI elements and make layout harder to follow.
	private func setupUI() { // swiftlint:disable:this function_body_length
		let contentView = NSView(frame: window!.contentView!.bounds)
		contentView.autoresizingMask = [.width, .height]
		window!.contentView = contentView

		var yPos: CGFloat = 760

		// MARK: - Debug Logging Section

		let debugSection = createSectionLabel("Debug Logging", at: yPos)
		contentView.addSubview(debugSection)
		yPos -= 30

		debugToggle = NSButton(checkboxWithTitle: "Enable debug logging", target: self, action: #selector(debugToggleChanged))
		debugToggle.frame = NSRect(x: 20, y: yPos, width: 180, height: 20)
		debugToggle.state = isDebugModeEnabled ? .on : .off
		contentView.addSubview(debugToggle)

		syncHistoryToggle = NSButton(checkboxWithTitle: "Log sync history", target: self, action: #selector(syncHistoryToggleChanged))
		syncHistoryToggle.frame = NSRect(x: 210, y: yPos, width: 150, height: 20)
		syncHistoryToggle.state = .off
		contentView.addSubview(syncHistoryToggle)

		let viewHistoryButton = NSButton(title: "View History", target: self, action: #selector(viewSyncHistory))
		viewHistoryButton.bezelStyle = .rounded
		viewHistoryButton.frame = NSRect(x: 370, y: yPos - 2, width: 100, height: 22)
		contentView.addSubview(viewHistoryButton)
		yPos -= 25

		logPathLabel = NSTextField(labelWithString: "Log file: ~/.twinkley-debug.log")
		logPathLabel.font = NSFont.systemFont(ofSize: 11)
		logPathLabel.textColor = .secondaryLabelColor
		logPathLabel.frame = NSRect(x: 40, y: yPos, width: 400, height: 16)
		contentView.addSubview(logPathLabel)

		let openLogButton = NSButton(title: "Open Log", target: self, action: #selector(openLogFile))
		openLogButton.bezelStyle = .rounded
		openLogButton.frame = NSRect(x: 450, y: yPos - 4, width: 80, height: 24)
		contentView.addSubview(openLogButton)

		let copyLogButton = NSButton(title: "Copy", target: self, action: #selector(copyLogToClipboard))
		copyLogButton.bezelStyle = .rounded
		copyLogButton.frame = NSRect(x: 535, y: yPos - 4, width: 50, height: 24)
		contentView.addSubview(copyLogButton)
		yPos -= 40

		// MARK: - System Diagnostics Section

		let diagSection = createSectionLabel("System Diagnostics", at: yPos)
		contentView.addSubview(diagSection)
		yPos -= 25

		// Create two columns of diagnostics
		let col1X: CGFloat = 20
		let col2X: CGFloat = 310
		let rowHeight: CGFloat = 22

		macModelLabel = createDiagnosticRow("Mac Model:", at: CGPoint(x: col1X, y: yPos), in: contentView)
		macOSVersionLabel = createDiagnosticRow("macOS:", at: CGPoint(x: col2X, y: yPos), in: contentView)
		yPos -= rowHeight

		displayBrightnessLabel = createDiagnosticRow("Display Brightness:", at: CGPoint(x: col1X, y: yPos), in: contentView)
		keyboardBrightnessLabel = createDiagnosticRow("Keyboard Brightness:", at: CGPoint(x: col2X, y: yPos), in: contentView)
		yPos -= rowHeight

		eventTapStatusLabel = createDiagnosticRow("Event Tap:", at: CGPoint(x: col1X, y: yPos), in: contentView)
		frameworkStatusLabel = createDiagnosticRow("Frameworks:", at: CGPoint(x: col2X, y: yPos), in: contentView)
		yPos -= rowHeight

		accessibilityStatusLabel = createDiagnosticRow("Accessibility:", at: CGPoint(x: col1X, y: yPos), in: contentView)
		powerStateLabel = createDiagnosticRow("Power:", at: CGPoint(x: col2X, y: yPos), in: contentView)
		yPos -= rowHeight

		keyboardIDsLabel = createDiagnosticRow("Keyboard IDs:", at: CGPoint(x: col1X, y: yPos), in: contentView)
		yPos -= 30

		// First row: Refresh, Test Read, Test Write, Export
		let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshDiagnostics))
		refreshButton.bezelStyle = .rounded
		refreshButton.frame = NSRect(x: 20, y: yPos, width: 80, height: 24)
		contentView.addSubview(refreshButton)

		let testReadButton = NSButton(title: "Test Read", target: self, action: #selector(testBrightnessRead))
		testReadButton.bezelStyle = .rounded
		testReadButton.frame = NSRect(x: 110, y: yPos, width: 90, height: 24)
		contentView.addSubview(testReadButton)

		let testWriteButton = NSButton(title: "Test Write", target: self, action: #selector(testBrightnessWrite))
		testWriteButton.bezelStyle = .rounded
		testWriteButton.frame = NSRect(x: 210, y: yPos, width: 90, height: 24)
		contentView.addSubview(testWriteButton)

		let exportButton = NSButton(title: "Export Diagnostics...", target: self, action: #selector(exportDiagnostics))
		exportButton.bezelStyle = .rounded
		exportButton.frame = NSRect(x: 440, y: yPos, width: 160, height: 24)
		contentView.addSubview(exportButton)
		yPos -= 30

		// Second row: Reset Event Tap, Simulate Brightness, Event Breakdown, Permission Help
		let resetTapButton = NSButton(title: "Reset Event Tap", target: self, action: #selector(resetEventTap))
		resetTapButton.bezelStyle = .rounded
		resetTapButton.frame = NSRect(x: 20, y: yPos, width: 120, height: 24)
		contentView.addSubview(resetTapButton)

		let simDownButton = NSButton(title: "Sim ▼", target: self, action: #selector(simulateBrightnessDown))
		simDownButton.bezelStyle = .rounded
		simDownButton.toolTip = "Simulate brightness DOWN key"
		simDownButton.frame = NSRect(x: 150, y: yPos, width: 60, height: 24)
		contentView.addSubview(simDownButton)

		let simUpButton = NSButton(title: "Sim ▲", target: self, action: #selector(simulateBrightnessUp))
		simUpButton.bezelStyle = .rounded
		simUpButton.toolTip = "Simulate brightness UP key"
		simUpButton.frame = NSRect(x: 215, y: yPos, width: 60, height: 24)
		contentView.addSubview(simUpButton)

		let eventBreakdownButton = NSButton(title: "Event Breakdown", target: self, action: #selector(showEventBreakdown))
		eventBreakdownButton.bezelStyle = .rounded
		eventBreakdownButton.frame = NSRect(x: 290, y: yPos, width: 130, height: 24)
		contentView.addSubview(eventBreakdownButton)

		let permHelpButton = NSButton(title: "Permission Help", target: self, action: #selector(showPermissionHelp))
		permHelpButton.bezelStyle = .rounded
		permHelpButton.frame = NSRect(x: 440, y: yPos, width: 130, height: 24)
		contentView.addSubview(permHelpButton)
		yPos -= 40

		// MARK: - Keypress Capture Section

		let captureSection = createSectionLabel("Keypress Capture", at: yPos)
		contentView.addSubview(captureSection)
		yPos -= 30

		// Privacy warning
		captureWarningLabel = NSTextField(wrappingLabelWithString:
			"⚠️ PRIVACY WARNING: When capture is active, ALL keypresses are logged with " +
				"brightness values. Do not type passwords or sensitive information. " +
				"Data stays local and is only shown in this window."
		)
		captureWarningLabel.font = NSFont.systemFont(ofSize: 11)
		captureWarningLabel.textColor = .systemOrange
		captureWarningLabel.frame = NSRect(x: 20, y: yPos - 45, width: 560, height: 55)
		contentView.addSubview(captureWarningLabel)
		yPos -= 70

		// Capture controls
		let captureRow = NSView(frame: NSRect(x: 20, y: yPos, width: 560, height: 24))

		let durationLabel = NSTextField(labelWithString: "Duration:")
		durationLabel.frame = NSRect(x: 0, y: 2, width: 60, height: 20)
		captureRow.addSubview(durationLabel)

		captureTimePopup = NSPopUpButton(frame: NSRect(x: 65, y: 0, width: 100, height: 24))
		captureTimePopup.addItems(withTitles: ["10 seconds", "30 seconds", "60 seconds"])
		captureTimePopup.selectItem(at: 1) // Default 30 seconds
		captureTimePopup.target = self
		captureTimePopup.action = #selector(captureDurationChanged)
		captureRow.addSubview(captureTimePopup)

		captureButton = NSButton(title: "Start Capture", target: self, action: #selector(toggleCapture))
		captureButton.bezelStyle = .rounded
		captureButton.frame = NSRect(x: 180, y: 0, width: 120, height: 24)
		captureRow.addSubview(captureButton)

		countdownLabel = NSTextField(labelWithString: "")
		countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
		countdownLabel.textColor = .systemRed
		countdownLabel.frame = NSRect(x: 310, y: 2, width: 100, height: 20)
		captureRow.addSubview(countdownLabel)

		contentView.addSubview(captureRow)
		yPos -= 35

		// Capture results
		let resultsLabel = NSTextField(labelWithString: "Captured Events:")
		resultsLabel.font = NSFont.systemFont(ofSize: 11)
		resultsLabel.frame = NSRect(x: 20, y: yPos, width: 200, height: 16)
		contentView.addSubview(resultsLabel)

		let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearCaptureResults))
		clearButton.bezelStyle = .rounded
		clearButton.controlSize = .small
		clearButton.frame = NSRect(x: 520, y: yPos - 2, width: 60, height: 20)
		contentView.addSubview(clearButton)
		yPos -= 20

		captureResultsView = NSScrollView(frame: NSRect(x: 20, y: 20, width: 560, height: yPos - 30))
		captureResultsView.hasVerticalScroller = true
		captureResultsView.autoresizingMask = [.width, .height]

		captureResultsText = NSTextView(frame: captureResultsView.bounds)
		captureResultsText.isEditable = false
		captureResultsText.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
		captureResultsText.backgroundColor = NSColor.textBackgroundColor
		captureResultsText.autoresizingMask = [.width]
		captureResultsView.documentView = captureResultsText

		contentView.addSubview(captureResultsView)

		// Initial diagnostics refresh
		refreshDiagnostics()
	}

	private func createSectionLabel(_ text: String, at y: CGFloat) -> NSTextField {
		let label = NSTextField(labelWithString: text)
		label.font = NSFont.boldSystemFont(ofSize: 13)
		label.frame = NSRect(x: 20, y: y, width: 560, height: 20)
		return label
	}

	private func createDiagnosticRow(_ labelText: String, at point: CGPoint, in view: NSView) -> NSTextField {
		let label = NSTextField(labelWithString: labelText)
		label.font = NSFont.systemFont(ofSize: 11)
		label.frame = NSRect(x: point.x, y: point.y, width: 120, height: 18)
		view.addSubview(label)

		let valueLabel = NSTextField(labelWithString: "—")
		valueLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
		valueLabel.frame = NSRect(x: point.x + 125, y: point.y, width: 150, height: 18)
		view.addSubview(valueLabel)

		return valueLabel
	}

	// MARK: - Actions

	@objc private func debugToggleChanged() {
		let enabled = debugToggle.state == .on
		isDebugModeEnabled = enabled
		context?.onDebugModeChanged?(enabled)
	}

	@objc private func syncHistoryToggleChanged() {
		let enabled = syncHistoryToggle.state == .on
		context?.onSyncHistoryToggled?(enabled)
	}

	@objc private func viewSyncHistory() {
		guard let history = context?.syncManager?.syncHistory, !history.isEmpty else {
			appendCaptureResult("═══════════════════════════════════════════════════════════")
			appendCaptureResult("SYNC HISTORY: No records")
			appendCaptureResult("Enable 'Log sync history' and perform some brightness changes")
			appendCaptureResult("═══════════════════════════════════════════════════════════")
			return
		}

		appendCaptureResult("═══════════════════════════════════════════════════════════")
		appendCaptureResult("SYNC HISTORY (\(history.count) records)")
		appendCaptureResult("═══════════════════════════════════════════════════════════")

		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss.SSS"

		for record in history.suffix(50) { // Show last 50
			let time = formatter.string(from: record.timestamp)
			let trigger = record.trigger.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
			let disp = String(format: "%5.1f%%", record.displayBrightness * 100)
			let kb = String(format: "%5.1f%%", record.keyboardBrightness * 100)
			let status = record.success ? (record.changeNeeded ? "changed" : "no-op") : "FAILED"
			appendCaptureResult("\(time) [\(trigger)] \(disp) → \(kb) \(status) (\(record.durationMs)ms)")
		}

		appendCaptureResult("═══════════════════════════════════════════════════════════")
	}

	@objc private func openLogFile() {
		let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".twinkley-debug.log")
		if FileManager.default.fileExists(atPath: logURL.path) {
			NSWorkspace.shared.activateFileViewerSelecting([logURL])
		} else {
			let alert = NSAlert()
			alert.messageText = "Log File Not Found"
			alert.informativeText = "Debug logging may not be enabled, or no events have been logged yet."
			alert.runModal()
		}
	}

	@objc private func copyLogToClipboard() {
		let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".twinkley-debug.log")
		if let content = try? String(contentsOf: logURL, encoding: .utf8) {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(content, forType: .string)

			// Brief visual feedback
			let originalTitle = "Copy"
			if let button = window?.contentView?.subviews.compactMap({ $0 as? NSButton }).first(where: { $0.title == "Copy" }) {
				button.title = "Copied!"
				DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
					button.title = originalTitle
				}
			}
		} else {
			let alert = NSAlert()
			alert.messageText = "Log File Not Found"
			alert.informativeText = "No debug log exists yet."
			alert.runModal()
		}
	}

	// Rationale: Diagnostics refresh updates all status fields in one pass.
	// Each field update is simple; grouping them maintains the refresh logic.
	@objc private func refreshDiagnostics() { // swiftlint:disable:this function_body_length
		// Mac model
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		macModelLabel.stringValue = String(cString: model)

		// macOS version
		let osVersion = ProcessInfo.processInfo.operatingSystemVersion
		macOSVersionLabel.stringValue = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

		// Brightness values
		if let display = context?.displayProvider?.getDisplayBrightness() {
			displayBrightnessLabel.stringValue = String(format: "%.1f%%", display * 100)
		} else {
			displayBrightnessLabel.stringValue = "Error"
			displayBrightnessLabel.textColor = .systemRed
		}

		// Keyboard brightness
		if let kbBrightness = context?.keyboardController?.getKeyboardBrightness() {
			keyboardBrightnessLabel.stringValue = String(format: "%.1f%%", kbBrightness * 100)
			keyboardBrightnessLabel.textColor = .labelColor
		} else {
			keyboardBrightnessLabel.stringValue = "N/A"
			keyboardBrightnessLabel.textColor = .systemOrange
		}

		// Event tap status with health info
		if let monitor = context?.brightnessMonitor {
			let health = monitor.health
			if health.isRunning {
				var status = "Running"
				if health.reenabledCount > 0 {
					status += " (re-enabled \(health.reenabledCount)x)"
				}
				eventTapStatusLabel.stringValue = status
				eventTapStatusLabel.textColor = .systemGreen
			} else {
				eventTapStatusLabel.stringValue = "Stopped"
				eventTapStatusLabel.textColor = .systemRed
			}
		} else {
			eventTapStatusLabel.stringValue = "Not initialized"
			eventTapStatusLabel.textColor = .systemOrange
		}

		// Framework status
		let cbLoaded = Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.isLoaded ?? false
		frameworkStatusLabel.stringValue = cbLoaded ? "Loaded" : "Not loaded"
		frameworkStatusLabel.textColor = cbLoaded ? .systemGreen : .secondaryLabelColor

		// Accessibility
		let axEnabled = AXIsProcessTrusted()
		accessibilityStatusLabel.stringValue = axEnabled ? "Granted" : "Not granted"
		accessibilityStatusLabel.textColor = axEnabled ? .systemGreen : .systemRed

		// Power state
		if let provider = context?.powerSourceProvider {
			let power = PowerState.current(provider: provider)
			if power.isOnBattery {
				powerStateLabel.stringValue = "Battery \(power.batteryLevel)%"
				powerStateLabel.textColor = power.isLowBattery ? .systemOrange : .labelColor
			} else {
				powerStateLabel.stringValue = "AC Power"
				powerStateLabel.textColor = .systemGreen
			}
		} else {
			powerStateLabel.stringValue = "Unknown"
			powerStateLabel.textColor = .secondaryLabelColor
		}

		// Keyboard IDs
		if let ids = context?.keyboardController?.getKeyboardBacklightIDs(), !ids.isEmpty {
			let activeID = context?.keyboardController?.activeKeyboardID ?? 0
			if ids.count == 1 {
				keyboardIDsLabel.stringValue = String(format: "%llu", ids[0])
			} else {
				let idStrs = ids.map { id in
					id == activeID ? "[\(id)]" : "\(id)"
				}
				keyboardIDsLabel.stringValue = idStrs.joined(separator: ", ")
			}
			keyboardIDsLabel.textColor = .labelColor
		} else {
			keyboardIDsLabel.stringValue = "None found"
			keyboardIDsLabel.textColor = .systemOrange
		}
	}

	@objc private func testBrightnessRead() {
		if let brightness = context?.displayProvider?.getDisplayBrightness() {
			appendCaptureResult("✓ Display brightness read: \(String(format: "%.1f%%", brightness * 100))")
		} else {
			appendCaptureResult("✗ Failed to read display brightness")
		}
	}

	@objc private func testBrightnessWrite() {
		// Read current, write same value (no visible change, just tests API)
		if let brightness = context?.displayProvider?.getDisplayBrightness() {
			if context?.keyboardController?.setKeyboardBrightness(brightness) == true {
				appendCaptureResult("✓ Keyboard brightness write succeeded (set to \(String(format: "%.1f%%", brightness * 100)))")
			} else {
				appendCaptureResult("✗ Failed to write keyboard brightness")
			}
		} else {
			appendCaptureResult("✗ Cannot test write: display brightness unavailable")
		}
	}

	@objc private func resetEventTap() {
		appendCaptureResult("═══════════════════════════════════════════════════════════")
		appendCaptureResult("RESETTING EVENT TAP...")

		if let monitor = context?.brightnessMonitor {
			let success = monitor.restart()
			if success {
				appendCaptureResult("✓ Event tap restarted successfully")
				// Force a sync after restart
				context?.syncManager?.sync(gamma: 1.0, trigger: .manual)
				appendCaptureResult("✓ Forced brightness sync")
			} else {
				appendCaptureResult("✗ Event tap restart FAILED - check Accessibility permissions")
			}
		} else {
			appendCaptureResult("✗ Event tap not initialized")
		}

		refreshDiagnostics()
		appendCaptureResult("═══════════════════════════════════════════════════════════")
	}

	@objc private func simulateBrightnessDown() {
		appendCaptureResult("Simulating brightness DOWN key (key code 145)...")
		let script = "tell application \"System Events\" to key code 145"
		runAppleScript(script)
	}

	@objc private func simulateBrightnessUp() {
		appendCaptureResult("Simulating brightness UP key (key code 144)...")
		let script = "tell application \"System Events\" to key code 144"
		runAppleScript(script)
	}

	private func runAppleScript(_ script: String) {
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
			process.arguments = ["-e", script]

			do {
				try process.run()
				process.waitUntilExit()
				DispatchQueue.main.async {
					if process.terminationStatus == 0 {
						self?.appendCaptureResult("✓ Key simulation sent")
					} else {
						self?.appendCaptureResult("✗ Key simulation failed (exit \(process.terminationStatus))")
					}
				}
			} catch {
				DispatchQueue.main.async {
					self?.appendCaptureResult("✗ Key simulation error: \(error.localizedDescription)")
				}
			}
		}
	}

	@objc private func showEventBreakdown() {
		appendCaptureResult("═══════════════════════════════════════════════════════════")
		appendCaptureResult("EVENT TYPE BREAKDOWN (NX_SYSDEFINED keyCodes)")
		appendCaptureResult("═══════════════════════════════════════════════════════════")

		guard let monitor = context?.brightnessMonitor else {
			appendCaptureResult("Event tap not initialized")
			return
		}

		let distribution = monitor.health.sortedKeyCodeDistribution
		if distribution.isEmpty {
			appendCaptureResult("No events recorded yet. Use brightness keys to generate events.")
			appendCaptureResult("")
			appendCaptureResult("Common keyCodes:")
			appendCaptureResult("  2, 3 = Brightness (older Macs)")
			appendCaptureResult("  6, 7 = Brightness (M4 and some states)")
			appendCaptureResult("  8, 9 = Volume")
			appendCaptureResult("  14   = Media/Play")
			appendCaptureResult("═══════════════════════════════════════════════════════════")
			return
		}

		let total = distribution.reduce(0) { $0 + $1.count }
		appendCaptureResult("Total NX_SYSDEFINED events: \(total)")
		appendCaptureResult("")

		for (keyCode, count) in distribution {
			let percent = Double(count) / Double(total) * 100
			let bar = String(repeating: "█", count: min(20, Int(percent / 5)))
			let keyType = keyCodeDescription(keyCode)
			appendCaptureResult(String(format: "keyCode=%2d: %4d (%5.1f%%) %@ %@", keyCode, count, percent, bar, keyType))
		}

		appendCaptureResult("═══════════════════════════════════════════════════════════")
	}

	private func keyCodeDescription(_ keyCode: Int) -> String {
		switch keyCode {
		case 2: "(brightness down - legacy)"
		case 3: "(brightness up - legacy)"
		case 6: "(brightness - M4)"
		case 7: "(brightness - wake state)"
		case 8: "(volume down)"
		case 9: "(volume up)"
		case 10: "(mute)"
		case 14: "(media/play)"
		case 16: "(play/pause)"
		case 17: "(fast forward)"
		case 18: "(rewind)"
		case 19: "(next track)"
		case 20: "(previous track)"
		default: ""
		}
	}

	@objc private func showPermissionHelp() {
		let alert = NSAlert()
		alert.messageText = "Permission Troubleshooting"
		alert.informativeText = """
		Common issues and fixes:

		1️⃣ App in Accessibility list but not working
		   → Toggle the checkbox OFF then ON again
		   → Restart TwinK[l]ey after toggling

		2️⃣ Permission granted but still failing
		   → Check if app signature changed (rebuild)
		   → Remove app from list, re-add from ~/Applications/
		   → Quit and relaunch the app

		3️⃣ Works from Terminal but not from Finder
		   → Terminal shares its permissions with child processes
		   → App needs its own TCC entry when launched directly
		   → Grant permission specifically to TwinK[l]ey.app

		4️⃣ Event tap keeps getting disabled
		   → This is normal after sleep/wake
		   → The app auto-re-enables (check Health status)
		   → Click "Reset Event Tap" to manually restart

		5️⃣ After rebuilding the app
		   → Ad-hoc signing: Must re-grant permission each build
		   → Certificate signing: Permissions persist across builds
		"""
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Open Accessibility Settings")
		alert.addButton(withTitle: "OK")

		if alert.runModal() == .alertFirstButtonReturn {
			if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
				NSWorkspace.shared.open(url)
			}
		}
	}

	@objc private func captureDurationChanged() {
		let durations = [10, 30, 60]
		captureDuration = durations[captureTimePopup.indexOfSelectedItem]
	}

	@objc private func toggleCapture() {
		if isCapturing {
			stopCapture()
		} else {
			startCapture()
		}
	}

	private func startCapture() {
		isCapturing = true
		captureStartTime = Date()
		capturedEvents = []
		captureButton.title = "Stop Capture"
		captureTimePopup.isEnabled = false

		// Enable full keypress capture
		context?.brightnessMonitor?.fullCaptureEnabled = true

		appendCaptureResult("═══════════════════════════════════════════════════════════")
		appendCaptureResult("CAPTURE STARTED - \(captureDuration) seconds (ALL keypresses)")
		appendCaptureResult("Press any keys to capture events with brightness values...")
		appendCaptureResult("═══════════════════════════════════════════════════════════")

		// Start countdown timer
		var remaining = captureDuration
		countdownLabel.stringValue = "\(remaining)s remaining"

		captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
			guard let self else {
				timer.invalidate()
				return
			}
			remaining -= 1
			countdownLabel.stringValue = "\(remaining)s remaining"

			if remaining <= 0 {
				stopCapture()
			}
		}
	}

	private func stopCapture() {
		isCapturing = false
		captureTimer?.invalidate()
		captureTimer = nil
		captureButton.title = "Start Capture"
		captureTimePopup.isEnabled = true
		countdownLabel.stringValue = ""

		// Disable full keypress capture
		context?.brightnessMonitor?.fullCaptureEnabled = false

		appendCaptureResult("═══════════════════════════════════════════════════════════")
		appendCaptureResult("CAPTURE ENDED - \(capturedEvents.count) events captured")
		appendCaptureResult("═══════════════════════════════════════════════════════════")
	}

	@objc private func clearCaptureResults() {
		captureResultsText.string = ""
		capturedEvents = []
	}

	// Called from AppDelegate when events are received
	// Use -1 for displayBrightness/keyboardBrightness if unavailable
	@objc public func recordCapturedEvent(eventType: String, keyCode: Int, keyState: Int, displayBrightness: Float, keyboardBrightness: Float) {
		guard isCapturing else { return }

		let timestamp = Date()
		let dispStr = displayBrightness >= 0 ? String(format: "%.1f%%", displayBrightness * 100) : "N/A"
		let kbStr = keyboardBrightness >= 0 ? String(format: "%.1f%%", keyboardBrightness * 100) : "N/A"

		var line: String
		switch eventType {
		case "NX":
			let isBrightnessKey = [2, 3, 6, 7].contains(keyCode)
			let marker = isBrightnessKey ? "★" : " "
			line = "\(marker) NX      keyCode=\(String(format: "%3d", keyCode)) state=0x\(String(format: "%02x", keyState)) | Disp: \(dispStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | KB: \(kbStr.padding(toLength: 6, withPad: " ", startingAt: 0))"
		case "keyDown":
			let keyName = keyCodeToName(keyCode)
			line = "  keyDown keyCode=\(String(format: "%3d", keyCode)) (\(keyName.padding(toLength: 8, withPad: " ", startingAt: 0))) | Disp: \(dispStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | KB: \(kbStr.padding(toLength: 6, withPad: " ", startingAt: 0))"
		case "keyUp":
			let keyName = keyCodeToName(keyCode)
			line = "  keyUp   keyCode=\(String(format: "%3d", keyCode)) (\(keyName.padding(toLength: 8, withPad: " ", startingAt: 0))) | Disp: \(dispStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | KB: \(kbStr.padding(toLength: 6, withPad: " ", startingAt: 0))"
		case "flags":
			line = "  flags   changed=0x\(String(format: "%08x", keyCode)) | Disp: \(dispStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | KB: \(kbStr.padding(toLength: 6, withPad: " ", startingAt: 0))"
		default:
			line = "  \(eventType) keyCode=\(keyCode)"
		}

		capturedEvents.append((timestamp, line))
		appendCaptureResult(line)

		// Also update live brightness display
		refreshDiagnostics()
	}

	// Rationale: Switch statement maps key codes to names - inherently has many cases.
	// A dictionary would be less readable for this debugging/diagnostic context.
	private func keyCodeToName(_ keyCode: Int) -> String { // swiftlint:disable:this cyclomatic_complexity
		// Common key codes for reference
		switch keyCode {
		case 0: "A"
		case 1: "S"
		case 2: "D"
		case 3: "F"
		case 49: "Space"
		case 36: "Return"
		case 51: "Delete"
		case 53: "Escape"
		case 48: "Tab"
		case 122: "F1"
		case 120: "F2"
		case 99: "F3"
		case 118: "F4"
		case 96: "F5"
		case 97: "F6"
		case 98: "F7"
		case 100: "F8"
		case 101: "F9"
		case 109: "F10"
		case 103: "F11"
		case 111: "F12"
		case 144: "BrtUp"
		case 145: "BrtDown"
		default: "key\(keyCode)"
		}
	}

	private func appendCaptureResult(_ text: String) {
		let timestamp = ISO8601DateFormatter().string(from: Date())
		let line = "[\(timestamp.suffix(15))] \(text)\n"
		captureResultsText.string += line

		// Auto-scroll to bottom
		captureResultsText.scrollToEndOfDocument(nil)
	}

	@objc private func exportDiagnostics() {
		let savePanel = NSSavePanel()
		savePanel.allowedContentTypes = [.plainText]
		savePanel.nameFieldStringValue = "twinkley-diagnostics-\(dateString()).txt"
		savePanel.title = "Export Diagnostics"
		savePanel.message = "Save diagnostic information to a text file"

		guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

		let report = generateDiagnosticsReport()

		do {
			try report.write(to: url, atomically: true, encoding: .utf8)

			// Show success and offer to reveal in Finder
			let alert = NSAlert()
			alert.messageText = "Diagnostics Exported"
			alert.informativeText = "Diagnostic report saved successfully."
			alert.addButton(withTitle: "Show in Finder")
			alert.addButton(withTitle: "OK")

			if alert.runModal() == .alertFirstButtonReturn {
				NSWorkspace.shared.activateFileViewerSelecting([url])
			}
		} catch {
			let alert = NSAlert()
			alert.messageText = "Export Failed"
			alert.informativeText = "Could not save diagnostics: \(error.localizedDescription)"
			alert.alertStyle = .warning
			alert.runModal()
		}
	}

	private func dateString() -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd-HHmmss"
		return formatter.string(from: Date())
	}

	// Rationale: Report generation collects all diagnostic data in one place.
	// This is a self-contained diagnostic dump - splitting would fragment the output logic.
	private func generateDiagnosticsReport() -> String { // swiftlint:disable:this function_body_length cyclomatic_complexity
		var report = """
		═══════════════════════════════════════════════════════════════════
		TwinK[l]ey Diagnostics Report
		Generated: \(ISO8601DateFormatter().string(from: Date()))
		═══════════════════════════════════════════════════════════════════

		APP INFO
		────────────────────────────────────────────────────────────────────
		Version: \(AppInfo.version)
		Bundle ID: \(AppInfo.identifier)

		SYSTEM INFO
		────────────────────────────────────────────────────────────────────

		"""

		// Mac model
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		report += "Mac Model: \(String(cString: model))\n"

		// macOS version
		let osVersion = ProcessInfo.processInfo.operatingSystemVersion
		report += "macOS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)\n"

		// CPU
		size = 0
		sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
		var cpu = [CChar](repeating: 0, count: size)
		sysctlbyname("machdep.cpu.brand_string", &cpu, &size, nil, 0)
		report += "CPU: \(String(cString: cpu))\n"

		// Power state
		if let provider = context?.powerSourceProvider {
			let power = PowerState.current(provider: provider)
			report += "Power: \(power.isOnBattery ? "Battery (\(power.batteryLevel)%)" : "AC Power")\n"
		} else {
			report += "Power: Unknown\n"
		}

		// Hardware capabilities
		report += """

		HARDWARE
		────────────────────────────────────────────────────────────────────

		"""
		if let ids = context?.keyboardController?.getKeyboardBacklightIDs(), !ids.isEmpty {
			report += "Keyboard Backlight IDs: \(ids.map { String($0) }.joined(separator: ", "))\n"
			report += "Active Keyboard ID: \(context?.keyboardController?.activeKeyboardID ?? 0)\n"
		} else {
			report += "Keyboard Backlight: Not detected\n"
		}
		report += "Built-in Display: \(CGMainDisplayID())\n"

		report += """

		PERMISSIONS
		────────────────────────────────────────────────────────────────────

		"""
		let axEnabled = AXIsProcessTrusted()
		report += "Accessibility: \(axEnabled ? "✓ Granted" : "✗ Not granted")\n"

		report += """

		FRAMEWORKS
		────────────────────────────────────────────────────────────────────

		"""

		// CoreBrightness
		let cbPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework"
		let cbExists = FileManager.default.fileExists(atPath: cbPath)
		let cbBundle = Bundle(path: cbPath)
		let cbLoaded = cbBundle?.isLoaded ?? false
		report += "CoreBrightness:\n"
		report += "  Path exists: \(cbExists ? "✓" : "✗")\n"
		report += "  Loaded: \(cbLoaded ? "✓" : "✗")\n"
		if let kbcClass = NSClassFromString("KeyboardBrightnessClient") {
			report += "  KeyboardBrightnessClient: ✓ Available\n"
			let selectors = ["setBrightness:forKeyboard:", "brightnessForKeyboard:", "copyKeyboardBacklightIDs"]
			for sel in selectors {
				let responds = (kbcClass as? NSObject.Type)?.instancesRespond(to: NSSelectorFromString(sel)) ?? false
				report += "    \(sel): \(responds ? "✓" : "✗")\n"
			}
			// Test keyboard brightness read
			if let kbBrightness = context?.keyboardController?.getKeyboardBrightness() {
				report += "  GetBrightness: ✓ Working (\(String(format: "%.1f%%", kbBrightness * 100)))\n"
			} else {
				report += "  GetBrightness: ✗ Failed\n"
			}
		} else {
			report += "  KeyboardBrightnessClient: ✗ Not found\n"
		}

		// DisplayServices
		let dsPath = "/System/Library/PrivateFrameworks/DisplayServices.framework"
		let dsExists = FileManager.default.fileExists(atPath: dsPath)
		report += "\nDisplayServices:\n"
		report += "  Path exists: \(dsExists ? "✓" : "✗")\n"

		// Test display brightness read
		if let brightness = context?.displayProvider?.getDisplayBrightness() {
			report += "  GetBrightness: ✓ Working (\(String(format: "%.1f%%", brightness * 100)))\n"
		} else {
			report += "  GetBrightness: ✗ Failed\n"
		}

		report += """

		EVENT TAP STATUS
		────────────────────────────────────────────────────────────────────

		"""

		if let monitor = context?.brightnessMonitor {
			let health = monitor.health
			report += "Status: \(health.isRunning ? "Running" : "Stopped")\n"
			report += "Events received: \(health.eventsReceived)\n"
			report += "Brightness events: \(health.brightnessEventsReceived)\n"
			report += "Disabled by timeout: \(health.disabledByTimeoutCount)\n"
			report += "Disabled by user input: \(health.disabledByUserInputCount)\n"
			report += "Re-enabled count: \(health.reenabledCount)\n"
			if let created = health.createdTimestamp {
				report += "Created: \(ISO8601DateFormatter().string(from: created))\n"
			}
			if let lastEvent = health.lastEventTimestamp {
				report += "Last event: \(ISO8601DateFormatter().string(from: lastEvent))\n"
			}

			// Event type breakdown
			let distribution = health.sortedKeyCodeDistribution
			if !distribution.isEmpty {
				report += "\nKeyCode Distribution:\n"
				let total = distribution.reduce(0) { $0 + $1.count }
				for (keyCode, count) in distribution {
					let percent = Double(count) / Double(total) * 100
					let desc = keyCodeDescription(keyCode)
					report += String(format: "  keyCode=%2d: %4d (%5.1f%%) %@\n", keyCode, count, percent, desc)
				}
			}
		} else {
			report += "Status: Not initialized\n"
		}

		// Include debug log if it exists
		let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".twinkley-debug.log")
		if let logContent = try? String(contentsOf: logURL, encoding: .utf8) {
			report += """

			DEBUG LOG (last 100 lines)
			────────────────────────────────────────────────────────────────────

			"""
			let lines = logContent.components(separatedBy: "\n")
			let lastLines = lines.suffix(100)
			report += lastLines.joined(separator: "\n")
		}

		// Include sync history if available
		if let history = context?.syncManager?.syncHistory, !history.isEmpty {
			report += """


			SYNC HISTORY (\(history.count) records)
			────────────────────────────────────────────────────────────────────

			"""
			let formatter = DateFormatter()
			formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

			for record in history {
				let time = formatter.string(from: record.timestamp)
				let trigger = record.trigger.rawValue
				let disp = String(format: "%.1f%%", record.displayBrightness * 100)
				let kb = String(format: "%.1f%%", record.keyboardBrightness * 100)
				let status = record.success ? (record.changeNeeded ? "changed" : "no-change") : "FAILED"
				report += "\(time) [\(trigger)] display=\(disp) -> keyboard=\(kb) \(status) (\(record.durationMs)ms)\n"
			}
		}

		// Include captured events if any
		if !capturedEvents.isEmpty {
			report += """


			CAPTURED EVENTS (\(capturedEvents.count) events)
			────────────────────────────────────────────────────────────────────

			"""
			for (timestamp, line) in capturedEvents {
				report += "[\(ISO8601DateFormatter().string(from: timestamp))] \(line)\n"
			}
		}

		report += """

		═══════════════════════════════════════════════════════════════════
		End of Report
		═══════════════════════════════════════════════════════════════════
		"""

		return report
	}

	private func startDiagnosticsRefresh() {
		// Refresh diagnostics every 2 seconds when window is visible
		Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
			guard let self, window?.isVisible == true else { return }
			refreshDiagnostics()
		}
	}

	public var isCaptureActive: Bool {
		isCapturing
	}
}

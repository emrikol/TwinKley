// TwinKleyUI - Dynamically loaded UI components
// This module is loaded on-demand to keep the main binary small

import AppKit
import TwinKleyCore

/// Entry point for the UI module - provides factory methods for creating windows
@objc public class TwinKleyUILoader: NSObject {
	@objc public static let shared = TwinKleyUILoader()

	private override init() {
		super.init()
	}

	/// Called when the module is loaded
	@objc public func initialize() {
		// Module loaded successfully
	}

	// MARK: - Window Factories

	/// Create a new Debug window controller
	@objc public func createDebugWindow() -> AnyObject {
		DebugWindowController()
	}

	/// Create a new Preferences window controller
	@objc public func createPreferencesWindow() -> AnyObject {
		PreferencesWindowController()
	}

	/// Create a new About window controller
	@objc public func createAboutWindow() -> AnyObject {
		AboutWindowController()
	}

	// MARK: - CLI Utilities

	/// Get help text for CLI
	@objc public func getHelpText() -> String {
		DebugOptions.helpText
	}

	/// Parse debug options from command line
	@objc public func parseDebugOptions() -> [String: Any] {
		let options = DebugOptions.fromCommandLine()
		return [
			"loggingEnabled": options.loggingEnabled,
			"captureKeypresses": options.captureKeypresses,
			"captureDuration": options.captureDuration,
			"verboseEvents": options.verboseEvents,
			"showBrightnessInMenu": options.showBrightnessInMenu,
			"trackEventTapHealth": options.trackEventTapHealth,
			"logSyncHistory": options.logSyncHistory
		]
	}

	// MARK: - Settings Management

	/// Create a new SettingsManager instance
	@objc public func createSettingsManager() -> AnyObject {
		SettingsManager()
	}

	// MARK: - Dialog Utilities

	/// Show the welcome dialog for first launch
	@objc public func showWelcomeDialog() {
		let alert = NSAlert()
		alert.messageText = "Welcome to \(AppInfo.shortName)!"
		alert.informativeText = """
		TwinKley automatically syncs your keyboard backlight to match your display brightness.

		🔒 Privacy First: Zero data collection, everything runs locally
		⚡️ Live Sync: Instant response to brightness changes
		🔋 Battery Smart: Optional power-saving modes

		To get started:
		1. Grant Accessibility permission (required)
		2. Adjust brightness - your keyboard will follow!

		Settings are in the menu bar icon.
		"""
		alert.alertStyle = .informational
		alert.icon = NSApp.applicationIconImage
		alert.addButton(withTitle: "Grant Permission")
		alert.addButton(withTitle: "Later")
		_ = alert.runModal()
	}

	/// Show the accessibility permission prompt
	/// Returns true if user clicked "Open Settings"
	@objc public func showAccessibilityPrompt() -> Bool {
		let alert = NSAlert()
		alert.messageText = "Accessibility Permission Required"
		alert.informativeText = """
		\(AppInfo.shortName) needs Accessibility permission to detect \
		brightness key presses and sync your keyboard backlight.

		Without this permission, only timed sync will work.

		Click "Open Settings" and add \(AppInfo.shortName) to the list, \
		or toggle it off and on if it's already there.

		You may need to restart the app after granting permission.
		"""
		alert.alertStyle = .warning
		alert.icon = NSApp.applicationIconImage
		alert.addButton(withTitle: "Open Settings")
		alert.addButton(withTitle: "Later")

		let response = alert.runModal()
		if response == .alertFirstButtonReturn {
			if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
				NSWorkspace.shared.open(url)
			}
			return true
		}
		return false
	}

	// MARK: - CLI Utilities

	/// Run health check and print results
	/// Returns exit code (0 = success, 1 = issues detected)
	@objc public func runHealthCheck() -> Int32 {
		print("TwinK[l]ey Health Check")
		print("=======================")
		print("")

		// Check Accessibility permission (both API and actual tap test)
		let apiSaysGranted = AXIsProcessTrusted()

		// Try to create a test event tap - this is the real test
		let testTap = CGEvent.tapCreate(
			tap: .cgSessionEventTap,
			place: .headInsertEventTap,
			options: .defaultTap,
			eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
			callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
			userInfo: nil
		)
		let tapWorks = testTap != nil
		if let tap = testTap {
			CFMachPortInvalidate(tap)
		}

		// Detect stale permission (API says yes but tap fails)
		let hasAccessibility = tapWorks
		if apiSaysGranted && !tapWorks {
			print("Accessibility: ⚠️  STALE (API says granted but tap fails)")
			print("  → Remove and re-add TwinKley in System Settings > Privacy > Accessibility")
		} else if tapWorks {
			print("Accessibility: ✓ Granted")
		} else {
			print("Accessibility: ✗ Not granted")
		}

		// Check frameworks
		let coreBrightnessPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework"
		let displayServicesPath = "/System/Library/PrivateFrameworks/DisplayServices.framework"
		let cbExists = FileManager.default.fileExists(atPath: coreBrightnessPath)
		let dsExists = FileManager.default.fileExists(atPath: displayServicesPath)
		print("CoreBrightness: \(cbExists ? "✓ Available" : "✗ Not found")")
		print("DisplayServices: \(dsExists ? "✓ Available" : "✗ Not found")")

		// Check Mac model
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		print("Mac Model: \(String(cString: model))")

		// Overall status
		print("")
		if hasAccessibility && cbExists && dsExists {
			print("Status: ✓ All systems ready")
			return 0
		} else {
			print("Status: ✗ Issues detected (see above)")
			return 1
		}
	}

	/// Open help URL in browser
	@objc public func openHelp() {
		if let url = URL(string: "\(AppInfo.githubURL)#readme") {
			NSWorkspace.shared.open(url)
		}
	}

	/// Show update privacy notice dialog
	/// Returns true if user wants to proceed with update check
	@objc public func showUpdatePrivacyNotice() -> Bool {
		let alert = NSAlert()
		alert.messageText = "Update Check Privacy Notice"
		alert.informativeText = """
		Checking for updates connects to GitHub's servers.

		When checking for updates, the following information is sent to GitHub:
		• Your IP address
		• Your macOS version
		• The app version

		We do not control GitHub's privacy practices. For more information, see GitHub's Privacy Statement.

		Do you want to check for updates?
		"""
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Check for Updates")
		alert.addButton(withTitle: "Cancel")

		return alert.runModal() == .alertFirstButtonReturn
	}

	/// Show capture privacy warning
	@objc public func showCapturePrivacyWarning(duration: Int) {
		print("""

		⚠️  PRIVACY WARNING ⚠️
		═══════════════════════════════════════════════════════════════════

		Keypress capture is ENABLED (--capture flag detected).

		This captures ALL system key events for diagnostic purposes.
		DO NOT type passwords or sensitive information while capture is active.

		Duration: \(duration) seconds
		Log file: ~/.twinkley-debug.log

		Press Ctrl+C to cancel, or wait for app to start...
		═══════════════════════════════════════════════════════════════════

		""")

		// Give user 3 seconds to cancel
		sleep(3)
	}
}

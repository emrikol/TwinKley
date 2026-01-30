// swiftlint:disable file_length
// Rationale: main.swift is the single-file app architecture per CLAUDE.md design.
// Splitting would add complexity contrary to the "simplicity" principle.

import AppKit
import CoreGraphics
import IOKit.ps
import TwinKleyCore
#if !APP_STORE
import Sparkle
#endif

// MARK: - Debug Mode (lazy loaded from UI library when needed)

// Simple debug flags that can be checked without loading UI library
private let debugFlagPresent = CommandLine.arguments.contains("--debug") || CommandLine.arguments.contains("-d")
private let verboseFlagPresent = CommandLine.arguments.contains("--verbose") || CommandLine.arguments.contains("-v")
private let captureFlagPresent = CommandLine.arguments.contains { $0.hasPrefix("--capture") }
private let helpFlagPresent = CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h")
private let showBrightnessFlagPresent = CommandLine.arguments.contains("--show-brightness")
private let syncHistoryFlagPresent = CommandLine.arguments.contains("--sync-history")

// Debug enabled if any debug flag is present (simple check, no UI library needed)
private var debugEnabled = debugFlagPresent || verboseFlagPresent || syncHistoryFlagPresent

// Minimal debug options struct (populated from CLI flags without loading UI library)
private struct DebugOptionsMinimal {
	var loggingEnabled: Bool
	var captureKeypresses: Bool
	var captureDuration: Int
	var verboseEvents: Bool
	var showBrightnessInMenu: Bool
	var logSyncHistory: Bool

	static func fromFlags() -> DebugOptionsMinimal {
		var duration = 30
		// Parse --capture=SECONDS if present
		for arg in CommandLine.arguments where arg.hasPrefix("--capture=") {
			let durationStr = String(arg.dropFirst("--capture=".count))
			duration = Int(durationStr) ?? 30
		}
		return DebugOptionsMinimal(
			loggingEnabled: debugFlagPresent || verboseFlagPresent || syncHistoryFlagPresent,
			captureKeypresses: captureFlagPresent,
			captureDuration: duration,
			verboseEvents: verboseFlagPresent,
			showBrightnessInMenu: showBrightnessFlagPresent,
			logSyncHistory: syncHistoryFlagPresent
		)
	}
}

private var debugOptions = DebugOptionsMinimal.fromFlags()

// Cache for UI library handle (loaded once, reused)
private var _uiLibraryHandle: UnsafeMutableRawPointer?
private var _uiLoader: NSObject?

/// Load UI library and get the loader object (for CLI utilities and windows)
private func getUILoader() -> NSObject? {
	if let loader = _uiLoader { return loader }

	// Load dylib if not already loaded
	if _uiLibraryHandle == nil {
		let bundlePath = Bundle.main.privateFrameworksPath ?? ""
		let bundleLibPath = "\(bundlePath)/libTwinKleyUI.dylib"
		let execPath = Bundle.main.executablePath ?? ""
		let execDir = (execPath as NSString).deletingLastPathComponent
		let debugLibPath = "\(execDir)/libTwinKleyUI.dylib"

		if FileManager.default.fileExists(atPath: bundleLibPath) {
			_uiLibraryHandle = dlopen(bundleLibPath, RTLD_NOW)
		} else if FileManager.default.fileExists(atPath: debugLibPath) {
			_uiLibraryHandle = dlopen(debugLibPath, RTLD_NOW)
		}
	}

	guard _uiLibraryHandle != nil else { return nil }

	// Get the loader instance
	if let loaderClass = NSClassFromString("TwinKleyUI.TwinKleyUILoader") as? NSObject.Type,
	   let loader = loaderClass.value(forKey: "shared") as? NSObject
	{
		_uiLoader = loader
		return loader
	}
	return nil
}

// Debug log file for capturing output when running in background
private var debugLogURL: URL? {
	guard debugEnabled else { return nil }
	return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".twinkley-debug.log")
}

// Handle --help flag (loads UI library for full help text)
private func handleHelpIfNeeded() {
	guard helpFlagPresent else { return }
	print("\(AppInfo.name) v\(AppInfo.version)")
	print("")
	print("Usage: TwinKley [OPTIONS]")
	print("")
	// Load UI library for full help text
	if let loader = getUILoader(),
	   let helpText = loader.perform(NSSelectorFromString("getHelpText"))?.takeUnretainedValue() as? String
	{
		print(helpText)
	} else {
		// Fallback help if UI library not available
		print("Debug Options:")
		print("  --debug, -d     Enable debug logging")
		print("  --verbose, -v   Log all system events")
		print("  --help, -h      Show this help")
	}
	exit(0)
}

// Handle --health-check flag (uses UI library for most output)
private func handleHealthCheck() -> Bool {
	guard CommandLine.arguments.contains("--health-check") else { return false }

	// Try to use UI library for health check
	if let loader = getUILoader() {
		// Run health check from UI library (handles accessibility, frameworks, mac model)
		let selector = NSSelectorFromString("runHealthCheck")

		// Check if method exists (avoid perform() for primitives - it can't distinguish 0 from nil)
		guard loader.responds(to: selector) else {
			print("⚠️  Health check method unavailable")
			exit(1)
		}

		// Call using objc_msgSend with typed signature to properly handle Int32 return
		typealias HealthCheckFunc = @convention(c) (AnyObject, Selector) -> Int32
		let msgSend = unsafeBitCast(dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend"), to: HealthCheckFunc.self)
		let code = msgSend(loader, selector)

		// Add display brightness check (requires main binary's brightness API)
		if let getFunc = getBrightnessFunc {
			var brightness: Float = 0
			let result = getFunc(CGMainDisplayID(), &brightness)
			if result == 0 {
				print("Display Brightness: \(String(format: "%.1f%%", brightness * 100))")
			} else {
				print("Display Brightness: ✗ Read failed")
			}
		} else {
			print("Display Brightness: ✗ API unavailable")
		}

		exit(code)
	}

	// Fallback: minimal health check without UI library
	print("TwinK[l]ey Health Check (minimal)")
	print("=================================")
	let hasAccessibility = AXIsProcessTrusted()
	print("Accessibility: \(hasAccessibility ? "✓ Granted" : "✗ Not granted")")
	exit(hasAccessibility ? 0 : 1)
}

func debugLog(_ message: String) {
	guard debugEnabled else { return }
	let timestamp = Date().ISO8601Format()
	let line = "[\(timestamp)] \(message)\n"
	print(line, terminator: "")
	// Also write to log file for background debugging
	if let url = debugLogURL,
	   let data = line.data(using: .utf8)
	{
		if FileManager.default.fileExists(atPath: url.path) {
			if let handle = try? FileHandle(forWritingTo: url) {
				handle.seekToEndOfFile()
				handle.write(data)
				handle.closeFile()
			}
		} else {
			try? data.write(to: url)
		}
	}
}

// MARK: - Power Source Provider (IOKit implementation)

/// System implementation of PowerSourceProvider using IOKit
struct SystemPowerSourceProvider: PowerSourceProvider {
	func getPowerSourcesInfo() -> [[String: Any]]? {
		guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
			  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else
		{
			return nil
		}

		var result: [[String: Any]] = []
		for source in sources {
			if let info = IOPSGetPowerSourceDescription(snapshot, source)?
				.takeUnretainedValue() as? [String: Any]
			{
				// Map IOKit keys to our portable keys
				var mapped: [String: Any] = [:]
				if let state = info[kIOPSPowerSourceStateKey] as? String {
					mapped[PowerState.powerSourceStateKey] = state == kIOPSBatteryPowerValue
						? PowerState.batteryPowerValue : state
				}
				if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
					mapped[PowerState.currentCapacityKey] = capacity
				}
				result.append(mapped)
			}
		}
		return result.isEmpty ? nil : result
	}
}

/// Shared power source provider instance
private let powerSourceProvider = SystemPowerSourceProvider()

// MARK: - Power State Monitor (notification-based, no polling)

// Note: PowerState struct is defined in TwinKleyCore

class PowerStateMonitor {
	var onPowerStateChanged: ((PowerState) -> Void)?
	private var runLoopSource: CFRunLoopSource?

	func start() {
		// Register for power source change notifications (no polling!)
		let context = Unmanaged.passUnretained(self).toOpaque()
		runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
			guard let context else { return }
			let monitor = Unmanaged<PowerStateMonitor>.fromOpaque(context).takeUnretainedValue()
			let state = PowerState.current(provider: powerSourceProvider)
			debugLog("Power state changed: onBattery=\(state.isOnBattery), level=\(state.batteryLevel)%")
			DispatchQueue.main.async {
				monitor.onPowerStateChanged?(state)
			}
		}, context).takeRetainedValue()

		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
		debugLog("Power state monitoring started")
	}

	func stop() {
		if let source = runLoopSource {
			CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
		}
		runLoopSource = nil
	}
}

// MARK: - Display Brightness (using DisplayServices private framework)

// Cache the framework handle to avoid repeated dlopen/dlclose
private var displayServicesHandle: UnsafeMutableRawPointer? = dlopen(
	"/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
	RTLD_NOW
)

private var getBrightnessFunc: ((UInt32, UnsafeMutablePointer<Float>) -> Int32)? = {
	guard let handle = displayServicesHandle,
		  let sym = dlsym(handle, "DisplayServicesGetBrightness") else
	{
		return nil
	}
	typealias GetBrightnessFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
	return unsafeBitCast(sym, to: GetBrightnessFunc.self)
}()

/// Wrapper for display brightness that conforms to BrightnessProvider protocol
class DisplayBrightnessProvider: BrightnessProvider, DisplayBrightnessProtocol {
	func getDisplayBrightness() -> Float? {
		guard let getFunc = getBrightnessFunc else { return nil }
		var brightness: Float = 0
		let result = getFunc(CGMainDisplayID(), &brightness)
		return result == 0 ? brightness : nil
	}
}

// MARK: - Keyboard Brightness (using KeyboardBrightnessClient - lazy loaded)

class KeyboardBrightnessController: BrightnessController, KeyboardBrightnessProtocol {
	private var client: AnyObject?
	private var keyboardID: UInt64 = 0
	private var isInitialized = false

	private let setBrightnessSelector = NSSelectorFromString("setBrightness:forKeyboard:")
	private let getBrightnessSelector = NSSelectorFromString("brightnessForKeyboard:")
	private let getKeyboardIDsSelector = NSSelectorFromString("copyKeyboardBacklightIDs")

	// Cache objc_msgSend pointer to avoid repeated dlsym lookups
	private static let objcMsgSendPtr: UnsafeMutableRawPointer = dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend")!

	// Lazy initialization - only load framework when first needed
	private func ensureInitialized() -> Bool {
		if isInitialized { return client != nil }
		isInitialized = true

		guard let bundle = Bundle(
			path: "/System/Library/PrivateFrameworks/CoreBrightness.framework"
		), bundle.load() else {
			debugLog("Failed to load CoreBrightness framework")
			return false
		}

		guard let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
			debugLog("KeyboardBrightnessClient class not found")
			return false
		}

		client = clientClass.init()

		if let client,
		   client.responds(to: getKeyboardIDsSelector),
		   let ids = client.perform(getKeyboardIDsSelector)?.takeUnretainedValue() as? [NSNumber],
		   let firstID = ids.first
		{
			keyboardID = firstID.uint64Value
		}

		return client != nil
	}

	func setKeyboardBrightness(_ level: Float) -> Bool {
		guard ensureInitialized(),
			  let client,
			  client.responds(to: setBrightnessSelector) else
		{
			return false
		}

		typealias SetBrightnessFunc = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
		let setFunc = unsafeBitCast(Self.objcMsgSendPtr, to: SetBrightnessFunc.self)

		return setFunc(client, setBrightnessSelector, level, keyboardID)
	}

	/// Get current keyboard brightness (0.0 - 1.0)
	func getKeyboardBrightness() -> Float? {
		guard ensureInitialized(),
			  let client,
			  client.responds(to: getBrightnessSelector) else
		{
			return nil
		}

		typealias GetBrightnessFunc = @convention(c) (AnyObject, Selector, UInt64) -> Float
		let getFunc = unsafeBitCast(Self.objcMsgSendPtr, to: GetBrightnessFunc.self)

		return getFunc(client, getBrightnessSelector, keyboardID)
	}

	var isReady: Bool {
		ensureInitialized()
	}

	/// Get all keyboard backlight IDs (for diagnostics)
	func getKeyboardBacklightIDs() -> [UInt64] {
		guard ensureInitialized(),
			  let client,
			  client.responds(to: getKeyboardIDsSelector),
			  let ids = client.perform(getKeyboardIDsSelector)?.takeUnretainedValue() as? [NSNumber] else
		{
			return []
		}
		return ids.map(\.uint64Value)
	}

	/// Get the currently active keyboard ID
	var activeKeyboardID: UInt64 {
		_ = ensureInitialized()
		return keyboardID
	}
}

// MARK: - Brightness Key Event Monitor

class BrightnessKeyMonitor: BrightnessMonitorProtocol {
	private var eventTap: CFMachPort?
	private var runLoopSource: CFRunLoopSource?
	var onBrightnessKeyPressed: (() -> Void)?

	// Callback for raw event capture (debug window)
	// Parameters: (eventType, keyCode, keyState)
	// - eventType: "NX" for NX_SYSDEFINED, "keyDown", "keyUp", "flags"
	// - keyCode: For NX events, the media key code; for key events, the keyboard key code
	// - keyState: State flags (for NX) or key code (for key events)
	var onEventCaptured: ((String, Int, Int) -> Void)?

	// When true, capture ALL key events (not just NX_SYSDEFINED)
	// This is enabled by the debug window during capture sessions
	var fullCaptureEnabled = false

	// Event tap health tracking
	var health = EventTapHealth()

	// NX keyCodes to treat as brightness events (configurable via settings)
	var brightnessKeyCodes: [Int] = Settings.brightnessKeyCodesDefault

	func start() -> Bool {
		health.createdTimestamp = Date()

		// We need accessibility permissions for event tap
		// Listen for keyDown, keyUp, and NX_SYSDEFINED (14) events
		let eventMask = (1 << CGEventType.keyDown.rawValue) |
			(1 << CGEventType.keyUp.rawValue) |
			(1 << 14) | // NX_SYSDEFINED
			(1 << CGEventType.flagsChanged.rawValue)

		guard let tap = CGEvent.tapCreate(
			tap: .cgSessionEventTap,
			place: .headInsertEventTap,
			options: .defaultTap, // Use Accessibility permission instead of Input Monitoring
			eventsOfInterest: CGEventMask(eventMask),
			callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
				guard let refcon else { return Unmanaged.passUnretained(event) }
				let monitor = Unmanaged<BrightnessKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
				monitor.handleEvent(type: type, event: event)
				return Unmanaged.passUnretained(event)
			},
			userInfo: Unmanaged.passUnretained(self).toOpaque()
		) else {
			debugLog("Failed to create event tap - need Accessibility permissions")
			return false
		}

		eventTap = tap
		runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
		CGEvent.tapEnable(tap: tap, enable: true)

		health.isRunning = true
		return true
	}

	// Rationale: Event handling logic is inherently sequential and interconnected.
	// Breaking it up would obscure the event flow and make debugging harder.
	private func handleEvent(type: CGEventType, event: CGEvent) { // swiftlint:disable:this function_body_length
		// Handle event tap being disabled by macOS (happens after sleep/wake, timeout, etc.)
		// kCGEventTapDisabledByTimeout = 0xFFFFFFFE, kCGEventTapDisabledByUserInput = 0xFFFFFFFD
		if type.rawValue == 0xFFFF_FFFE || type.rawValue == 0xFFFF_FFFD {
			let isTimeout = type.rawValue == 0xFFFF_FFFE
			if isTimeout {
				health.disabledByTimeoutCount += 1
			} else {
				health.disabledByUserInputCount += 1
			}
			health.lastDisabledTimestamp = Date()

			debugLog("⚠️  Event tap disabled by macOS (type=\(type.rawValue)) - re-enabling")
			if let tap = eventTap {
				CGEvent.tapEnable(tap: tap, enable: true)
				health.reenabledCount += 1
			}
			return
		}

		// Track event receipt
		health.eventsReceived += 1
		health.lastEventTimestamp = Date()

		// Capture regular key events when full capture is enabled
		if fullCaptureEnabled {
			if type == .keyDown {
				let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
				DispatchQueue.main.async { [weak self] in
					self?.onEventCaptured?("keyDown", keyCode, 0)
				}
			} else if type == .keyUp {
				let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
				DispatchQueue.main.async { [weak self] in
					self?.onEventCaptured?("keyUp", keyCode, 0)
				}
			} else if type == .flagsChanged {
				let flags = Int(event.flags.rawValue)
				DispatchQueue.main.async { [weak self] in
					self?.onEventCaptured?("flags", flags, 0)
				}
			}
		}

		// Check for regular key events (Fn+F1/F2)
		if type == .keyDown {
			let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
			// F1 = 122, F2 = 120 (when used with Fn for brightness)
			// key codes 144/145 are brightness up/down on some keyboards
			if keyCode == 122 || keyCode == 120 || keyCode == 145 || keyCode == 144 {
				health.brightnessEventsReceived += 1
				debugLog("Brightness key (F1/F2) detected")
				DispatchQueue.main.async { [weak self] in
					self?.onBrightnessKeyPressed?()
				}
			}
		}

		// Check for NX_SYSDEFINED events (media keys including brightness)
		if type.rawValue == 14 { // NX_SYSDEFINED
			let data1 = event.getIntegerValueField(CGEventField(rawValue: 85)!) // data1 field
			let keyCode = Int((data1 >> 16) & 0xFF)
			let keyState = Int((data1 >> 8) & 0xFF)

			// Track keyCode distribution for diagnostics
			health.trackKeyCode(keyCode)

			// Notify capture callback (for debug window) - always capture NX events
			DispatchQueue.main.async { [weak self] in
				self?.onEventCaptured?("NX", keyCode, keyState)
			}

			// Check if it's brightness (keyCodes configurable via ~/.twinkley.json)
			if brightnessKeyCodes.contains(keyCode) {
				health.brightnessEventsReceived += 1
				debugLog("Brightness event detected (keyCode=\(keyCode))")
				DispatchQueue.main.async { [weak self] in
					self?.onBrightnessKeyPressed?()
				}
			}
		}
	}

	func stop() {
		if let tap = eventTap {
			CGEvent.tapEnable(tap: tap, enable: false)
			CFMachPortInvalidate(tap)
		}
		if let source = runLoopSource {
			CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
		}
		eventTap = nil
		runLoopSource = nil
		health.isRunning = false
	}

	/// Restart the event tap (stop and start again)
	/// Returns true if restart was successful
	@discardableResult
	func restart() -> Bool {
		debugLog("Restarting event tap...")
		stop()
		// Brief pause to ensure clean teardown
		Thread.sleep(forTimeInterval: 0.1)
		let result = start()
		debugLog("Event tap restart: \(result ? "success" : "failed")")
		return result
	}
}

// MARK: - Brightness Sync Manager (wrapper around Core with debug logging)

class AppBrightnessSyncManager: BrightnessSyncProtocol {
	private let keyboard: KeyboardBrightnessController
	private let displayProvider: DisplayBrightnessProvider
	private lazy var coreSyncManager: TwinKleyCore.BrightnessSyncManager = .init(
		brightnessProvider: displayProvider,
		brightnessController: keyboard
	)

	// Sync history for diagnostics (keep last 100 records)
	private(set) var syncHistory: [SyncRecord] = []
	private let maxHistoryCount = 100
	var syncHistoryEnabled = false

	init(displayProvider: DisplayBrightnessProvider, keyboardController: KeyboardBrightnessController) {
		self.displayProvider = displayProvider
		keyboard = keyboardController
	}

	/// Sync keyboard brightness to display brightness with debug logging
	/// - Parameters:
	///   - gamma: Gamma correction exponent (1.0 = linear, >1.0 = power curve)
	///   - trigger: What triggered this sync (for history logging)
	func sync(gamma: Double = 1.0, trigger: SyncTrigger = .manual) {
		let startTime = Date()

		let previousBrightness = coreSyncManager.lastSyncedBrightness

		// Perform sync (reads display brightness internally)
		let result = coreSyncManager.sync(gamma: gamma)

		// Use cached display brightness from core manager (avoids double-read)
		let displayBrightness = coreSyncManager.lastSyncedDisplayBrightness
		let displayBrightnessValid = displayBrightness >= 0

		let durationMs = Int(Date().timeIntervalSince(startTime) * 1_000)
		let keyboardBrightness = coreSyncManager.lastSyncedBrightness
		let changeNeeded = keyboardBrightness != previousBrightness

		// Log if brightness changed
		if displayBrightnessValid, changeNeeded {
			debugLog("Sync: display=\(String(format: "%.4f", displayBrightness)) -> keyboard=\(String(format: "%.4f", keyboardBrightness)) (γ=\(String(format: "%.1f", gamma))) \(result ? "OK" : "FAILED")")
		}

		// Record to history if enabled
		if syncHistoryEnabled, displayBrightnessValid {
			let record = SyncRecord(
				timestamp: startTime,
				trigger: trigger,
				displayBrightness: displayBrightness,
				keyboardBrightness: keyboardBrightness,
				gamma: gamma,
				success: result,
				durationMs: durationMs,
				changeNeeded: changeNeeded
			)
			syncHistory.append(record)

			// Trim history if too long
			if syncHistory.count > maxHistoryCount {
				syncHistory.removeFirst(syncHistory.count - maxHistoryCount)
			}

			if debugOptions.logSyncHistory {
				debugLog("SyncHistory: \(trigger.rawValue) display=\(String(format: "%.1f%%", displayBrightness * 100)) -> kb=\(String(format: "%.1f%%", keyboardBrightness * 100)) \(changeNeeded ? "changed" : "no-change") \(durationMs)ms")
			}
		}
	}

	func clearHistory() {
		syncHistory.removeAll()
	}

	var isReady: Bool {
		keyboard.isReady
	}
}

// MARK: - Menu Bar Icon

private func createMenuBarIcon() -> NSImage {
	// Load pre-rendered PDF from bundle (smaller than inline drawing code)
	let resourcePath = Bundle.main.resourcePath ?? ""
	let iconPath = "\(resourcePath)/MenuBarIcon.pdf"

	if let icon = NSImage(contentsOfFile: iconPath) {
		icon.isTemplate = true
		return icon
	}

	// Fallback: minimal placeholder if PDF not found
	debugLog("Menu bar icon not found at \(iconPath), using fallback")
	let fallback = NSImage(size: NSSize(width: 18, height: 18))
	fallback.isTemplate = true
	return fallback
}

// MARK: - Settings Adapter

/// Adapter to expose local settings via SettingsProtocol for UI windows
private class SettingsProtocolAdapter: SettingsProtocol {
	private let getSettings: () -> Settings
	private let setSettings: (Settings) -> Void

	init(getSettings: @escaping () -> Settings, setSettings: @escaping (Settings) -> Void) {
		self.getSettings = getSettings
		self.setSettings = setSettings
	}

	var settings: Settings { getSettings() }

	func update(_ block: (inout Settings) -> Void) {
		var currentSettings = getSettings()
		block(&currentSettings)
		setSettings(currentSettings)
	}
}

// MARK: - App Delegate

// Rationale: AppDelegate is the central coordinator for this single-purpose utility.
// Splitting into multiple classes would fragment the straightforward control flow.
class AppDelegate: NSObject, NSApplicationDelegate { // swiftlint:disable:this type_body_length
	private var statusItem: NSStatusItem!
	private var keyMonitor: BrightnessKeyMonitor?
	private var powerMonitor: PowerStateMonitor?
	private var currentPowerState = PowerState.current(provider: powerSourceProvider)
	private var keypressSyncMenuItem: NSMenuItem!
	private var timedSyncMenuItem: NSMenuItem!
	private var fallbackTimer: Timer?

	// Settings loaded at startup via minimal SettingsLoader (no full SettingsManager needed in main binary)
	private var settings = SettingsLoader.load()
	private func saveSettings() { SettingsLoader.save(settings) }

	// Adapter to expose settings via SettingsProtocol for UI windows
	private lazy var settingsAdapter = SettingsProtocolAdapter(
		getSettings: { [weak self] in self?.settings ?? Settings.default },
		setSettings: { [weak self] newSettings in
			self?.settings = newSettings
			self?.saveSettings()
		}
	)

	// Lazy-loaded brightness controllers - shared between syncManager and debug window
	private lazy var displayProvider: DisplayBrightnessProvider = .init()
	private lazy var keyboardController: KeyboardBrightnessController = .init()
	private lazy var syncManager: AppBrightnessSyncManager = .init(
		displayProvider: displayProvider,
		keyboardController: keyboardController
	)

	#if !APP_STORE
	// Lazy-load Sparkle only when needed (saves ~2-3 MB during normal operation)
	private lazy var updaterController: SPUStandardUpdaterController = {
		debugLog("Lazy-loading Sparkle framework...")
		return SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)
	}()
	#endif

	private var preferencesWindow: PreferencesWindowProtocol?
	private var debugWindow: DebugWindowProtocol?
	private var aboutWindow: AboutWindowProtocol?

	// Debouncer for keypress sync - coalesces rapid key presses into fewer syncs
	private let keypressSyncDebouncer = Debouncer(delay: 0.3)

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Note: Sparkle is now lazy-loaded only when user checks for updates or opens Preferences
		// This saves ~2-3 MB of memory during normal brightness sync operation

		// Enable sync history if requested via CLI
		if debugOptions.logSyncHistory {
			syncManager.syncHistoryEnabled = true
		}

		setupStatusItem()
		checkFirstLaunch()
		checkAccessibilityPermission()
		setupBrightnessMonitor()
		setupObservers()
		syncManager.sync(gamma: settings.brightnessGamma, trigger: .startup)
	}

	private func checkFirstLaunch() {
		if !settings.hasLaunchedBefore {
			settings.hasLaunchedBefore = true
			saveSettings()
			showWelcomeDialog()
		}
	}

	private func showWelcomeDialog() {
		// Use UI library for dialog (keeps main binary small)
		if let loader = getUILoader() {
			_ = loader.perform(NSSelectorFromString("showWelcomeDialog"))
		}
	}

	/// Test if event tap actually works (more reliable than AXIsProcessTrusted)
	/// AXIsProcessTrusted can return true with stale TCC entries after code signature changes
	private func testEventTapPermission() -> (apiSaysGranted: Bool, tapWorks: Bool) {
		let apiSaysGranted = AXIsProcessTrusted()

		// Try to create a minimal test tap - this is the real test
		let testTap = CGEvent.tapCreate(
			tap: .cgSessionEventTap,
			place: .headInsertEventTap,
			options: .defaultTap,
			eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
			callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
			userInfo: nil
		)

		let tapWorks = testTap != nil

		// Clean up test tap
		if let tap = testTap {
			CFMachPortInvalidate(tap)
		}

		return (apiSaysGranted, tapWorks)
	}

	private func checkAccessibilityPermission() {
		// .defaultTap requires Accessibility permission (not Input Monitoring)
		let (apiSaysGranted, tapWorks) = testEventTapPermission()

		debugLog("Accessibility permission: API=\(apiSaysGranted), tapWorks=\(tapWorks)")

		if !tapWorks {
			if apiSaysGranted {
				// Stale TCC entry - signature changed but permission wasn't invalidated
				debugLog("⚠️  Stale accessibility permission detected - need to re-grant")
			}
			showAccessibilityPrompt()
		}
	}

	private func showAccessibilityPrompt() {
		// Use UI library for dialog (keeps main binary small)
		if let loader = getUILoader() {
			_ = loader.perform(NSSelectorFromString("showAccessibilityPrompt"))
		}
	}

	private var showBrightnessInMenu = false
	private var brightnessDisplayTimer: Timer?

	// Rationale: Menu setup is a cohesive unit - all menu items defined together.
	// Splitting would scatter related menu configuration across multiple functions.
	private func setupStatusItem() { // swiftlint:disable:this function_body_length
		// Use variable length if showing brightness, otherwise square for icon only
		showBrightnessInMenu = debugOptions.showBrightnessInMenu
		let length = showBrightnessInMenu ? NSStatusItem.variableLength : NSStatusItem.squareLength
		statusItem = NSStatusBar.system.statusItem(withLength: length)

		if let button = statusItem.button {
			button.image = createMenuBarIcon()
			if showBrightnessInMenu {
				updateMenuBarBrightness()
				startBrightnessDisplayTimer()
			}
		}

		let menu = NSMenu()

		let aboutItem = NSMenuItem(title: "About \(AppInfo.shortName)", action: #selector(showAbout), keyEquivalent: "")
		aboutItem.target = self
		menu.addItem(aboutItem)

		#if !APP_STORE
		let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
		updateItem.target = self
		menu.addItem(updateItem)
		#endif

		menu.addItem(NSMenuItem.separator())

		let statusText = syncManager.isReady ? "Status: Active" : "Status: Error"
		let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
		statusMenuItem.isEnabled = false
		menu.addItem(statusMenuItem)

		menu.addItem(NSMenuItem.separator())

		keypressSyncMenuItem = NSMenuItem(
			title: "Live Sync",
			action: #selector(toggleLiveSync),
			keyEquivalent: ""
		)
		keypressSyncMenuItem.target = self
		keypressSyncMenuItem.state = settings.liveSyncEnabled ? .on : .off
		menu.addItem(keypressSyncMenuItem)

		timedSyncMenuItem = NSMenuItem(
			title: "Timed Sync",
			action: #selector(toggleTimedSync),
			keyEquivalent: ""
		)
		timedSyncMenuItem.target = self
		timedSyncMenuItem.state = settings.timedSyncEnabled ? .on : .off
		menu.addItem(timedSyncMenuItem)

		let syncItem = NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "")
		syncItem.target = self
		menu.addItem(syncItem)

		menu.addItem(NSMenuItem.separator())

		let prefsItem = NSMenuItem(
			title: "Preferences...",
			action: #selector(showPreferences),
			keyEquivalent: ","
		)
		prefsItem.target = self
		menu.addItem(prefsItem)

		let helpItem = NSMenuItem(
			title: "Help",
			action: #selector(openHelp),
			keyEquivalent: "?"
		)
		helpItem.target = self
		menu.addItem(helpItem)

		menu.addItem(NSMenuItem.separator())

		let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)

		statusItem.menu = menu
	}

	private func setupBrightnessMonitor() {
		keyMonitor = BrightnessKeyMonitor()
		keyMonitor?.brightnessKeyCodes = settings.brightnessKeyCodes
		keyMonitor?.onBrightnessKeyPressed = { [weak self] in
			guard let self, settings.liveSyncEnabled else { return }
			// Small delay to let macOS process the brightness change first
			// The event tap catches the key BEFORE the brightness actually changes
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
				guard let self else { return }
				syncManager.sync(gamma: settings.brightnessGamma, trigger: .keypress)
				updateMenuBarBrightness() // Update display immediately
			}
			// Debounced final sync after key release (coalesces rapid key presses)
			keypressSyncDebouncer.debounce { [weak self] in
				guard let self else { return }
				syncManager.sync(gamma: settings.brightnessGamma, trigger: .keypress)
				updateMenuBarBrightness() // Update display after final sync
			}
		}

		// Wire up event capture for debug window
		keyMonitor?.onEventCaptured = { [weak self] eventType, keyCode, keyState in
			guard let self else { return }
			// Only pass to debug window if capture is active
			if let debugWindow, debugWindow.isCaptureActive {
				let displayBrightness = displayProvider.getDisplayBrightness() ?? -1
				let keyboardBrightness = keyboardController.getKeyboardBrightness() ?? -1
				debugWindow.recordCapturedEvent(
					eventType: eventType,
					keyCode: keyCode,
					keyState: keyState,
					displayBrightness: displayBrightness,
					keyboardBrightness: keyboardBrightness
				)
			}
		}

		if keyMonitor?.start() == true {
			debugLog("Event tap started successfully - listening for brightness keys")
		} else {
			debugLog("Event tap failed - need Accessibility permissions")
		}

		// Start timed sync if enabled and not paused by power settings
		updateTimerState()
	}

	private func startTimedSync() {
		// Don't start if already running
		guard fallbackTimer == nil else { return }

		let intervalSeconds = settings.timedSyncIntervalSeconds
		fallbackTimer = Timer.scheduledTimer(
			withTimeInterval: intervalSeconds,
			repeats: true
		) { [weak self] _ in
			guard let self else { return }
			syncManager.sync(gamma: settings.brightnessGamma, trigger: .timer)
		}
		// Allow 10% tolerance for system timer coalescing (better energy efficiency)
		fallbackTimer?.tolerance = intervalSeconds * 0.1
		RunLoop.current.add(fallbackTimer!, forMode: .common)
		debugLog("Timed sync started (interval: \(intervalSeconds)s)")
	}

	private func stopTimedSync() {
		fallbackTimer?.invalidate()
		fallbackTimer = nil
	}

	/// Check if timer should be running based on settings and power state
	private func shouldTimerBeRunning() -> Bool {
		guard settings.timedSyncEnabled else { return false }
		if settings.pauseTimedSyncOnBattery, currentPowerState.isOnBattery { return false }
		if settings.pauseTimedSyncOnLowBattery, currentPowerState.isLowBattery { return false }
		return true
	}

	/// Update timer state based on current settings and power state
	private func updateTimerState() {
		if shouldTimerBeRunning() {
			if fallbackTimer == nil {
				startTimedSync()
			}
		} else {
			stopTimedSync()
		}
	}

	// MARK: - Menu Bar Brightness Display

	private func updateMenuBarBrightness() {
		guard showBrightnessInMenu, let button = statusItem.button else { return }

		if let brightness = displayProvider.getDisplayBrightness() {
			let percent = Int(round(brightness * 100))
			button.title = " \(percent)%"
		} else {
			button.title = " --%"
		}
	}

	private func startBrightnessDisplayTimer() {
		// Update every 2 seconds to keep display current
		brightnessDisplayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
			self?.updateMenuBarBrightness()
		}
		brightnessDisplayTimer?.tolerance = 0.5
	}

	private func stopBrightnessDisplayTimer() {
		brightnessDisplayTimer?.invalidate()
		brightnessDisplayTimer = nil
	}

	@objc
	private func toggleLiveSync() {
		settings.liveSyncEnabled.toggle()
		saveSettings()
		keypressSyncMenuItem.state = settings.liveSyncEnabled ? .on : .off
	}

	@objc
	private func toggleTimedSync() {
		settings.timedSyncEnabled.toggle()
		saveSettings()
		timedSyncMenuItem.state = settings.timedSyncEnabled ? .on : .off
		updateTimerState()
	}

	// MARK: - Display Callback Management

	private var displayCallbackRegistered = false

	// Static callback function for CGDisplayRegisterReconfigurationCallback
	private static let displayReconfigCallback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
		guard let userInfo else { return }
		let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

		// Check if it's a relevant change (not just display added/removed)
		if flags.contains(.setModeFlag) || flags.contains(.setMainFlag) {
			debugLog("Display reconfiguration detected")
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				delegate.syncManager.sync(gamma: delegate.settings.brightnessGamma, trigger: .displayChange)
			}
		}
	}

	private func registerDisplayCallback() {
		guard !displayCallbackRegistered else { return }
		CGDisplayRegisterReconfigurationCallback(
			Self.displayReconfigCallback,
			Unmanaged.passUnretained(self).toOpaque()
		)
		displayCallbackRegistered = true
	}

	private func unregisterDisplayCallback() {
		guard displayCallbackRegistered else { return }
		CGDisplayRemoveReconfigurationCallback(Self.displayReconfigCallback, Unmanaged.passUnretained(self).toOpaque())
		displayCallbackRegistered = false
	}

	private func setupObservers() {
		// Screen wake notification
		NSWorkspace.shared.notificationCenter.addObserver(
			self,
			selector: #selector(onWake),
			name: NSWorkspace.didWakeNotification,
			object: nil
		)

		// Screen unlock notification
		DistributedNotificationCenter.default().addObserver(
			self,
			selector: #selector(onWake),
			name: NSNotification.Name("com.apple.screenIsUnlocked"),
			object: nil
		)

		// Power state change notification (battery/AC)
		powerMonitor = PowerStateMonitor()
		powerMonitor?.onPowerStateChanged = { [weak self] state in
			guard let self else { return }
			let wasOnBattery = currentPowerState.isOnBattery
			currentPowerState = state
			// Update timer state based on new power state (start/stop as needed)
			updateTimerState()
			// Sync when plugging in (in case we paused on battery)
			if wasOnBattery, !state.isOnBattery {
				syncManager.sync(gamma: settings.brightnessGamma, trigger: .wake)
			}
		}
		powerMonitor?.start()

		// Display reconfiguration callback (catches some brightness changes)
		registerDisplayCallback()

		// Settings changed notification (from Preferences window)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(onSettingsChanged),
			name: .settingsChanged,
			object: nil
		)

		// Note: com.apple.BezelServices.brightness* distributed notifications don't work on modern macOS
		// Brightness sync relies on: 1) keypress detection, 2) display reconfiguration, 3) timer fallback
	}

	@objc
	private func onWake() {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			guard let self else { return }
			syncManager.sync(gamma: settings.brightnessGamma, trigger: .wake)
		}
	}

	@objc
	private func onSettingsChanged() {
		// Update menu item states
		keypressSyncMenuItem.state = settings.liveSyncEnabled ? .on : .off
		timedSyncMenuItem.state = settings.timedSyncEnabled ? .on : .off

		// Update timer state (start/stop/restart as needed)
		updateTimerState()

		// Sync with new gamma value
		syncManager.sync(gamma: settings.brightnessGamma, trigger: .manual)
	}

	@objc
	private func syncNow() {
		syncManager.sync(gamma: settings.brightnessGamma, trigger: .manual)
	}

	@objc
	private func showAbout() {
		guard let loader = getUILoader(),
			  let window = loader.perform(NSSelectorFromString("createAboutWindow"))?.takeUnretainedValue() else { return }

		aboutWindow = window as? AboutWindowProtocol
		if let aboutCtrl = window as? NSObject {
			let setHandlerSel = NSSelectorFromString("setDebugToggleHandler:")
			if aboutCtrl.responds(to: setHandlerSel) {
				let handler: @convention(block) () -> Void = { [weak self] in
					NSApp.stopModal()
					DispatchQueue.main.async { self?.showDebugWindow() }
				}
				aboutCtrl.perform(setHandlerSel, with: handler)
			}
		}
		aboutWindow?.showWindow()
	}

	private func showDebugWindow() {
		if debugWindow == nil {
			guard let loader = getUILoader(),
				  let window = loader.perform(NSSelectorFromString("createDebugWindow"))?.takeUnretainedValue() else { return }

			debugWindow = window as? DebugWindowProtocol

			let context = UIContext()
			context.brightnessMonitor = keyMonitor
			context.displayProvider = displayProvider
			context.keyboardController = keyboardController
			context.syncManager = syncManager
			context.settingsManager = settingsAdapter
			context.powerSourceProvider = powerSourceProvider
			context.onDebugModeChanged = { enabled in
				debugEnabled = enabled
			}
			context.onSyncHistoryToggled = { [weak self] enabled in
				self?.syncManager.syncHistoryEnabled = enabled
			}
			debugWindow?.setContext(context)
		}
		debugWindow?.isDebugModeEnabled = debugEnabled
		debugWindow?.showWindow()
		NSApp.activate(ignoringOtherApps: true)
	}

	@objc
	private func showPreferences() {
		if preferencesWindow == nil {
			guard let loader = getUILoader(),
				  let window = loader.perform(NSSelectorFromString("createPreferencesWindow"))?.takeUnretainedValue() else { return }

			preferencesWindow = window as? PreferencesWindowProtocol

			let context = UIContext()
			context.settingsManager = settingsAdapter
			context.onSettingsChanged = {
				NotificationCenter.default.post(name: .settingsChanged, object: nil)
			}
			#if !APP_STORE
			context.getAutoUpdateEnabled = { [weak self] in
				self?.updaterController.updater.automaticallyChecksForUpdates ?? false
			}
			context.setAutoUpdateEnabled = { [weak self] enabled in
				self?.updaterController.updater.automaticallyChecksForUpdates = enabled
			}
			#endif
			preferencesWindow?.setContext(context)
		}
		preferencesWindow?.showWindow()
		NSApp.activate(ignoringOtherApps: true)
	}

	@objc
	private func openHelp() {
		// Use UI library if available for consistent behavior
		if let loader = getUILoader() {
			_ = loader.perform(NSSelectorFromString("openHelp"))
			return
		}
		// Fallback: open directly
		if let url = URL(string: "\(AppInfo.githubURL)#readme") {
			NSWorkspace.shared.open(url)
		}
	}

	#if !APP_STORE
	// Loading window shown while checking for updates
	private var updateCheckWindow: NSWindow?

	@objc
	private func checkForUpdates() {
		// Show loading indicator immediately
		showUpdateCheckingWindow()

		// Show privacy notice on first update check (dialog in UI library)
		if !settings.hasAcknowledgedUpdatePrivacy {
			if let loader = getUILoader() {
				// Use typed objc_msgSend for reliable Bool return
				let selector = NSSelectorFromString("showUpdatePrivacyNotice")
				guard loader.responds(to: selector) else {
					dismissUpdateCheckingWindow()
					return
				}
				typealias ShowPrivacyFunc = @convention(c) (AnyObject, Selector) -> Bool
				let msgSend = unsafeBitCast(dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend"), to: ShowPrivacyFunc.self)
				let shouldProceed = msgSend(loader, selector)
				if shouldProceed {
					settings.hasAcknowledgedUpdatePrivacy = true
					saveSettings()
					updaterController.updater.checkForUpdates()
					// Sparkle will show its own dialog, dismiss our loading window after a delay
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
						self?.dismissUpdateCheckingWindow()
					}
				} else {
					dismissUpdateCheckingWindow()
				}
			}
		} else {
			updaterController.updater.checkForUpdates()
			// Sparkle will show its own dialog, dismiss our loading window after a delay
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				self?.dismissUpdateCheckingWindow()
			}
		}
	}

	private func showUpdateCheckingWindow() {
		// Create simple loading window with spinner
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
			styleMask: [.titled],
			backing: .buffered,
			defer: false
		)
		window.title = "TwinK[l]ey"
		window.isReleasedWhenClosed = false
		window.level = .floating
		window.center()

		// Create content view with spinner and label
		let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
		contentView.wantsLayer = true

		// Progress indicator (spinner)
		let spinner = NSProgressIndicator(frame: NSRect(x: 130, y: 50, width: 32, height: 32))
		spinner.style = .spinning
		spinner.startAnimation(nil)
		contentView.addSubview(spinner)

		// Label
		let label = NSTextField(labelWithString: "Checking for updates...")
		label.frame = NSRect(x: 20, y: 20, width: 260, height: 20)
		label.alignment = .center
		label.font = .systemFont(ofSize: 13)
		contentView.addSubview(label)

		window.contentView = contentView
		window.makeKeyAndOrderFront(nil)

		updateCheckWindow = window
	}

	private func dismissUpdateCheckingWindow() {
		updateCheckWindow?.close()
		updateCheckWindow = nil
	}
	#endif

	@objc
	private func quit() {
		// Stop all monitors and timers
		keyMonitor?.stop()
		powerMonitor?.stop()
		stopTimedSync()
		stopBrightnessDisplayTimer()
		keypressSyncDebouncer.cancel()

		// Unregister callbacks
		unregisterDisplayCallback()

		// Remove notification observers
		NSWorkspace.shared.notificationCenter.removeObserver(self)
		DistributedNotificationCenter.default().removeObserver(self)

		NSApp.terminate(nil)
	}
}

// Show privacy warning for capture mode
private func showCapturePrivacyWarning() {
	guard debugOptions.captureKeypresses else { return }

	// Use UI library if available
	if let loader = getUILoader() {
		_ = loader.perform(
			NSSelectorFromString("showCapturePrivacyWarningWithDuration:"),
			with: debugOptions.captureDuration as NSNumber
		)
		return
	}

	// Fallback: print warning inline
	print("⚠️  Keypress capture enabled (\(debugOptions.captureDuration)s). DO NOT type passwords!")
	sleep(3)
}

// Notification for settings changes
extension Notification.Name {
	static let settingsChanged = Notification.Name("settingsChanged")
}

// MARK: - Main

// Handle CLI-only commands before starting GUI
handleHelpIfNeeded()
_ = handleHealthCheck()
showCapturePrivacyWarning()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

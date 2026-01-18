import AppKit
import CoreGraphics
import IOKit.ps
import TwinKleyCore
#if !APP_STORE
import Sparkle
#endif

// MARK: - Debug Mode

private let debugEnabledViaCLI = CommandLine.arguments.contains("--debug")
private var debugEnabled = CommandLine.arguments.contains("--debug")

// Debug log file for capturing output when running in background
private var debugLogURL: URL? {
	guard debugEnabled else { return nil }
	return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".twinkley-debug.log")
}

func debugLog(_ message: String) {
	guard debugEnabled else { return }
	let timestamp = ISO8601DateFormatter().string(from: Date())
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

// MARK: - Power State Monitor (notification-based, no polling)

struct PowerState {
	var isOnBattery: Bool
	var batteryLevel: Int // 0-100, or -1 if unknown
	var isLowBattery: Bool { batteryLevel >= 0 && batteryLevel < 20 }

	static func current() -> PowerState {
		var isOnBattery = false
		var batteryLevel = -1

		guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
			  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else
		{
			return PowerState(isOnBattery: false, batteryLevel: -1)
		}

		for source in sources {
			guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
				continue
			}

			if let powerSource = info[kIOPSPowerSourceStateKey] as? String {
				isOnBattery = (powerSource == kIOPSBatteryPowerValue)
			}

			if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
				batteryLevel = capacity
			}
		}

		return PowerState(isOnBattery: isOnBattery, batteryLevel: batteryLevel)
	}
}

class PowerStateMonitor {
	var onPowerStateChanged: ((PowerState) -> Void)?
	private var runLoopSource: CFRunLoopSource?

	func start() {
		// Register for power source change notifications (no polling!)
		let context = Unmanaged.passUnretained(self).toOpaque()
		runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
			guard let context else { return }
			let monitor = Unmanaged<PowerStateMonitor>.fromOpaque(context).takeUnretainedValue()
			let state = PowerState.current()
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
class DisplayBrightnessProvider: BrightnessProvider {
	func getDisplayBrightness() -> Float? {
		guard let getFunc = getBrightnessFunc else { return nil }
		var brightness: Float = 0
		let result = getFunc(CGMainDisplayID(), &brightness)
		return result == 0 ? brightness : nil
	}
}

// MARK: - Keyboard Brightness (using KeyboardBrightnessClient - lazy loaded)

class KeyboardBrightnessController: BrightnessController {
	private var client: AnyObject?
	private var keyboardID: UInt64 = 0
	private var isInitialized = false

	private let setBrightnessSelector = NSSelectorFromString("setBrightness:forKeyboard:")
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

	var isReady: Bool {
		ensureInitialized()
	}
}

// MARK: - Brightness Key Event Monitor

class BrightnessKeyMonitor {
	private var eventTap: CFMachPort?
	private var runLoopSource: CFRunLoopSource?
	var onBrightnessKeyPressed: (() -> Void)?

	// NX key types for brightness (from IOKit/hidsystem/ev_keymap.h)
	private let nxKeytypeBrightnessUp: Int64 = 2
	private let nxKeytypeBrightnessDown: Int64 = 3

	func start() -> Bool {
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

		return true
	}

	private func handleEvent(type: CGEventType, event: CGEvent) {
		// Handle event tap being disabled by macOS (happens after sleep/wake, timeout, etc.)
		// kCGEventTapDisabledByTimeout = 0xFFFFFFFE, kCGEventTapDisabledByUserInput = 0xFFFFFFFD
		if type.rawValue == 0xFFFFFFFE || type.rawValue == 0xFFFFFFFD {
			debugLog("⚠️  Event tap disabled by macOS (type=\(type.rawValue)) - re-enabling")
			if let tap = eventTap {
				CGEvent.tapEnable(tap: tap, enable: true)
			}
			return
		}

		// Check for regular key events (Fn+F1/F2)
		if type == .keyDown {
			let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
			// F1 = 122, F2 = 120 (when used with Fn for brightness)
			// key codes 144/145 are brightness up/down on some keyboards
			if keyCode == 122 || keyCode == 120 || keyCode == 145 || keyCode == 144 {
				debugLog("Brightness key (F1/F2) detected")
				DispatchQueue.main.async { [weak self] in
					self?.onBrightnessKeyPressed?()
				}
			}
		}

		// Check for NX_SYSDEFINED events (media keys including brightness)
		if type.rawValue == 14 { // NX_SYSDEFINED
			let data1 = event.getIntegerValueField(CGEventField(rawValue: 85)!) // data1 field
			let keyCode = (data1 >> 16) & 0xFF
			// keyState: 0xA = down, 0xB = up (unused, we trigger on any)

			// Check if it's brightness
			// keyCode 2/3 = older Macs, 6 = M4, 7 = some wake/power states
			if keyCode == nxKeytypeBrightnessUp || keyCode == nxKeytypeBrightnessDown || keyCode == 6 || keyCode == 7 {
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
	}
}

// MARK: - Brightness Sync Manager (wrapper around Core with debug logging)

class AppBrightnessSyncManager {
	// Lazy-loaded keyboard controller - only initialized on first sync
	private lazy var keyboard: KeyboardBrightnessController = .init()
	private lazy var displayProvider: DisplayBrightnessProvider = .init()
	private lazy var coreSyncManager: TwinKleyCore.BrightnessSyncManager = .init(
		brightnessProvider: displayProvider,
		brightnessController: keyboard
	)

	/// Sync keyboard brightness to display brightness with debug logging
	/// - Parameter gamma: Gamma correction exponent (1.0 = linear, >1.0 = power curve)
	func sync(gamma: Double = 1.0) {
		// Get display brightness for logging
		let displayBrightness = displayProvider.getDisplayBrightness()
		let previousBrightness = coreSyncManager.lastSyncedBrightness

		// Perform sync
		let result = coreSyncManager.sync(gamma: gamma)

		// Log if brightness changed
		if let displayBrightness, coreSyncManager.lastSyncedBrightness != previousBrightness {
			let keyboardBrightness = coreSyncManager.lastSyncedBrightness
			debugLog("Sync: display=\(String(format: "%.4f", displayBrightness)) -> keyboard=\(String(format: "%.4f", keyboardBrightness)) (γ=\(String(format: "%.1f", gamma))) \(result ? "OK" : "FAILED")")
		}
	}

	var isReady: Bool {
		keyboard.isReady
	}
}

// MARK: - Menu Bar Icon

private func createMenuBarIcon() -> NSImage {
	let size: CGFloat = 18
	let image = NSImage(size: NSSize(width: size, height: size))

	image.lockFocus()
	let context = NSGraphicsContext.current!.cgContext

	// Use black color - template mode will handle light/dark
	context.setFillColor(NSColor.black.cgColor)
	context.setStrokeColor(NSColor.black.cgColor)

	// Sun on left half (centered at 35%)
	let sunCenterX = size * 0.35
	let sunCenterY = size * 0.5
	let sunRadius = size * 0.14

	// Sun body
	context.addArc(
		center: CGPoint(x: sunCenterX, y: sunCenterY),
		radius: sunRadius,
		startAngle: 0,
		endAngle: .pi * 2,
		clockwise: true
	)
	context.fillPath()

	// Sun rays
	context.setLineWidth(size / 14)
	context.setLineCap(.round)
	let rayLength = size * 0.12
	let rayStart = sunRadius + size / 22

	for i in 0..<8 {
		let angle = CGFloat(i) * .pi / 4
		context.move(to: CGPoint(x: sunCenterX + cos(angle) * rayStart, y: sunCenterY + sin(angle) * rayStart))
		context.addLine(to: CGPoint(
			x: sunCenterX + cos(angle) * (rayStart + rayLength),
			y: sunCenterY + sin(angle) * (rayStart + rayLength)
		))
	}
	context.strokePath()

	// "K" on right half (centered at 68%)
	let kCenterX = size * 0.68
	let kCenterY = size * 0.5
	let kHeight = size * 0.65
	let kWidth = size * 0.28

	context.setLineWidth(size / 9)
	context.setLineCap(.round)
	context.setLineJoin(.round)

	// K vertical line
	let kLeftX = kCenterX - kWidth * 0.3
	context.move(to: CGPoint(x: kLeftX, y: kCenterY - kHeight / 2))
	context.addLine(to: CGPoint(x: kLeftX, y: kCenterY + kHeight / 2))
	context.strokePath()

	// K diagonal lines
	let kRightX = kCenterX + kWidth * 0.5
	context.move(to: CGPoint(x: kRightX, y: kCenterY - kHeight / 2))
	context.addLine(to: CGPoint(x: kLeftX, y: kCenterY))
	context.addLine(to: CGPoint(x: kRightX, y: kCenterY + kHeight / 2))
	context.strokePath()

	image.unlockFocus()

	// Set as template for automatic light/dark mode support
	image.isTemplate = true
	return image
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusItem: NSStatusItem!
	private let syncManager = AppBrightnessSyncManager()
	private var keyMonitor: BrightnessKeyMonitor?
	private var powerMonitor: PowerStateMonitor?
	private var currentPowerState = PowerState.current()
	private var keypressSyncMenuItem: NSMenuItem!
	private var timedSyncMenuItem: NSMenuItem!
	private var fallbackTimer: Timer?

	private let settingsManager = SettingsManager()

	#if !APP_STORE
	private var updaterController: SPUStandardUpdaterController!
	#endif

	// Debouncer for keypress sync - coalesces rapid key presses into fewer syncs
	private let keypressSyncDebouncer = Debouncer(delay: 0.3)

	func applicationDidFinishLaunching(_ notification: Notification) {
		#if !APP_STORE
		// Initialize Sparkle updater
		updaterController = SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)
		#endif

		setupStatusItem()
		checkAccessibilityPermission()
		setupBrightnessMonitor()
		setupObservers()
		syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
	}

	private func checkAccessibilityPermission() {
		// .defaultTap requires Accessibility permission (not Input Monitoring)
		let hasPermission = AXIsProcessTrusted()
		debugLog("Accessibility permission: \(hasPermission)")
		if !hasPermission {
			showAccessibilityPrompt()
		}
	}

	private func showAccessibilityPrompt() {
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
			// Open System Settings to Accessibility pane
			if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
				NSWorkspace.shared.open(url)
			}
		}
	}

	private func setupStatusItem() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

		if let button = statusItem.button {
			button.image = createMenuBarIcon()
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
		keypressSyncMenuItem.state = settingsManager.settings.liveSyncEnabled ? .on : .off
		menu.addItem(keypressSyncMenuItem)

		timedSyncMenuItem = NSMenuItem(
			title: "Timed Sync",
			action: #selector(toggleTimedSync),
			keyEquivalent: ""
		)
		timedSyncMenuItem.target = self
		timedSyncMenuItem.state = settingsManager.settings.timedSyncEnabled ? .on : .off
		menu.addItem(timedSyncMenuItem)

		let syncItem = NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "")
		syncItem.target = self
		menu.addItem(syncItem)

		menu.addItem(NSMenuItem.separator())

		let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)

		statusItem.menu = menu
	}

	private func setupBrightnessMonitor() {
		keyMonitor = BrightnessKeyMonitor()
		keyMonitor?.onBrightnessKeyPressed = { [weak self] in
			guard let self, settingsManager.settings.liveSyncEnabled else { return }
			// Small delay to let macOS process the brightness change first
			// The event tap catches the key BEFORE the brightness actually changes
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
				guard let self else { return }
				syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
			}
			// Debounced final sync after key release (coalesces rapid key presses)
			keypressSyncDebouncer.debounce { [weak self] in
				guard let self else { return }
				syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
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

		let intervalSeconds = settingsManager.settings.timedSyncIntervalSeconds
		fallbackTimer = Timer.scheduledTimer(
			withTimeInterval: intervalSeconds,
			repeats: true
		) { [weak self] _ in
			guard let self else { return }
			syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
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
		guard settingsManager.settings.timedSyncEnabled else { return false }
		let settings = settingsManager.settings
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

	@objc
	private func toggleLiveSync() {
		settingsManager.update { $0.liveSyncEnabled.toggle() }
		keypressSyncMenuItem.state = settingsManager.settings.liveSyncEnabled ? .on : .off
	}

	@objc
	private func toggleTimedSync() {
		settingsManager.update { $0.timedSyncEnabled.toggle() }
		timedSyncMenuItem.state = settingsManager.settings.timedSyncEnabled ? .on : .off
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
				delegate.syncManager.sync(gamma: delegate.settingsManager.settings.brightnessGamma)
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
				syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
			}
		}
		powerMonitor?.start()

		// Display reconfiguration callback (catches some brightness changes)
		registerDisplayCallback()

		// Note: com.apple.BezelServices.brightness* distributed notifications don't work on modern macOS
		// Brightness sync relies on: 1) keypress detection, 2) display reconfiguration, 3) timer fallback
	}

	@objc
	private func onWake() {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			guard let self else { return }
			syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
		}
	}

	@objc
	private func syncNow() {
		syncManager.sync(gamma: settingsManager.settings.brightnessGamma)
	}

	@objc
	private func showAbout() {
		let alert = NSAlert()
		alert.messageText = AppInfo.name
		alert.informativeText = """
		Version \(AppInfo.version)

		Syncs keyboard backlight brightness
		to match display brightness.

		© 2024 GPL-3.0 License
		"""
		alert.alertStyle = .informational
		alert.icon = NSApp.applicationIconImage
		alert.addButton(withTitle: "OK")

		// Create clickable URL link
		let linkField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 20))
		linkField.isEditable = false
		linkField.isBordered = false
		linkField.backgroundColor = .clear
		linkField.allowsEditingTextAttributes = true
		linkField.isSelectable = true
		linkField.alignment = .center

		let linkString = NSMutableAttributedString(string: AppInfo.githubURL)
		let fullRange = NSRange(location: 0, length: linkString.length)
		linkString.addAttribute(.link, value: AppInfo.githubURL, range: fullRange)
		linkString.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: fullRange)
		linkField.attributedStringValue = linkString

		alert.accessoryView = linkField

		// Find and make the alert's icon double-clickable for debug toggle
		// Traverse view hierarchy to find the NSImageView (the icon)
		let window = alert.window
		if let iconView = findIconImageView(in: window.contentView) {
			let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(iconDoubleClicked))
			clickGesture.numberOfClicksRequired = 2
			iconView.addGestureRecognizer(clickGesture)
		}

		alert.runModal()
	}

	/// Recursively find the NSImageView in the alert that contains the icon
	private func findIconImageView(in view: NSView?) -> NSImageView? {
		guard let view else { return nil }

		// Check if this view is an NSImageView with the app icon
		if let imageView = view as? NSImageView,
		   imageView.image === NSApp.applicationIconImage {
			return imageView
		}

		// Recursively search subviews
		for subview in view.subviews {
			if let found = findIconImageView(in: subview) {
				return found
			}
		}

		return nil
	}

	@objc
	private func iconDoubleClicked() {
		// Don't allow disabling debug mode if it was enabled via CLI
		if debugEnabledViaCLI && debugEnabled {
			let alert = NSAlert()
			alert.messageText = "Debug Mode"
			alert.informativeText = "Debug mode was enabled via --debug flag and cannot be disabled at runtime."
			alert.alertStyle = .informational
			alert.addButton(withTitle: "OK")
			alert.runModal()
			return
		}

		// Toggle debug mode
		debugEnabled.toggle()

		// Log the toggle
		debugLog("Debug mode \(debugEnabled ? "enabled" : "disabled") via UI")

		// Show confirmation alert
		let alert = NSAlert()
		alert.messageText = "Debug Mode \(debugEnabled ? "Enabled" : "Disabled")"
		alert.informativeText = debugEnabled
			? "Debug logs will be written to ~/.twinkley-debug.log\n\nDouble-click the icon again to disable."
			: "Debug logging has been disabled."
		alert.alertStyle = .informational
		alert.addButton(withTitle: "OK")
		alert.runModal()
	}

	#if !APP_STORE
	@objc
	private func checkForUpdates() {
		updaterController.updater.checkForUpdates()
	}
	#endif

	@objc
	private func quit() {
		// Stop all monitors and timers
		keyMonitor?.stop()
		powerMonitor?.stop()
		stopTimedSync()
		keypressSyncDebouncer.cancel()

		// Unregister callbacks
		unregisterDisplayCallback()

		// Remove notification observers
		NSWorkspace.shared.notificationCenter.removeObserver(self)
		DistributedNotificationCenter.default().removeObserver(self)

		NSApp.terminate(nil)
	}
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

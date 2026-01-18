import Foundation

// MARK: - Protocols for UI Components

/// Protocol for brightness monitoring (used by debug window)
public protocol BrightnessMonitorProtocol: AnyObject {
	var health: EventTapHealth { get }
	var fullCaptureEnabled: Bool { get set }
	func restart() -> Bool
}

/// Protocol for display brightness reading
public protocol DisplayBrightnessProtocol {
	func getDisplayBrightness() -> Float?
}

/// Protocol for keyboard brightness control
public protocol KeyboardBrightnessProtocol {
	func setKeyboardBrightness(_ level: Float) -> Bool
	func getKeyboardBrightness() -> Float?
	func getKeyboardBacklightIDs() -> [UInt64]
	var activeKeyboardID: UInt64 { get }
}

/// Protocol for brightness sync management
public protocol BrightnessSyncProtocol: AnyObject {
	var syncHistory: [SyncRecord] { get }
	var syncHistoryEnabled: Bool { get set }
	func sync(gamma: Double, trigger: SyncTrigger)
}

/// Protocol for settings management
public protocol SettingsProtocol: AnyObject {
	var settings: Settings { get }
	func update(_ block: (inout Settings) -> Void)
}

// MARK: - UI Context (passed to UI windows)

/// Context object passed to UI windows with all dependencies
public class UIContext {
	public weak var brightnessMonitor: BrightnessMonitorProtocol?
	public var displayProvider: DisplayBrightnessProtocol?
	public var keyboardController: KeyboardBrightnessProtocol?
	public weak var syncManager: BrightnessSyncProtocol?
	public weak var settingsManager: SettingsProtocol?

	// Callbacks for debug window
	public var onDebugModeChanged: ((Bool) -> Void)?
	public var onSyncHistoryToggled: ((Bool) -> Void)?

	// Callbacks for preferences window
	public var onSettingsChanged: (() -> Void)?
	public var getAutoUpdateEnabled: (() -> Bool)?
	public var setAutoUpdateEnabled: ((Bool) -> Void)?

	public init() {}
}

// MARK: - Window Controller Protocol

/// Protocol that all dynamically-loaded window controllers must conform to
@objc public protocol DynamicWindowController {
	init()
	func showWindow()
	func setContext(_ context: Any)
}

/// Protocol for debug window - allows main app to interact with it
@objc public protocol DebugWindowProtocol: DynamicWindowController {
	var isCaptureActive: Bool { get }
	var isDebugModeEnabled: Bool { get set }
	/// Record a captured event. Use -1 for displayBrightness/keyboardBrightness if unavailable
	func recordCapturedEvent(
		eventType: String,
		keyCode: Int,
		keyState: Int,
		displayBrightness: Float,
		keyboardBrightness: Float
	)
}

/// Protocol for preferences window
@objc public protocol PreferencesWindowProtocol: DynamicWindowController {}

/// Protocol for about window
@objc public protocol AboutWindowProtocol: DynamicWindowController {}

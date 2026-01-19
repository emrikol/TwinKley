import Foundation

// MARK: - Protocols for UI Components

/// Protocol for brightness monitoring (used by debug window)
public protocol BrightnessMonitorProtocol: AnyObject {
	/// Current health statistics for the event tap
	var health: EventTapHealth { get }
	/// Whether full event capture is enabled for debugging
	var fullCaptureEnabled: Bool { get set }
	/// Restart the brightness monitor
	/// - Returns: true if restart succeeded
	func restart() -> Bool
}

/// Protocol for display brightness reading
public protocol DisplayBrightnessProtocol {
	/// Get current display brightness
	/// - Returns: Brightness level 0.0-1.0, or nil if unavailable
	func getDisplayBrightness() -> Float?
}

/// Protocol for keyboard brightness control
public protocol KeyboardBrightnessProtocol {
	/// Set keyboard backlight brightness
	/// - Parameter level: Brightness level 0.0-1.0
	/// - Returns: true if successful
	func setKeyboardBrightness(_ level: Float) -> Bool
	/// Get current keyboard brightness
	/// - Returns: Brightness level 0.0-1.0, or nil if unavailable
	func getKeyboardBrightness() -> Float?
	/// Get all available keyboard backlight IDs
	/// - Returns: Array of keyboard IDs
	func getKeyboardBacklightIDs() -> [UInt64]
	/// The currently active keyboard ID
	var activeKeyboardID: UInt64 { get }
}

/// Protocol for brightness sync management
public protocol BrightnessSyncProtocol: AnyObject {
	/// History of recent sync operations
	var syncHistory: [SyncRecord] { get }
	/// Whether sync history tracking is enabled
	var syncHistoryEnabled: Bool { get set }
	/// Perform a brightness sync operation
	/// - Parameters:
	///   - gamma: Gamma correction value
	///   - trigger: What triggered the sync
	func sync(gamma: Double, trigger: SyncTrigger)
}

/// Protocol for settings management
public protocol SettingsProtocol: AnyObject {
	/// Current settings
	var settings: Settings { get }
	/// Update settings with a modification block
	/// - Parameter block: Block that modifies settings
	func update(_ block: (inout Settings) -> Void)
}

// MARK: - UI Context (passed to UI windows)

/// Context object passed to UI windows with all dependencies
public class UIContext {
	/// Brightness monitor for event tap diagnostics
	public weak var brightnessMonitor: BrightnessMonitorProtocol?
	/// Display brightness provider
	public var displayProvider: DisplayBrightnessProtocol?
	/// Keyboard brightness controller
	public var keyboardController: KeyboardBrightnessProtocol?
	/// Brightness sync manager
	public weak var syncManager: BrightnessSyncProtocol?
	/// Settings manager
	public weak var settingsManager: SettingsProtocol?
	/// Power source provider for battery status
	public var powerSourceProvider: PowerSourceProvider?

	/// Callback when debug mode is toggled
	public var onDebugModeChanged: ((Bool) -> Void)?
	/// Callback when sync history tracking is toggled
	public var onSyncHistoryToggled: ((Bool) -> Void)?

	/// Callback when settings are changed
	public var onSettingsChanged: (() -> Void)?
	/// Getter for auto-update enabled state
	public var getAutoUpdateEnabled: (() -> Bool)?
	/// Setter for auto-update enabled state
	public var setAutoUpdateEnabled: ((Bool) -> Void)?

	/// Creates an empty UI context
	public init() { }
}

// MARK: - Window Controller Protocol

/// Protocol that all dynamically-loaded window controllers must conform to
@objc public protocol DynamicWindowController {
	/// Initialize the window controller
	init()
	/// Show the window
	func showWindow()
	/// Set the context with dependencies
	/// - Parameter context: UIContext with all dependencies
	func setContext(_ context: Any)
}

/// Protocol for debug window - allows main app to interact with it
@objc public protocol DebugWindowProtocol: DynamicWindowController {
	/// Whether event capture is currently active
	var isCaptureActive: Bool { get }
	/// Whether debug mode is enabled
	var isDebugModeEnabled: Bool { get set }
	/// Record a captured event for display
	/// - Parameters:
	///   - eventType: Type of event (e.g., "NX_SYSDEFINED")
	///   - keyCode: Key code of the event
	///   - keyState: State of the key (up/down)
	///   - displayBrightness: Current display brightness (-1 if unavailable)
	///   - keyboardBrightness: Current keyboard brightness (-1 if unavailable)
	func recordCapturedEvent(
		eventType: String,
		keyCode: Int,
		keyState: Int,
		displayBrightness: Float,
		keyboardBrightness: Float
	)
}

/// Protocol for preferences window
@objc public protocol PreferencesWindowProtocol: DynamicWindowController { }

/// Protocol for about window
@objc public protocol AboutWindowProtocol: DynamicWindowController { }

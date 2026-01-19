import Foundation

/// Event tap health statistics for diagnostics
/// Note: Computed properties for UI display are in TwinKleyUI/EventTapHealthExtensions.swift
public struct EventTapHealth {
	/// Whether the event tap is currently running
	public var isRunning: Bool = false
	/// Total number of events received
	public var eventsReceived: Int = 0
	/// Number of brightness-related events received
	public var brightnessEventsReceived: Int = 0
	/// Number of times the tap was disabled by system timeout
	public var disabledByTimeoutCount: Int = 0
	/// Number of times the tap was disabled by user input
	public var disabledByUserInputCount: Int = 0
	/// Number of times the tap was re-enabled after being disabled
	public var reenabledCount: Int = 0
	/// Timestamp of the last event received
	public var lastEventTimestamp: Date?
	/// Timestamp of when the tap was last disabled
	public var lastDisabledTimestamp: Date?
	/// Timestamp of when the tap was created
	public var createdTimestamp: Date?
	/// Distribution of key codes received (keyCode -> count)
	public var keyCodeDistribution: [Int: Int] = [:]

	/// Creates a new empty event tap health record
	public init() { }

	/// Track a keyCode event (used by main app)
	/// - Parameter keyCode: The key code to track
	public mutating func trackKeyCode(_ keyCode: Int) {
		keyCodeDistribution[keyCode, default: 0] += 1
	}
}

/// Sync operation record for history
public struct SyncRecord {
	/// When the sync occurred
	public let timestamp: Date
	/// What triggered the sync
	public let trigger: SyncTrigger
	/// Display brightness at time of sync (0.0-1.0)
	public let displayBrightness: Float
	/// Keyboard brightness set (0.0-1.0)
	public let keyboardBrightness: Float
	/// Gamma correction value used
	public let gamma: Double
	/// Whether the sync succeeded
	public let success: Bool
	/// Duration of the sync operation in milliseconds
	public let durationMs: Int
	/// Whether a brightness change was actually needed
	public let changeNeeded: Bool

	/// Creates a new sync record
	/// - Parameters:
	///   - timestamp: When the sync occurred (default: now)
	///   - trigger: What triggered the sync
	///   - displayBrightness: Display brightness at time of sync
	///   - keyboardBrightness: Keyboard brightness set
	///   - gamma: Gamma correction value used
	///   - success: Whether the sync succeeded
	///   - durationMs: Duration in milliseconds
	///   - changeNeeded: Whether a change was actually needed
	public init(
		timestamp: Date = Date(),
		trigger: SyncTrigger,
		displayBrightness: Float,
		keyboardBrightness: Float,
		gamma: Double,
		success: Bool,
		durationMs: Int,
		changeNeeded: Bool
	) {
		self.timestamp = timestamp
		self.trigger = trigger
		self.displayBrightness = displayBrightness
		self.keyboardBrightness = keyboardBrightness
		self.gamma = gamma
		self.success = success
		self.durationMs = durationMs
		self.changeNeeded = changeNeeded
	}
}

/// What triggered a brightness sync operation
public enum SyncTrigger: String {
	/// Triggered by brightness key press
	case keypress
	/// Triggered by periodic timer
	case timer
	/// Triggered by system wake from sleep
	case wake
	/// Triggered by display configuration change
	case displayChange = "display"
	/// Triggered manually by user
	case manual
	/// Triggered at app startup
	case startup
}

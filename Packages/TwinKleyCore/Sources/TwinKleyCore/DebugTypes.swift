import Foundation

/// Event tap health statistics for diagnostics
/// Note: Computed properties for UI display are in TwinKleyUI/EventTapHealthExtensions.swift
public struct EventTapHealth {
	public var isRunning: Bool = false
	public var eventsReceived: Int = 0
	public var brightnessEventsReceived: Int = 0
	public var disabledByTimeoutCount: Int = 0
	public var disabledByUserInputCount: Int = 0
	public var reenabledCount: Int = 0
	public var lastEventTimestamp: Date?
	public var lastDisabledTimestamp: Date?
	public var createdTimestamp: Date?
	public var keyCodeDistribution: [Int: Int] = [:]

	public init() {}

	/// Track a keyCode event (used by main app)
	public mutating func trackKeyCode(_ keyCode: Int) {
		keyCodeDistribution[keyCode, default: 0] += 1
	}
}

/// Sync operation record for history
public struct SyncRecord {
	public let timestamp: Date
	public let trigger: SyncTrigger
	public let displayBrightness: Float
	public let keyboardBrightness: Float
	public let gamma: Double
	public let success: Bool
	public let durationMs: Int
	public let changeNeeded: Bool

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

public enum SyncTrigger: String {
	case keypress = "keypress"
	case timer = "timer"
	case wake = "wake"
	case displayChange = "display"
	case manual = "manual"
	case startup = "startup"
}

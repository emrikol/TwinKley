import Foundation

// MARK: - Protocols

/// Provides display brightness readings
public protocol BrightnessProvider {
	/// Get current display brightness (0.0-1.0), nil if unavailable
	func getDisplayBrightness() -> Float?
}

/// Controls keyboard backlight brightness
public protocol BrightnessController {
	/// Set keyboard brightness (0.0-1.0)
	/// - Returns: true if successful
	func setKeyboardBrightness(_ brightness: Float) -> Bool
}

// MARK: - Brightness Sync Manager

/// Manages brightness synchronization between display and keyboard
public final class BrightnessSyncManager {
	private let brightnessProvider: BrightnessProvider
	private let brightnessController: BrightnessController
	private var lastBrightness: Float = -1
	private var lastDisplayBrightness: Float = -1

	/// Creates a new sync manager with the given brightness provider and controller
	/// - Parameters:
	///   - brightnessProvider: Provider for reading display brightness
	///   - brightnessController: Controller for setting keyboard brightness
	public init(
		brightnessProvider: BrightnessProvider,
		brightnessController: BrightnessController
	) {
		self.brightnessProvider = brightnessProvider
		self.brightnessController = brightnessController
	}

	/// Sync keyboard brightness to display brightness with gamma correction
	/// - Parameter gamma: Gamma correction exponent (1.0 = linear, >1.0 = power curve)
	/// - Returns: true if sync succeeded, false otherwise
	@discardableResult
	public func sync(gamma: Double = 1.0) -> Bool {
		guard let displayBrightness = brightnessProvider.getDisplayBrightness() else {
			// Reset to invalid on read failure to prevent stale values in history
			lastDisplayBrightness = -1
			return false
		}

		// Track display brightness for caller access (avoids double-read)
		lastDisplayBrightness = displayBrightness

		// Apply gamma curve: keyboard = display^gamma
		// gamma > 1: dims keyboard at low brightness (power curve)
		// gamma = 1: linear (no correction)
		// Both display and keyboard range from 0.0 to 1.0
		let rawCorrectedBrightness: Float = if gamma == 1.0 {
			displayBrightness
		} else {
			Float(pow(Double(displayBrightness), gamma))
		}

		// Clamp to [0.0, 1.0] for safety (defends against floating-point edge cases)
		let correctedBrightness = min(max(rawCorrectedBrightness, 0.0), 1.0)

		// Only set keyboard brightness if it changed significantly
		guard abs(correctedBrightness - lastBrightness) > 0.005 else {
			return true // No change needed, still considered success
		}

		// Only update lastBrightness if set succeeds (allows retry on failure)
		let success = brightnessController.setKeyboardBrightness(correctedBrightness)
		if success {
			lastBrightness = correctedBrightness
		}
		return success
	}

	/// Reset last brightness to force sync on next call
	public func reset() {
		lastBrightness = -1
		lastDisplayBrightness = -1
	}

	/// Get the last synced keyboard brightness value
	public var lastSyncedBrightness: Float {
		lastBrightness
	}

	/// Get the display brightness used in the last sync (avoids double-read)
	public var lastSyncedDisplayBrightness: Float {
		lastDisplayBrightness
	}
}

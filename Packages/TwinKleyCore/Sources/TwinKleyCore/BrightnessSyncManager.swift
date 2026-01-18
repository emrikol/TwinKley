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
			return false
		}

		// Apply gamma curve: keyboard = display^gamma
		// gamma > 1: dims keyboard at low brightness (power curve)
		// gamma = 1: linear (no correction)
		// Both display and keyboard range from 0.0 to 1.0
		let correctedBrightness: Float = if gamma == 1.0 {
			displayBrightness
		} else {
			Float(pow(Double(displayBrightness), gamma))
		}

		// Only set keyboard brightness if it changed significantly
		guard abs(correctedBrightness - lastBrightness) > 0.005 else {
			return true // No change needed, still considered success
		}

		lastBrightness = correctedBrightness
		return brightnessController.setKeyboardBrightness(correctedBrightness)
	}

	/// Reset last brightness to force sync on next call
	public func reset() {
		lastBrightness = -1
	}

	/// Get the last synced brightness value
	public var lastSyncedBrightness: Float {
		lastBrightness
	}
}

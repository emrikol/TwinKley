import Foundation

/// Protocol for power source information provider (enables testing)
public protocol PowerSourceProvider {
	/// Get power source information from the system
	/// - Returns: Array of dictionaries with power source info, or nil if unavailable
	func getPowerSourcesInfo() -> [[String: Any]]?
}

/// Power state information (battery/AC)
public struct PowerState {
	/// Whether the device is running on battery power
	public var isOnBattery: Bool
	/// Battery charge level (0-100), or -1 if unknown
	public var batteryLevel: Int

	/// Whether battery level is considered low (below 20%)
	public var isLowBattery: Bool { batteryLevel >= 0 && batteryLevel < 20 }

	/// Creates a power state with the given values
	/// - Parameters:
	///   - isOnBattery: Whether on battery power (default: false)
	///   - batteryLevel: Battery level 0-100, or -1 if unknown (default: -1)
	public init(isOnBattery: Bool = false, batteryLevel: Int = -1) {
		self.isOnBattery = isOnBattery
		self.batteryLevel = batteryLevel
	}

	/// IOKit power source state key
	public static let powerSourceStateKey = "Power Source State"
	/// IOKit current capacity key
	public static let currentCapacityKey = "Current Capacity"
	/// IOKit battery power value
	public static let batteryPowerValue = "Battery Power"

	/// Get the current power state from a provider
	/// - Parameter provider: The power source provider to query
	/// - Returns: Current power state
	public static func current(provider: PowerSourceProvider) -> PowerState {
		guard let sources = provider.getPowerSourcesInfo() else {
			return PowerState(isOnBattery: false, batteryLevel: -1)
		}

		var isOnBattery = false
		var batteryLevel = -1

		for info in sources {
			if let powerSource = info[powerSourceStateKey] as? String {
				isOnBattery = (powerSource == batteryPowerValue)
			}

			if let capacity = info[currentCapacityKey] as? Int {
				batteryLevel = capacity
			}
		}

		return PowerState(isOnBattery: isOnBattery, batteryLevel: batteryLevel)
	}
}

import Foundation
import IOKit.ps

/// Power state information (battery/AC)
public struct PowerState {
	public var isOnBattery: Bool
	public var batteryLevel: Int // 0-100, or -1 if unknown

	public var isLowBattery: Bool { batteryLevel >= 0 && batteryLevel < 20 }

	public init(isOnBattery: Bool = false, batteryLevel: Int = -1) {
		self.isOnBattery = isOnBattery
		self.batteryLevel = batteryLevel
	}

	/// Get the current power state from the system
	public static func current() -> PowerState {
		var isOnBattery = false
		var batteryLevel = -1

		guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
			  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
		else {
			return PowerState(isOnBattery: false, batteryLevel: -1)
		}

		for source in sources {
			guard let info = IOPSGetPowerSourceDescription(snapshot, source)?
				.takeUnretainedValue() as? [String: Any]
			else {
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

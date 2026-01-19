import Foundation
import TwinKleyCore

/// UI-only computed properties for EventTapHealth (kept out of main binary)
public extension EventTapHealth {
	/// Time interval since the last event was received, or nil if no events yet
	var timeSinceLastEvent: TimeInterval? {
		lastEventTimestamp.map { Date().timeIntervalSince($0) }
	}

	/// Human-readable status description for the event tap
	var statusDescription: String {
		guard isRunning else { return "Not running" }
		if let lastEvent = timeSinceLastEvent {
			if lastEvent > 300 { // 5 minutes
				return "Running (no events in \(Int(lastEvent / 60)) min)"
			}
		}
		return "Running"
	}

	/// Key code distribution sorted by count (highest first)
	var sortedKeyCodeDistribution: [(keyCode: Int, count: Int)] {
		keyCodeDistribution.map { (keyCode: $0.key, count: $0.value) }
			.sorted { $0.count > $1.count }
	}

	/// Clear the key code distribution tracking
	mutating func resetDistribution() {
		keyCodeDistribution.removeAll()
	}
}

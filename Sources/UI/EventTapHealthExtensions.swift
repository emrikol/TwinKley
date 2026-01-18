import Foundation
import TwinKleyCore

/// UI-only computed properties for EventTapHealth (kept out of main binary)
public extension EventTapHealth {
	var timeSinceLastEvent: TimeInterval? {
		lastEventTimestamp.map { Date().timeIntervalSince($0) }
	}

	var statusDescription: String {
		guard isRunning else { return "Not running" }
		if let lastEvent = timeSinceLastEvent {
			if lastEvent > 300 { // 5 minutes
				return "Running (no events in \(Int(lastEvent / 60)) min)"
			}
		}
		return "Running"
	}

	var sortedKeyCodeDistribution: [(keyCode: Int, count: Int)] {
		keyCodeDistribution.map { (keyCode: $0.key, count: $0.value) }
			.sorted { $0.count > $1.count }
	}

	mutating func resetDistribution() {
		keyCodeDistribution.removeAll()
	}
}

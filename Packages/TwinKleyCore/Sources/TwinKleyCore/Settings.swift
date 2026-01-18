import Foundation

// MARK: - App Info

/// App version information
public enum AppInfo {
	public static let version = "1.0.0-beta1"
	public static let name = "☀️ TwinK[l]ey ⌨️"
	public static let shortName = "TwinK[l]ey"
	public static let identifier = "com.local.TwinKley"
	public static let githubURL = "https://github.com/emrikol/TwinKley"
}

// MARK: - Settings

/// App settings that can be persisted to disk
public struct Settings: Codable, Equatable {
	public var liveSyncEnabled: Bool // Event-driven sync (brightness keys, Control Center, etc.)
	public var timedSyncEnabled: Bool // Background polling fallback
	public var timedSyncIntervalMs: Int
	public var pauseTimedSyncOnBattery: Bool // Pause polling when on battery
	public var pauseTimedSyncOnLowBattery: Bool // Pause polling when battery < 20%
	public var brightnessGamma: Double // Gamma curve for perceptual brightness matching
	public var hasLaunchedBefore: Bool // First-run tracking
	public var hasAcknowledgedUpdatePrivacy: Bool // User acknowledged GitHub privacy notice

	public static let intervalMin = 100
	public static let intervalMax = 60_000 // Up to 1 minute
	public static let intervalDefault = 10_000 // 10 seconds (reduced CPU wake-ups)

	public static let gammaMin = 0.5
	public static let gammaMax = 4.0
	public static let gammaDefault = 1.5 // 1.5 = mild correction (recommended)

	public static let `default` = Settings(
		liveSyncEnabled: true,
		timedSyncEnabled: false, // Off by default - live sync is event-driven (zero polling)
		timedSyncIntervalMs: intervalDefault,
		pauseTimedSyncOnBattery: false,
		pauseTimedSyncOnLowBattery: true,
		brightnessGamma: gammaDefault,
		hasLaunchedBefore: false,
		hasAcknowledgedUpdatePrivacy: false
	)

	public init(
		liveSyncEnabled: Bool = true,
		timedSyncEnabled: Bool = false, // Off by default for energy efficiency
		timedSyncIntervalMs: Int = intervalDefault,
		pauseTimedSyncOnBattery: Bool = false,
		pauseTimedSyncOnLowBattery: Bool = true,
		brightnessGamma: Double = gammaDefault,
		hasLaunchedBefore: Bool = false,
		hasAcknowledgedUpdatePrivacy: Bool = false
	) {
		self.liveSyncEnabled = liveSyncEnabled
		self.timedSyncEnabled = timedSyncEnabled
		self.timedSyncIntervalMs = Self.clampInterval(timedSyncIntervalMs)
		self.pauseTimedSyncOnBattery = pauseTimedSyncOnBattery
		self.pauseTimedSyncOnLowBattery = pauseTimedSyncOnLowBattery
		self.brightnessGamma = Self.clampGamma(brightnessGamma)
		self.hasLaunchedBefore = hasLaunchedBefore
		self.hasAcknowledgedUpdatePrivacy = hasAcknowledgedUpdatePrivacy
	}

	// Uses synthesized Codable - no backward compatibility needed (pre-v1)

	/// Clamp interval to valid range
	public static func clampInterval(_ value: Int) -> Int {
		min(max(value, intervalMin), intervalMax)
	}

	/// Clamp gamma to valid range
	public static func clampGamma(_ value: Double) -> Double {
		min(max(value, gammaMin), gammaMax)
	}

	/// Timer interval in seconds
	public var timedSyncIntervalSeconds: Double {
		Double(timedSyncIntervalMs) / 1_000.0
	}
}

// SettingsManager moved to TwinKleyUI for lazy loading

/// Minimal settings loader for main binary (minimal code, kept in Core for fast startup)
public enum SettingsLoader {
	public static var defaultFileURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".twinkley.json")
	}

	/// Quick load settings from disk (returns default on error)
	public static func load(from url: URL? = nil) -> Settings {
		let fileURL = url ?? defaultFileURL
		guard let data = try? Data(contentsOf: fileURL),
			  let decoded = try? JSONDecoder().decode(Settings.self, from: data) else
		{
			return Settings.default
		}
		return decoded
	}

	/// Quick save settings to disk
	@discardableResult
	public static func save(_ settings: Settings, to url: URL? = nil) -> Bool {
		let fileURL = url ?? defaultFileURL
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return (try? encoder.encode(settings).write(to: fileURL)) != nil
	}
}

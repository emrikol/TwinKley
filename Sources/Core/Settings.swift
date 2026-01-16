import Foundation

// MARK: - App Info

/// App version information
public enum AppInfo {
	public static let version = "1.0.0"
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

	public static let intervalMin = 100
	public static let intervalMax = 60_000 // Up to 1 minute
	public static let intervalDefault = 10_000 // 10 seconds (reduced CPU wake-ups)

	public static let gammaMin = 0.5
	public static let gammaMax = 4.0
	public static let gammaDefault = 1.5 // 1.5 = mild correction (recommended)

	public static let `default` = Settings(
		liveSyncEnabled: true,
		timedSyncEnabled: true,
		timedSyncIntervalMs: intervalDefault,
		pauseTimedSyncOnBattery: false,
		pauseTimedSyncOnLowBattery: true,
		brightnessGamma: gammaDefault
	)

	public init(
		liveSyncEnabled: Bool = true,
		timedSyncEnabled: Bool = true,
		timedSyncIntervalMs: Int = intervalDefault,
		pauseTimedSyncOnBattery: Bool = false,
		pauseTimedSyncOnLowBattery: Bool = true,
		brightnessGamma: Double = gammaDefault
	) {
		self.liveSyncEnabled = liveSyncEnabled
		self.timedSyncEnabled = timedSyncEnabled
		self.timedSyncIntervalMs = Self.clampInterval(timedSyncIntervalMs)
		self.pauseTimedSyncOnBattery = pauseTimedSyncOnBattery
		self.pauseTimedSyncOnLowBattery = pauseTimedSyncOnLowBattery
		self.brightnessGamma = Self.clampGamma(brightnessGamma)
	}

	// MARK: - Backward Compatibility

	enum CodingKeys: String, CodingKey {
		case liveSyncEnabled
		case keypressSyncEnabled // Old name for backward compatibility
		case timedSyncEnabled
		case timedSyncIntervalMs
		case pauseTimedSyncOnBattery
		case pauseTimedSyncOnLowBattery
		case brightnessGamma
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Try new name first, fall back to old name for backward compatibility
		if let liveSyncEnabled = try? container.decode(Bool.self, forKey: .liveSyncEnabled) {
			self.liveSyncEnabled = liveSyncEnabled
		} else if let keypressSyncEnabled = try? container.decode(Bool.self, forKey: .keypressSyncEnabled) {
			self.liveSyncEnabled = keypressSyncEnabled // Migrate old setting
		} else {
			self.liveSyncEnabled = true // Default if neither exists
		}

		timedSyncEnabled = try container.decode(Bool.self, forKey: .timedSyncEnabled)
		timedSyncIntervalMs = Self.clampInterval(try container.decode(Int.self, forKey: .timedSyncIntervalMs))
		pauseTimedSyncOnBattery = try container.decode(Bool.self, forKey: .pauseTimedSyncOnBattery)
		pauseTimedSyncOnLowBattery = try container.decode(Bool.self, forKey: .pauseTimedSyncOnLowBattery)
		brightnessGamma = Self.clampGamma(try container.decode(Double.self, forKey: .brightnessGamma))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		// Only encode the new name
		try container.encode(liveSyncEnabled, forKey: .liveSyncEnabled)
		try container.encode(timedSyncEnabled, forKey: .timedSyncEnabled)
		try container.encode(timedSyncIntervalMs, forKey: .timedSyncIntervalMs)
		try container.encode(pauseTimedSyncOnBattery, forKey: .pauseTimedSyncOnBattery)
		try container.encode(pauseTimedSyncOnLowBattery, forKey: .pauseTimedSyncOnLowBattery)
		try container.encode(brightnessGamma, forKey: .brightnessGamma)
	}

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

/// Manages loading and saving settings
public class SettingsManager {
	private let fileURL: URL
	public private(set) var settings: Settings

	public init(fileURL: URL? = nil) {
		self.fileURL = fileURL ?? Self.defaultFileURL
		settings = Settings.default
		load()
	}

	public static var defaultFileURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".twinkley.json")
	}

	/// Load settings from disk
	public func load() {
		guard let data = try? Data(contentsOf: fileURL),
			  let decoded = try? JSONDecoder().decode(Settings.self, from: data) else
		{
			settings = Settings.default
			return
		}
		settings = decoded
	}

	/// Save settings to disk
	@discardableResult
	public func save() -> Bool {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return (try? encoder.encode(settings).write(to: fileURL)) != nil
	}

	/// Update a setting and save
	public func update(_ block: (inout Settings) -> Void) {
		block(&settings)
		save()
	}
}

import Foundation
import TwinKleyCore

/// Manages loading and saving settings - loaded from dynamic library
public class SettingsManager: SettingsProtocol {
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

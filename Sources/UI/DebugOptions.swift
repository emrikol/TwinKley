import Foundation
import TwinKleyCore

/// Debug options that can be set via CLI arguments or GUI
public struct DebugOptions: Equatable {
	/// Enable debug logging to ~/.twinkley-debug.log
	public var loggingEnabled: Bool

	/// Capture all keypress events (for diagnostics)
	public var captureKeypresses: Bool

	/// Duration for keypress capture in seconds (0 = until manually stopped)
	public var captureDuration: Int

	/// Log verbose event details (all NX_SYSDEFINED events, not just brightness)
	public var verboseEvents: Bool

	/// Show brightness values in menu bar (for debugging)
	public var showBrightnessInMenu: Bool

	/// Track event tap health (disabled/re-enabled counts)
	public var trackEventTapHealth: Bool

	/// Log sync history (recent sync operations with timing)
	public var logSyncHistory: Bool

	public static let `default` = DebugOptions(
		loggingEnabled: false,
		captureKeypresses: false,
		captureDuration: 30,
		verboseEvents: false,
		showBrightnessInMenu: false,
		trackEventTapHealth: true, // Always track for diagnostics
		logSyncHistory: false
	)

	public init(
		loggingEnabled: Bool = false,
		captureKeypresses: Bool = false,
		captureDuration: Int = 30,
		verboseEvents: Bool = false,
		showBrightnessInMenu: Bool = false,
		trackEventTapHealth: Bool = true,
		logSyncHistory: Bool = false
	) {
		self.loggingEnabled = loggingEnabled
		self.captureKeypresses = captureKeypresses
		self.captureDuration = captureDuration
		self.verboseEvents = verboseEvents
		self.showBrightnessInMenu = showBrightnessInMenu
		self.trackEventTapHealth = trackEventTapHealth
		self.logSyncHistory = logSyncHistory
	}

	/// Parse debug options from command line arguments
	public static func fromCommandLine(_ arguments: [String] = CommandLine.arguments) -> DebugOptions {
		var options = DebugOptions.default

		// --debug or -d: Enable debug logging
		if arguments.contains("--debug") || arguments.contains("-d") {
			options.loggingEnabled = true
		}

		// --capture[=SECONDS]: Enable keypress capture
		for arg in arguments {
			if arg == "--capture" {
				options.captureKeypresses = true
				options.captureDuration = 30 // Default 30 seconds
			} else if arg.hasPrefix("--capture=") {
				options.captureKeypresses = true
				let durationStr = String(arg.dropFirst("--capture=".count))
				options.captureDuration = Int(durationStr) ?? 30
			}
		}

		// --verbose or -v: Log all events
		if arguments.contains("--verbose") || arguments.contains("-v") {
			options.verboseEvents = true
			options.loggingEnabled = true // Verbose implies logging
		}

		// --show-brightness: Show brightness in menu bar
		if arguments.contains("--show-brightness") {
			options.showBrightnessInMenu = true
		}

		// --sync-history: Log sync operations
		if arguments.contains("--sync-history") {
			options.logSyncHistory = true
			options.loggingEnabled = true
		}

		// --health-check: Run health check and exit
		// (handled separately in main.swift)

		return options
	}

	/// Generate CLI arguments from current options
	public func toCommandLineArguments() -> [String] {
		var args: [String] = []

		if loggingEnabled && !verboseEvents && !logSyncHistory {
			args.append("--debug")
		}

		if verboseEvents {
			args.append("--verbose")
		}

		if captureKeypresses {
			if captureDuration != 30 {
				args.append("--capture=\(captureDuration)")
			} else {
				args.append("--capture")
			}
		}

		if showBrightnessInMenu {
			args.append("--show-brightness")
		}

		if logSyncHistory {
			args.append("--sync-history")
		}

		return args
	}

	/// Help text for CLI arguments
	public static let helpText = """
	Debug Options:
	  --debug, -d           Enable debug logging to ~/.twinkley-debug.log
	  --verbose, -v         Log all system events (implies --debug)
	  --capture[=SECONDS]   Capture keypress events for diagnostics (default: 30s)
	                        ⚠️  PRIVACY: Captures ALL key events - avoid typing passwords!
	  --show-brightness     Show current brightness values in menu bar
	  --sync-history        Log all sync operations with timing
	  --health-check        Run diagnostics and exit with status

	Examples:
	  TwinKley --debug                    # Enable debug logging
	  TwinKley --capture=60               # Capture keypresses for 60 seconds
	  TwinKley --verbose --capture        # Full diagnostic mode
	  TwinKley --health-check             # Quick system health check
	"""
}

/// Available debug options for UI display
public enum DebugOption: String, CaseIterable {
	case logging = "Debug Logging"
	case captureKeypresses = "Capture Keypresses"
	case verboseEvents = "Verbose Event Logging"
	case showBrightnessInMenu = "Show Brightness in Menu"
	case syncHistory = "Log Sync History"

	public var description: String {
		switch self {
		case .logging:
			return "Log events to ~/.twinkley-debug.log"
		case .captureKeypresses:
			return "Record all key events for diagnostics (privacy sensitive)"
		case .verboseEvents:
			return "Log all NX_SYSDEFINED events, not just brightness keys"
		case .showBrightnessInMenu:
			return "Display current brightness percentages in the menu bar"
		case .syncHistory:
			return "Log all sync operations with timing information"
		}
	}

	public var cliArgument: String {
		switch self {
		case .logging:
			return "--debug"
		case .captureKeypresses:
			return "--capture"
		case .verboseEvents:
			return "--verbose"
		case .showBrightnessInMenu:
			return "--show-brightness"
		case .syncHistory:
			return "--sync-history"
		}
	}

	public var isPrivacySensitive: Bool {
		switch self {
		case .captureKeypresses:
			return true
		default:
			return false
		}
	}
}

// Note: EventTapHealth, SyncRecord, and SyncTrigger are defined in TwinKleyCore/DebugTypes.swift

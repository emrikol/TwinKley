import AppKit
import TwinKleyCore

/// About window controller - dynamically loaded UI component
@objc public class AboutWindowController: NSObject, AboutWindowProtocol {
	private var context: UIContext?
	private var onDebugToggle: (() -> Void)?

	@objc public required override init() {
		super.init()
	}

	/// Set the context with all dependencies
	@objc public func setContext(_ context: Any) {
		guard let ctx = context as? UIContext else { return }
		self.context = ctx
	}

	/// Set callback for when user double-clicks icon to toggle debug
	/// Note: handler must be @convention(block) for ObjC runtime compatibility
	@objc public func setDebugToggleHandler(_ handler: @escaping @convention(block) () -> Void) {
		self.onDebugToggle = handler
	}

	/// Show the About dialog
	@objc public func showWindow() {
		let alert = NSAlert()
		alert.messageText = AppInfo.name
		alert.informativeText = """
		Version \(AppInfo.version)

		Syncs keyboard backlight brightness
		to match display brightness.

		© 2024 GPL-3.0 License
		"""
		alert.alertStyle = .informational
		alert.icon = NSApp.applicationIconImage
		alert.addButton(withTitle: "OK")

		// Create clickable URL link
		let linkField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 20))
		linkField.isEditable = false
		linkField.isBordered = false
		linkField.backgroundColor = .clear
		linkField.allowsEditingTextAttributes = true
		linkField.isSelectable = true
		linkField.alignment = .center

		let linkString = NSMutableAttributedString(string: AppInfo.githubURL)
		let fullRange = NSRange(location: 0, length: linkString.length)
		linkString.addAttribute(.link, value: AppInfo.githubURL, range: fullRange)
		linkString.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: fullRange)
		linkField.attributedStringValue = linkString

		alert.accessoryView = linkField

		// Find and make the alert's icon double-clickable for debug toggle
		let window = alert.window
		if let iconView = findIconImageView(in: window.contentView) {
			let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(iconDoubleClicked))
			clickGesture.numberOfClicksRequired = 2
			iconView.addGestureRecognizer(clickGesture)
		}

		alert.runModal()
	}

	/// Recursively find the NSImageView in the alert that contains the icon
	private func findIconImageView(in view: NSView?) -> NSImageView? {
		guard let view else { return nil }

		// Check if this view is an NSImageView with the app icon
		if let imageView = view as? NSImageView,
		   imageView.image === NSApp.applicationIconImage
		{
			return imageView
		}

		// Recursively search subviews
		for subview in view.subviews {
			if let found = findIconImageView(in: subview) {
				return found
			}
		}

		return nil
	}

	@objc
	private func iconDoubleClicked() {
		onDebugToggle?()
	}
}

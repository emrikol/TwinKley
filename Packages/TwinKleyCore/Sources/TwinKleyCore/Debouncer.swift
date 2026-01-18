import Foundation

/// A utility class that coalesces rapid function calls into a single execution after a delay.
/// Useful for reducing CPU wake-ups when handling repeated events like key presses.
public class Debouncer {
	private var workItem: DispatchWorkItem?
	private let delay: TimeInterval
	private let queue: DispatchQueue

	/// Creates a new debouncer with the specified delay.
	/// - Parameters:
	///   - delay: The time interval to wait after the last call before executing.
	///   - queue: The queue to execute the action on. Defaults to main queue.
	public init(delay: TimeInterval, queue: DispatchQueue = .main) {
		self.delay = delay
		self.queue = queue
	}

	/// Debounce an action. Cancels any pending action and schedules a new one.
	/// - Parameter action: The closure to execute after the delay.
	public func debounce(action: @escaping () -> Void) {
		workItem?.cancel()
		let item = DispatchWorkItem(block: action)
		workItem = item
		queue.asyncAfter(deadline: .now() + delay, execute: item)
	}

	/// Cancel any pending debounced action.
	public func cancel() {
		workItem?.cancel()
		workItem = nil
	}

	/// Whether there is a pending action waiting to execute.
	public var isPending: Bool {
		workItem != nil && !workItem!.isCancelled
	}
}

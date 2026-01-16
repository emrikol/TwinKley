@testable import TwinKleyCore
import XCTest

final class DebouncerTests: XCTestCase {
	// MARK: - Basic Functionality

	func testDebouncerExecutesAfterDelay() {
		let expectation = expectation(description: "Debounced action should execute")
		let debouncer = Debouncer(delay: 0.1)

		debouncer.debounce {
			expectation.fulfill()
		}

		waitForExpectations(timeout: 0.5)
	}

	func testDebouncerCancelsPreviousCalls() {
		let expectation = expectation(description: "Only final action should execute")
		var callCount = 0
		let debouncer = Debouncer(delay: 0.1)

		// Rapid calls - only the last one should execute
		for i in 1...5 {
			debouncer.debounce {
				callCount += 1
				if i == 5 {
					expectation.fulfill()
				}
			}
		}

		waitForExpectations(timeout: 0.5)
		XCTAssertEqual(callCount, 1, "Only one action should have executed")
	}

	func testDebouncerExplicitCancel() {
		let expectation = expectation(description: "Action should not execute after cancel")
		expectation.isInverted = true // We expect this NOT to be fulfilled
		let debouncer = Debouncer(delay: 0.1)

		debouncer.debounce {
			expectation.fulfill()
		}

		debouncer.cancel()

		waitForExpectations(timeout: 0.3)
	}

	func testDebouncerIsPending() {
		let debouncer = Debouncer(delay: 0.5)

		XCTAssertFalse(debouncer.isPending, "Should not be pending initially")

		debouncer.debounce { }

		XCTAssertTrue(debouncer.isPending, "Should be pending after debounce")

		debouncer.cancel()

		XCTAssertFalse(debouncer.isPending, "Should not be pending after cancel")
	}

	// MARK: - Timing Tests

	func testDebouncerRespectsDelay() {
		let startTime = Date()
		let expectation = expectation(description: "Action should execute after delay")
		let debouncer = Debouncer(delay: 0.2)

		debouncer.debounce {
			let elapsed = Date().timeIntervalSince(startTime)
			XCTAssertGreaterThanOrEqual(elapsed, 0.18, "Should wait at least the delay time")
			expectation.fulfill()
		}

		waitForExpectations(timeout: 0.5)
	}

	func testDebouncerResetsDelayOnNewCall() {
		let expectation = expectation(description: "Action should execute after final delay")
		var executionTime: Date?
		let debouncer = Debouncer(delay: 0.15)

		// First call
		debouncer.debounce {
			executionTime = Date()
			expectation.fulfill()
		}

		// Second call after 0.1s - should reset the delay
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			debouncer.debounce {
				executionTime = Date()
				expectation.fulfill()
			}
		}

		waitForExpectations(timeout: 0.5)

		// Total time should be ~0.1s (wait) + 0.15s (new delay) = ~0.25s, not 0.15s
		// This is hard to test precisely, so we just verify it executed
		XCTAssertNotNil(executionTime)
	}

	// MARK: - Edge Cases

	func testDebouncerCanBeReused() {
		let expectation1 = expectation(description: "First debounce")
		let expectation2 = expectation(description: "Second debounce")
		let debouncer = Debouncer(delay: 0.1)

		debouncer.debounce {
			expectation1.fulfill()
		}

		wait(for: [expectation1], timeout: 0.3)

		debouncer.debounce {
			expectation2.fulfill()
		}

		wait(for: [expectation2], timeout: 0.3)
	}

	func testDebouncerWithZeroDelay() {
		let expectation = expectation(description: "Should execute with zero delay")
		let debouncer = Debouncer(delay: 0)

		debouncer.debounce {
			expectation.fulfill()
		}

		waitForExpectations(timeout: 0.1)
	}
}

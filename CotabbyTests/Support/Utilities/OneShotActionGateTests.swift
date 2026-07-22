import Dispatch
import Foundation
import XCTest
@testable import Cotabby

/// Pins the exactly-once invariant used by Vision and ScreenCaptureKit continuation bridges.
final class OneShotActionGateTests: XCTestCase {
    func test_run_executesOnlyTheFirstAction() {
        let gate = OneShotActionGate()
        let counter = LockedCounter()

        XCTAssertTrue(gate.run { counter.increment() })
        XCTAssertFalse(gate.run { counter.increment() })
        XCTAssertEqual(counter.value, 1)
    }

    func test_run_executesOnceWhenCallbacksRace() {
        let gate = OneShotActionGate()
        let counter = LockedCounter()

        DispatchQueue.concurrentPerform(iterations: 256) { _ in
            gate.run { counter.increment() }
        }

        XCTAssertEqual(counter.value, 1)
    }
}

/// Thread-safe test storage avoids making the assertion itself part of the race under test.
private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func increment() {
        lock.lock()
        storedValue += 1
        lock.unlock()
    }
}

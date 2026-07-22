import Dispatch
import XCTest
@testable import Cotabby

/// Exercises the synchronization boundary between task cancellation and native sequence lifetime.
final class LlamaSequenceAbortControllerTests: XCTestCase {
    func test_cancelTargetsThePublishedSequence() {
        let controller = LlamaSequenceAbortController()
        var cancelledSequenceID: Int32?

        controller.publish(42)
        let didCancel = controller.cancelPublishedSequence { cancelledSequenceID = $0 }

        XCTAssertTrue(didCancel)
        XCTAssertEqual(cancelledSequenceID, 42)
        XCTAssertTrue(controller.finish(42))
        XCTAssertFalse(controller.cancelPublishedSequence { _ in
            XCTFail("A finished sequence must no longer be visible to cancellation.")
        })
    }

    func test_finishingWithoutCancellationReturnsFalseAndWithdrawsTarget() {
        let controller = LlamaSequenceAbortController()

        controller.publish(42)

        XCTAssertFalse(controller.finish(42))
        XCTAssertFalse(controller.cancelPublishedSequence { _ in
            XCTFail("Finishing must atomically withdraw the native sequence target.")
        })
    }

    func test_retiringPublishedSequencePreventsLateCancellation() {
        let controller = LlamaSequenceAbortController()
        var destroyedSequenceID: Int32?

        controller.publish(42)
        controller.retireAndDestroy(42) { destroyedSequenceID = $0 }

        XCTAssertEqual(destroyedSequenceID, 42)
        XCTAssertFalse(controller.cancelPublishedSequence { _ in
            XCTFail("A retired native sequence must no longer be visible to cancellation.")
        })
    }

    func test_retirementWaitsForInFlightNativeCancellation() {
        let controller = LlamaSequenceAbortController()
        let queue = DispatchQueue(label: "LlamaSequenceAbortControllerTests", attributes: .concurrent)
        let cancellationEntered = DispatchSemaphore(value: 0)
        let allowCancellationToFinish = DispatchSemaphore(value: 0)
        let retirementStarted = DispatchSemaphore(value: 0)
        let retirementFinished = DispatchSemaphore(value: 0)
        controller.publish(42)

        queue.async {
            controller.cancelPublishedSequence { _ in
                cancellationEntered.signal()
                allowCancellationToFinish.wait()
            }
        }
        XCTAssertEqual(cancellationEntered.wait(timeout: .now() + 1), .success)

        queue.async {
            retirementStarted.signal()
            controller.retireAndDestroy(42) { _ in }
            retirementFinished.signal()
        }
        XCTAssertEqual(retirementStarted.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(
            retirementFinished.wait(timeout: .now() + 0.05),
            .timedOut,
            "Destruction must wait until cancellation releases its borrowed native pointer."
        )

        allowCancellationToFinish.signal()
        XCTAssertEqual(retirementFinished.wait(timeout: .now() + 1), .success)
        XCTAssertFalse(controller.cancelPublishedSequence { _ in
            XCTFail("Retirement must withdraw the target before destruction completes.")
        })
    }
}

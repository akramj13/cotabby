import Foundation

/// Coordinates cancellation and destruction of the native autocomplete sequence.
///
/// Generation publishes the sequence currently decoding while cancellation may arrive from a
/// different thread. CotabbyInference looks up a native sequence pointer before setting its atomic
/// cancellation flag, so destruction must not invalidate that pointer between lookup and use.
/// This controller makes the native cancel and destroy calls mutually exclusive and retires a
/// published identity before its storage can be freed.
///
/// `LlamaRuntimeCore` owns one controller for the lifetime of the loaded runtime. The controller is
/// `@unchecked Sendable` because every access to `publishedSequenceID` is protected by `NSLock`.
nonisolated final class LlamaSequenceAbortController: @unchecked Sendable {
    private let lock = NSLock()
    private var publishedSequenceID: Int32 = -1
    private var cancellationIssuedSequenceID: Int32 = -1

    /// Publishes the sequence whose prompt or completion is currently decoding.
    func publish(_ sequenceID: Int32) {
        lock.lock()
        publishedSequenceID = sequenceID
        cancellationIssuedSequenceID = -1
        lock.unlock()
    }

    /// Removes the current cancellation target after the operation finishes.
    func clear() {
        lock.lock()
        publishedSequenceID = -1
        cancellationIssuedSequenceID = -1
        lock.unlock()
    }

    /// Cancels the published sequence while preserving its native lifetime for the whole call.
    @discardableResult
    func cancelPublishedSequence(using cancel: (Int32) -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard publishedSequenceID >= 0 else { return false }
        cancellationIssuedSequenceID = publishedSequenceID
        cancel(publishedSequenceID)
        return true
    }

    /// Atomically withdraws `sequenceID` and reports whether its permanent native abort flag fired.
    ///
    /// A Swift task can notice cooperative cancellation before the next native sample observes the
    /// flag. Consuming this fact lets the runtime discard that poisoned sequence in either ordering.
    /// Once this method withdraws the target, later cancellation cannot mark it after the check.
    func finish(_ sequenceID: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if publishedSequenceID == sequenceID {
            publishedSequenceID = -1
        }
        let cancellationWasIssued = cancellationIssuedSequenceID == sequenceID
        if cancellationWasIssued {
            cancellationIssuedSequenceID = -1
        }
        return cancellationWasIssued
    }

    /// Retires `sequenceID`, then destroys it without allowing cancellation to race the free.
    ///
    /// `destroy` runs inside the critical section intentionally. Both native calls are short, and
    /// this span closes the use-after-free window between cancellation's pointer lookup and flag
    /// store. Callers must not invoke another controller method from either supplied closure.
    func retireAndDestroy(_ sequenceID: Int32, using destroy: (Int32) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        if publishedSequenceID == sequenceID {
            publishedSequenceID = -1
        }
        if cancellationIssuedSequenceID == sequenceID {
            cancellationIssuedSequenceID = -1
        }
        destroy(sequenceID)
    }
}

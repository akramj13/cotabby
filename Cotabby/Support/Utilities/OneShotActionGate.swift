import Foundation

/// Lets exactly one competing callback complete an asynchronous bridge.
///
/// Apple completion-handler APIs occasionally expose the same failure through both a callback and
/// a throwing entry point. A checked continuation traps the process when resumed twice, so each
/// callback bridge owns one short-lived gate and routes every completion path through `run(_:)`.
/// The gate is `@unchecked Sendable` because `NSLock` protects its only mutable value.
nonisolated final class OneShotActionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasRun = false

    /// Runs `action` for the first caller and ignores every later attempt.
    ///
    /// The action executes after releasing the lock. Continuation resumption can immediately run
    /// awaiting work, so keeping the lock held would create an unnecessary re-entrancy hazard.
    @discardableResult
    func run(_ action: () -> Void) -> Bool {
        lock.lock()
        let shouldRun = !hasRun
        if shouldRun {
            hasRun = true
        }
        lock.unlock()

        guard shouldRun else { return false }
        action()
        return true
    }
}

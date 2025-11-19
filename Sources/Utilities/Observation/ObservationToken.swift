import Foundation
import os.lock

/// A cancellable token that keeps an observation alive until explicitly cancelled or deinitialized.
/// The cancellation handler is guarded by an unfair lock to ensure it is invoked at most once.
internal final class ObservationToken: Sendable {
    private struct CancellationState {
        var handler: (@Sendable () -> Void)?
    }

    private let lock: OSAllocatedUnfairLock<CancellationState> = OSAllocatedUnfairLock(
        initialState: CancellationState(),
    )

    internal init(cancellationHandler: @escaping @Sendable () -> Void) {
        lock.withLock { state in
            state.handler = cancellationHandler
        }
    }

    /// Cancels the underlying observation.
    internal func cancel() {
        let handler = lock.withLock { state -> (@Sendable () -> Void)? in
            defer { state.handler = nil }
            return state.handler
        }
        handler?()
    }

    deinit {
        cancel()
    }
}

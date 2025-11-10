import Foundation

/// A cancellable token that keeps an observation alive until explicitly cancelled or deinitialized.
internal final class ObservationToken {
    private var cancellationHandler: (() -> Void)?

    internal init(cancellationHandler: @escaping () -> Void) {
        self.cancellationHandler = cancellationHandler
    }

    /// Cancels the underlying observation.
    internal func cancel() {
        cancellationHandler?()
        cancellationHandler = nil
    }

    deinit {
        cancel()
    }
}

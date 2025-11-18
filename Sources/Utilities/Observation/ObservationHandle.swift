import Foundation

/// Lightweight wrapper that keeps an observation token alive until cancelled.
internal struct ObservationHandle: Sendable {
    private let token: ObservationToken

    internal init(token: ObservationToken) {
        self.token = token
    }

    /// Cancels the underlying observation.
    internal func cancel() {
        token.cancel()
    }
}

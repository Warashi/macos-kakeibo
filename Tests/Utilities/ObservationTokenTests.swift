import Foundation
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct ObservationTokenTests {
    @Test("cancel を複数回呼んでもハンドラは1度しか実行されない")
    internal func cancel_isIdempotent() async throws {
        let counter = CancellationCounter()
        let token = ObservationToken {
            Task {
                await counter.increment()
            }
        }

        token.cancel()
        token.cancel()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await counter.value == 1)
    }

    @Test("deinit 時にハンドラが呼ばれる")
    internal func deinit_triggersHandler() async throws {
        let counter = CancellationCounter()
        var token: ObservationToken? = ObservationToken {
            Task {
                await counter.increment()
            }
        }

        _ = token
        token = nil

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await counter.value == 1)
    }
}

private actor CancellationCounter {
    private var count: Int = 0

    func increment() {
        count += 1
    }

    var value: Int {
        count
    }
}

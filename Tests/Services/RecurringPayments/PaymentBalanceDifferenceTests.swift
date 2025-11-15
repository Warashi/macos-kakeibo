import Foundation
@testable import Kakeibo
import Testing

@Suite("RecurringPaymentBalanceService - PaymentDifferenceテスト")
internal struct PaymentBalanceDifferenceTests {
    @Test("PaymentDifference：ぴったり")
    internal func paymentDifference_exact() {
        let diff = PaymentDifference(expected: 100_000, actual: 100_000)
        #expect(diff.difference == 0)
        #expect(diff.type == .exact)
    }

    @Test("PaymentDifference：超過払い")
    internal func paymentDifference_overpaid() {
        let diff = PaymentDifference(expected: 100_000, actual: 120_000)
        #expect(diff.difference == 20000)
        #expect(diff.type == .overpaid)
    }

    @Test("PaymentDifference：過少払い")
    internal func paymentDifference_underpaid() {
        let diff = PaymentDifference(expected: 100_000, actual: 80000)
        #expect(diff.difference == -20000)
        #expect(diff.type == .underpaid)
    }
}

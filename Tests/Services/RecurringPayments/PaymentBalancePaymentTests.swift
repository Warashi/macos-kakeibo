import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("RecurringPaymentBalanceService - 実績支払いテスト")
internal struct PaymentBalancePaymentTests {
    private let service: RecurringPaymentBalanceService = RecurringPaymentBalanceService()

    private func sampleDefinition() -> RecurringPaymentDefinition {
        RecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
    }

    @Test("実績支払いを反映：ぴったり支払い")
    internal func processPayment_exactAmount() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = RecurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 45000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 45000,
        )

        context.insert(definition)
        context.insert(balance)
        context.insert(occurrence)

        // When
        let difference = service.processPayment(
            occurrence: occurrence,
            balance: balance,
        )

        // Then
        #expect(difference.expected == 45000)
        #expect(difference.actual == 45000)
        #expect(difference.difference == 0)
        #expect(difference.type == .exact)
        #expect(balance.totalPaidAmount == 45000)
        #expect(balance.balance == 0) // 45000 - 45000
    }

    @Test("実績支払いを反映：超過払い")
    internal func processPayment_overpaid() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = RecurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 45000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 50000, // 予定より多く支払い
        )

        context.insert(definition)
        context.insert(balance)
        context.insert(occurrence)

        // When
        let difference = service.processPayment(
            occurrence: occurrence,
            balance: balance,
        )

        // Then
        #expect(difference.type == .overpaid)
        #expect(difference.difference == 5000)
        #expect(balance.totalPaidAmount == 50000)
        #expect(balance.balance == -5000) // 45000 - 50000
    }

    @Test("実績支払いを反映：過少払い")
    internal func processPayment_underpaid() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = RecurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 45000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        let occurrence = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 40000, // 予定より少なく支払い
        )

        context.insert(definition)
        context.insert(balance)
        context.insert(occurrence)

        // When
        let difference = service.processPayment(
            occurrence: occurrence,
            balance: balance,
        )

        // Then
        #expect(difference.type == .underpaid)
        #expect(difference.difference == -5000)
        #expect(balance.totalPaidAmount == 40000)
        #expect(balance.balance == 5000) // 45000 - 40000（余り）
    }

    @Test("実績支払いを反映：複数回の支払い")
    internal func processPayment_multiplePayments() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = RecurringPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 90000, // 2回分積立
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(balance)

        // 1回目の支払い
        let occurrence1 = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 45000,
        )
        context.insert(occurrence1)

        service.processPayment(
            occurrence: occurrence1,
            balance: balance,
        )

        #expect(balance.totalPaidAmount == 45000)
        #expect(balance.balance == 45000)

        // 2回目の支払い
        let occurrence2 = RecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2027, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 50000, // 超過払い
        )
        context.insert(occurrence2)

        service.processPayment(
            occurrence: occurrence2,
            balance: balance,
        )

        // Then
        #expect(balance.totalPaidAmount == 95000) // 45000 + 50000
        #expect(balance.balance == -5000) // 90000 - 95000
    }
}

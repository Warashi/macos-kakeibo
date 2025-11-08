import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SpecialPaymentBalanceService Tests")
internal struct SpecialPaymentBalanceServiceTests {
    private let service: SpecialPaymentBalanceService = SpecialPaymentBalanceService()

    private func sampleDefinition() -> SpecialPaymentDefinition {
        SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
    }

    // MARK: - 月次積立の記録テスト

    @Test("月次積立を記録：新規作成")
    internal func recordMonthlySavings_newBalance() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        context.insert(definition)

        // When
        let balance = service.recordMonthlySavings(
            for: definition,
            balance: nil,
            year: 2025,
            month: 11,
            context: context,
        )

        // Then
        #expect(balance.totalSavedAmount == 3750) // 45000 / 12
        #expect(balance.totalPaidAmount == 0)
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("月次積立を記録：既存残高に加算")
    internal func recordMonthlySavings_addToExisting() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let existingBalance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 3750,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 10,
        )
        context.insert(definition)
        context.insert(existingBalance)

        // When
        let balance = service.recordMonthlySavings(
            for: definition,
            balance: existingBalance,
            year: 2025,
            month: 11,
            context: context,
        )

        // Then
        #expect(balance.totalSavedAmount == 7500) // 3750 + 3750
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("月次積立を記録：同じ年月で重複記録はスキップ")
    internal func recordMonthlySavings_skipDuplicate() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let existingBalance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 3750,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        context.insert(definition)
        context.insert(existingBalance)

        // When
        let balance = service.recordMonthlySavings(
            for: definition,
            balance: existingBalance,
            year: 2025,
            month: 11, // 同じ年月
            context: context,
        )

        // Then
        #expect(balance.totalSavedAmount == 3750) // 変わらない
    }

    @Test("月次積立を記録：複数月連続で記録")
    internal func recordMonthlySavings_multipleMonths() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        context.insert(definition)

        var balance: SpecialPaymentSavingBalance?

        // 6ヶ月分の積立を記録
        for month in 1 ... 6 {
            balance = service.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2025,
                month: month,
                context: context,
            )
        }

        // Then
        let finalBalance = try #require(balance)
        #expect(finalBalance.totalSavedAmount == 22500) // 3750 × 6
        #expect(finalBalance.lastUpdatedYear == 2025)
        #expect(finalBalance.lastUpdatedMonth == 6)
    }

    // MARK: - 実績支払いの反映テスト

    @Test("実績支払いを反映：ぴったり支払い")
    internal func processPayment_exactAmount() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 45000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        let occurrence = SpecialPaymentOccurrence(
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
            context: context,
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
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 45000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        let occurrence = SpecialPaymentOccurrence(
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
            context: context,
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
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 45000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        let occurrence = SpecialPaymentOccurrence(
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
            context: context,
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
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 90000, // 2回分積立
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(balance)

        // 1回目の支払い
        let occurrence1 = SpecialPaymentOccurrence(
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
            context: context,
        )

        #expect(balance.totalPaidAmount == 45000)
        #expect(balance.balance == 45000)

        // 2回目の支払い
        let occurrence2 = SpecialPaymentOccurrence(
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
            context: context,
        )

        // Then
        #expect(balance.totalPaidAmount == 95000) // 45000 + 50000
        #expect(balance.balance == -5000) // 90000 - 95000
    }

    // MARK: - 残高の再計算テスト

    @Test("残高の再計算：完了済みOccurrenceから集計")
    internal func recalculateBalance_fromOccurrences() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // 定義の作成日を2025年1月に設定
        let definition = sampleDefinition()
        let createdDate = Date.from(year: 2025, month: 1) ?? Date()
        // createdAtを直接設定することができないため、この部分は簡易的に実装

        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 0,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )

        // 完了済みのOccurrenceを追加
        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 45000,
        )
        let occurrence2 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 50000,
        )
        let occurrence3 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2027, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving, // 未完了は除外される
        )

        context.insert(definition)
        context.insert(balance)
        definition.occurrences = [occurrence1, occurrence2, occurrence3]

        // When: 2025年11月時点での再計算
        service.recalculateBalance(
            for: definition,
            balance: balance,
            year: 2025,
            month: 11,
            context: context,
        )

        // Then
        // 累計支払額は完了済みのみ: 45000 + 50000 = 95000
        #expect(balance.totalPaidAmount == 95000)

        // 累計積立額は月次積立額 × 経過月数
        // 2025年1月〜11月 = 11ヶ月
        // 3750 × 11 = 41250
        #expect(balance.totalSavedAmount == 41250)

        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("残高の再計算：Occurrenceがない場合")
    internal func recalculateBalance_noOccurrences() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 1000, // 古いデータ
            totalPaidAmount: 500, // 古いデータ
            lastUpdatedYear: 2024,
            lastUpdatedMonth: 12,
        )

        context.insert(definition)
        context.insert(balance)

        // When
        service.recalculateBalance(
            for: definition,
            balance: balance,
            year: 2025,
            month: 11,
            context: context,
        )

        // Then
        #expect(balance.totalPaidAmount == 0) // Occurrenceがないので0
        #expect(balance.totalSavedAmount >= 0) // 経過月数に応じた積立額
    }

    // MARK: - PaymentDifference テスト

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

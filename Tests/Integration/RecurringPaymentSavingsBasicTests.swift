import Foundation
@testable import Kakeibo
import SwiftData
import Testing

/// 定期支払い積立・充当ロジックの統合テスト（基本シナリオ）
///
/// 基本的な積立・支払いのエンドツーエンドシナリオを検証します。
@Suite("RecurringPaymentSavings Basic Integration Tests")
internal struct RecurringPaymentSavingsBasicTests {
    private let balanceService: RecurringPaymentBalanceService = RecurringPaymentBalanceService()
    private let calculator: BudgetCalculator = BudgetCalculator()

    // MARK: - 基本シナリオ

    @Test("基本シナリオ：3年周期の積立と支払い")
    internal func basicScenario_threeYearCycle() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given: 3年周期（36ヶ月）の定期支払い定義
        let category = SwiftDataCategory(name: "保険・税金")
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 36,
            firstOccurrenceDate: Date.from(year: 2028, month: 1) ?? Date(),
            category: category,
            savingStrategy: .evenlyDistributed,
        )

        context.insert(category)
        context.insert(definition)
        try context.save()

        // 月次積立額は 120,000 / 36 = 3,333.33...
        let expectedMonthlySaving = Decimal(120_000) / Decimal(36)
        #expect(definition.monthlySavingAmount == expectedMonthlySaving)

        // When: 36ヶ月分の積立を記録
        var balance: SwiftDataRecurringPaymentSavingBalance?
        for month in 1 ... 36 {
            balance = balanceService.recordMonthlySavings(
                params: RecurringPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: balance,
                    year: 2025 + (month - 1) / 12,
                    month: ((month - 1) % 12) + 1,
                ),
            )
        }

        let finalBalance = try #require(balance)

        // Then: 累計積立額が目標金額に近いこと
        // 3333.33... × 36 = 120,000
        #expect(finalBalance.totalSavedAmount >= 119_999)
        #expect(finalBalance.totalSavedAmount <= 120_001)
        #expect(finalBalance.totalPaidAmount == 0)
        #expect(finalBalance.balance >= 119_999)

        // 実績支払いを記録
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2028, month: 1) ?? Date(),
            expectedAmount: 120_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 120_000,
        )
        context.insert(occurrence)
        definition.occurrences = [occurrence]

        let difference = balanceService.processPayment(
            occurrence: occurrence,
            balance: finalBalance,
        )

        // Then: ぴったり支払えたことを確認
        #expect(difference.type == .exact)
        #expect(finalBalance.totalPaidAmount == 120_000)
        #expect(finalBalance.balance >= -1)
        #expect(finalBalance.balance <= 1)
    }

    // MARK: - 繰上げ払いケース

    @Test("繰上げ払い：実績 < 予定")
    internal func underpaidScenario() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 12ヶ月積立
        var balance: SwiftDataRecurringPaymentSavingBalance?
        for month in 1 ... 12 {
            balance = balanceService.recordMonthlySavings(
                params: RecurringPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: balance,
                    year: 2025,
                    month: month,
                ),
            )
        }

        let finalBalance = try #require(balance)
        #expect(finalBalance.totalSavedAmount == 45000)

        // When: 実績が予定より少ない（値引きがあった）
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 40000, // 5000円安く済んだ
        )
        context.insert(occurrence)
        definition.occurrences = [occurrence]

        let difference = balanceService.processPayment(
            occurrence: occurrence,
            balance: finalBalance,
        )

        // Then: 差額が残高に残る
        #expect(difference.type == .underpaid)
        #expect(difference.difference == -5000)
        #expect(finalBalance.totalPaidAmount == 40000)
        #expect(finalBalance.balance == 5000) // 余りが残る
    }

    // MARK: - 繰下げ払いケース

    @Test("繰下げ払い：実績 > 予定")
    internal func overpaidScenario() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 24ヶ月積立
        var balance: SwiftDataRecurringPaymentSavingBalance?
        for month in 1 ... 24 {
            balance = balanceService.recordMonthlySavings(
                params: RecurringPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: balance,
                    year: 2024 + (month - 1) / 12,
                    month: ((month - 1) % 12) + 1,
                ),
            )
        }

        let finalBalance = try #require(balance)
        #expect(finalBalance.totalSavedAmount == 120_000)

        // When: 実績が予定より多い（追加整備が必要だった）
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 120_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 135_000, // 15000円超過
        )
        context.insert(occurrence)
        definition.occurrences = [occurrence]

        let difference = balanceService.processPayment(
            occurrence: occurrence,
            balance: finalBalance,
        )

        // Then: 残高がマイナスになる（次回以降の積立で補填）
        #expect(difference.type == .overpaid)
        #expect(difference.difference == 15000)
        #expect(finalBalance.totalPaidAmount == 135_000)
        #expect(finalBalance.balance == -15000) // マイナス残高
        #expect(finalBalance.isBalanceInsufficient) // 不足フラグ
    }
}

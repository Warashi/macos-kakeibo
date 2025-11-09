import Foundation
@testable import Kakeibo
import SwiftData
import Testing

/// 特別支払い積立・充当ロジックの統合テスト（複数回支払いシナリオ）
///
/// 複数サイクルでの積立・支払いの繰り返しを検証します。
@Suite("SpecialPaymentSavings Multiple Payments Tests")
internal struct SpecialPaymentMultiplePaymentsTests {
    private let balanceService: SpecialPaymentBalanceService = SpecialPaymentBalanceService()

    @Test("複数回支払い：2回目、3回目の支払い")
    internal func multiplePaymentsScenario() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given: 年次支払い
        let definition = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 4) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        var balance: SpecialPaymentSavingBalance?

        // 1回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSavingCycle(
            definition: definition,
            balance: balance,
            startMonth: 1,
            endMonth: 12,
            context: context,
        )

        let occurrence1 = createOccurrence(
            definition: definition,
            year: 2025,
            month: 4,
            expectedAmount: 150_000,
            actualAmount: 150_000,
            context: context,
        )

        let finalBalance = try #require(balance)
        balanceService.processPayment(occurrence: occurrence1, balance: finalBalance, context: context)

        #expect(finalBalance.totalSavedAmount == 150_000)
        #expect(finalBalance.totalPaidAmount == 150_000)
        #expect(finalBalance.balance == 0)

        // 2回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSavingCycle(
            definition: definition,
            balance: balance,
            startMonth: 13,
            endMonth: 24,
            context: context,
        )

        let occurrence2 = createOccurrence(
            definition: definition,
            year: 2026,
            month: 4,
            expectedAmount: 150_000,
            actualAmount: 155_000, // 少し超過
            context: context,
        )

        balanceService.processPayment(occurrence: occurrence2, balance: finalBalance, context: context)

        #expect(finalBalance.totalSavedAmount == 300_000)
        #expect(finalBalance.totalPaidAmount == 305_000)
        #expect(finalBalance.balance == -5000)

        // 3回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSavingCycle(
            definition: definition,
            balance: balance,
            startMonth: 25,
            endMonth: 36,
            context: context,
        )

        let occurrence3 = createOccurrence(
            definition: definition,
            year: 2027,
            month: 4,
            expectedAmount: 150_000,
            actualAmount: 145_000, // 安く済んだ
            context: context,
        )

        balanceService.processPayment(occurrence: occurrence3, balance: finalBalance, context: context)

        // Then: 累計が正しく計算されている
        #expect(finalBalance.totalSavedAmount == 450_000) // 150000 × 3
        #expect(finalBalance.totalPaidAmount == 450_000) // 150000 + 155000 + 145000
        #expect(finalBalance.balance == 0) // ちょうどゼロ
    }

    // MARK: - Private Helpers

    /// 指定範囲の月次積立を実行するヘルパー関数
    private func performSavingCycle(
        definition: SpecialPaymentDefinition,
        balance: SpecialPaymentSavingBalance?,
        startMonth: Int,
        endMonth: Int,
        context: ModelContext,
    ) -> SpecialPaymentSavingBalance? {
        var currentBalance = balance
        for month in startMonth ... endMonth {
            currentBalance = balanceService.recordMonthlySavings(
                for: definition,
                balance: currentBalance,
                year: 2024 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }
        return currentBalance
    }

    /// 支払い実績を作成するヘルパー関数
    private func createOccurrence(
        definition: SpecialPaymentDefinition,
        year: Int,
        month: Int,
        expectedAmount: Decimal,
        actualAmount: Decimal,
        context: ModelContext,
    ) -> SpecialPaymentOccurrence {
        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: year, month: month) ?? Date(),
            expectedAmount: expectedAmount,
            status: .completed,
            actualDate: Date(),
            actualAmount: actualAmount,
        )
        context.insert(occurrence)
        return occurrence
    }
}

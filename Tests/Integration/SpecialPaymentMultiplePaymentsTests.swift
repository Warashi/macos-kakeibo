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
        balance = performFirstCycle(definition: definition, balance: balance, context: context)

        // 2回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSecondCycle(definition: definition, balance: balance, context: context)

        // 3回目のサイクル: 12ヶ月積立 + 支払い
        let finalBalance = try performThirdCycle(definition: definition, balance: balance, context: context)

        // Then: 累計が正しく計算されている
        #expect(finalBalance.totalSavedAmount == 450_000) // 150000 × 3
        #expect(finalBalance.totalPaidAmount == 450_000) // 150000 + 155000 + 145000
        #expect(finalBalance.balance == 0) // ちょうどゼロ
    }

    // MARK: - Private Helpers

    /// サイクルパラメータ
    private struct CycleParams {
        internal let startMonth: Int
        internal let endMonth: Int
        internal let year: Int
        internal let month: Int
        internal let actualAmount: Decimal
    }

    /// 1回目のサイクルを実行
    private func performFirstCycle(
        definition: SpecialPaymentDefinition,
        balance: SpecialPaymentSavingBalance?,
        context: ModelContext,
    ) -> SpecialPaymentSavingBalance? {
        let params: CycleParams = CycleParams(
            startMonth: 1,
            endMonth: 12,
            year: 2025,
            month: 4,
            actualAmount: 150_000,
        )

        let updatedBalance: SpecialPaymentSavingBalance? = performSavingCycle(
            definition: definition,
            balance: balance,
            params: params,
            context: context,
        )

        let occurrence = createOccurrence(definition: definition, params: params, context: context)
        if let finalBalance = updatedBalance {
            balanceService.processPayment(occurrence: occurrence, balance: finalBalance, context: context)
            return finalBalance
        }
        return updatedBalance
    }

    /// 2回目のサイクルを実行
    private func performSecondCycle(
        definition: SpecialPaymentDefinition,
        balance: SpecialPaymentSavingBalance?,
        context: ModelContext,
    ) -> SpecialPaymentSavingBalance? {
        let params: CycleParams = CycleParams(
            startMonth: 13,
            endMonth: 24,
            year: 2026,
            month: 4,
            actualAmount: 155_000,
        )

        let updatedBalance: SpecialPaymentSavingBalance? = performSavingCycle(
            definition: definition,
            balance: balance,
            params: params,
            context: context,
        )

        let occurrence = createOccurrence(definition: definition, params: params, context: context)
        if let finalBalance = updatedBalance {
            balanceService.processPayment(occurrence: occurrence, balance: finalBalance, context: context)
            return finalBalance
        }
        return updatedBalance
    }

    /// 3回目のサイクルを実行
    private func performThirdCycle(
        definition: SpecialPaymentDefinition,
        balance: SpecialPaymentSavingBalance?,
        context: ModelContext,
    ) throws -> SpecialPaymentSavingBalance {
        let params: CycleParams = CycleParams(
            startMonth: 25,
            endMonth: 36,
            year: 2027,
            month: 4,
            actualAmount: 145_000,
        )

        let updatedBalance: SpecialPaymentSavingBalance? = performSavingCycle(
            definition: definition,
            balance: balance,
            params: params,
            context: context,
        )

        let occurrence = createOccurrence(definition: definition, params: params, context: context)
        let finalBalance = try #require(updatedBalance)
        balanceService.processPayment(occurrence: occurrence, balance: finalBalance, context: context)
        return finalBalance
    }

    /// 指定範囲の月次積立を実行するヘルパー関数
    private func performSavingCycle(
        definition: SpecialPaymentDefinition,
        balance: SpecialPaymentSavingBalance?,
        params: CycleParams,
        context: ModelContext,
    ) -> SpecialPaymentSavingBalance? {
        var currentBalance: SpecialPaymentSavingBalance? = balance
        for month in params.startMonth ... params.endMonth {
            currentBalance = balanceService.recordMonthlySavings(
                params: SpecialPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: currentBalance,
                    year: 2024 + (month - 1) / 12,
                    month: ((month - 1) % 12) + 1,
                    context: context,
                ),
            )
        }
        return currentBalance
    }

    /// 支払い実績を作成するヘルパー関数
    private func createOccurrence(
        definition: SpecialPaymentDefinition,
        params: CycleParams,
        context: ModelContext,
    ) -> SpecialPaymentOccurrence {
        let occurrence: SpecialPaymentOccurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: params.year, month: params.month) ?? Date(),
            expectedAmount: 150_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: params.actualAmount,
        )
        context.insert(occurrence)
        return occurrence
    }
}

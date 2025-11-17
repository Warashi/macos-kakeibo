import Foundation
@testable import Kakeibo
import SwiftData
import Testing

/// 定期支払い積立・充当ロジックの統合テスト（複数回支払いシナリオ）
///
/// 複数サイクルでの積立・支払いの繰り返しを検証します。
@Suite("RecurringPaymentSavings Multiple Payments Tests")
internal struct RecurringPaymentMultiplePaymentsTests {
    private let balanceService: RecurringPaymentBalanceService = RecurringPaymentBalanceService()

    @Test("複数回支払い：2回目、3回目の支払い")
    @DatabaseActor
    internal func multiplePaymentsScenario() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given: 年次支払い
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 4) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        var balance: SwiftDataRecurringPaymentSavingBalance?

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
    @DatabaseActor
    private func performFirstCycle(
        definition: SwiftDataRecurringPaymentDefinition,
        balance: SwiftDataRecurringPaymentSavingBalance?,
        context: ModelContext,
    ) -> SwiftDataRecurringPaymentSavingBalance? {
        let params: CycleParams = CycleParams(
            startMonth: 1,
            endMonth: 12,
            year: 2025,
            month: 4,
            actualAmount: 150_000,
        )

        let updatedBalance: SwiftDataRecurringPaymentSavingBalance? = performSavingCycle(
            definition: definition,
            balance: balance,
            params: params,
        )

        let occurrence = createOccurrence(definition: definition, params: params, context: context)
        if let finalBalance = updatedBalance {
            balanceService.processPayment(occurrence: occurrence, balance: finalBalance)
            return finalBalance
        }
        return updatedBalance
    }

    /// 2回目のサイクルを実行
    @DatabaseActor
    private func performSecondCycle(
        definition: SwiftDataRecurringPaymentDefinition,
        balance: SwiftDataRecurringPaymentSavingBalance?,
        context: ModelContext,
    ) -> SwiftDataRecurringPaymentSavingBalance? {
        let params: CycleParams = CycleParams(
            startMonth: 13,
            endMonth: 24,
            year: 2026,
            month: 4,
            actualAmount: 155_000,
        )

        let updatedBalance: SwiftDataRecurringPaymentSavingBalance? = performSavingCycle(
            definition: definition,
            balance: balance,
            params: params,
        )

        let occurrence = createOccurrence(definition: definition, params: params, context: context)
        if let finalBalance = updatedBalance {
            balanceService.processPayment(occurrence: occurrence, balance: finalBalance)
            return finalBalance
        }
        return updatedBalance
    }

    /// 3回目のサイクルを実行
    @DatabaseActor
    private func performThirdCycle(
        definition: SwiftDataRecurringPaymentDefinition,
        balance: SwiftDataRecurringPaymentSavingBalance?,
        context: ModelContext,
    ) throws -> SwiftDataRecurringPaymentSavingBalance {
        let params: CycleParams = CycleParams(
            startMonth: 25,
            endMonth: 36,
            year: 2027,
            month: 4,
            actualAmount: 145_000,
        )

        let updatedBalance: SwiftDataRecurringPaymentSavingBalance? = performSavingCycle(
            definition: definition,
            balance: balance,
            params: params,
        )

        let occurrence = createOccurrence(definition: definition, params: params, context: context)
        let finalBalance = try #require(updatedBalance)
        balanceService.processPayment(occurrence: occurrence, balance: finalBalance)
        return finalBalance
    }

    /// 指定範囲の月次積立を実行するヘルパー関数
    @DatabaseActor
    private func performSavingCycle(
        definition: SwiftDataRecurringPaymentDefinition,
        balance: SwiftDataRecurringPaymentSavingBalance?,
        params: CycleParams,
    ) -> SwiftDataRecurringPaymentSavingBalance? {
        var currentBalance: SwiftDataRecurringPaymentSavingBalance? = balance
        for month in params.startMonth ... params.endMonth {
            currentBalance = balanceService.recordMonthlySavings(
                params: RecurringPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: currentBalance,
                    year: 2024 + (month - 1) / 12,
                    month: ((month - 1) % 12) + 1,
                ),
            )
        }
        return currentBalance
    }

    /// 支払い実績を作成するヘルパー関数
    @DatabaseActor
    private func createOccurrence(
        definition: SwiftDataRecurringPaymentDefinition,
        params: CycleParams,
        context: ModelContext,
    ) -> SwiftDataRecurringPaymentOccurrence {
        let occurrence: SwiftDataRecurringPaymentOccurrence = SwiftDataRecurringPaymentOccurrence(
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

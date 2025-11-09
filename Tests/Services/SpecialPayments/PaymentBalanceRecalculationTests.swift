import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SpecialPaymentBalanceService - 残高再計算テスト")
internal struct PaymentBalanceRecalculationTests {
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

    @Test("残高の再計算：完了済みOccurrenceから集計")
    internal func recalculateBalance_fromOccurrences() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()

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

        // When: 2025年11月時点での再計算（積立開始は2025年1月）
        service.recalculateBalance(
            for: definition,
            balance: balance,
            year: 2025,
            month: 11,
            startYear: 2025,
            startMonth: 1,
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
}

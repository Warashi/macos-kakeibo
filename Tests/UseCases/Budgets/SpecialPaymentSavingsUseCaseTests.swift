import Foundation
import Testing
@testable import Kakeibo

@Suite
internal struct SpecialPaymentSavingsUseCaseTests {
    @Test("月次積立合計を算出する")
    internal func calculatesMonthlySavingsTotal() {
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 60_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5) ?? Date(),
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 5_000
        )
        let snapshot = BudgetSnapshot(
            budgets: [],
            transactions: [],
            categories: [],
            annualBudgetConfig: nil,
            specialPaymentDefinitions: [definition],
            specialPaymentBalances: []
        )
        let useCase = DefaultSpecialPaymentSavingsUseCase()

        let total = useCase.monthlySavingsTotal(snapshot: snapshot, year: 2025, month: 11)

        #expect(total == 5_000)
    }

    @Test("表示用エントリを生成する")
    internal func buildsEntries() throws {
        let definition = SpecialPaymentDefinition(
            name: "旅行",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 12) ?? Date(),
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 10_000
        )
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 30_000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 10
        )
        let snapshot = BudgetSnapshot(
            budgets: [],
            transactions: [],
            categories: [],
            annualBudgetConfig: nil,
            specialPaymentDefinitions: [definition],
            specialPaymentBalances: [balance]
        )
        let useCase = DefaultSpecialPaymentSavingsUseCase()

        let entries = useCase.entries(snapshot: snapshot, year: 2025, month: 11)
        let entry = try #require(entries.first)

        #expect(entry.name == "旅行")
        #expect(entry.monthlySaving == 10_000)
        #expect(entry.progress > 0)
    }
}

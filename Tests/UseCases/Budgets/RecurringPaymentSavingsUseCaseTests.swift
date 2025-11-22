import Foundation
@testable import Kakeibo
import Testing

@Suite
internal struct RecurringPaymentSavingsUseCaseTests {
    @Test("月次積立合計を算出する")
    internal func calculatesMonthlySavingsTotal() {
        let definition = RecurringPaymentDefinition(
            id: UUID(),
            name: "自動車税",
            notes: "",
            amount: 60000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5) ?? Date(),
            endDate: nil,
            categoryId: nil,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 5000,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: nil,
            createdAt: Date(),
            updatedAt: Date(),
        )
        let snapshot = BudgetSnapshot(
            budgets: [],
            transactions: [],
            categories: [],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [definition],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultRecurringPaymentSavingsUseCase()

        let total = useCase.monthlySavingsTotal(snapshot: snapshot, year: 2025, month: 11)

        #expect(total == 5000)
    }

    @Test("表示用エントリを生成する")
    internal func buildsEntries() throws {
        let definitionId = UUID()
        let definition = RecurringPaymentDefinition(
            id: definitionId,
            name: "旅行",
            notes: "",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 12) ?? Date(),
            endDate: nil,
            categoryId: nil,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 10000,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: nil,
            createdAt: Date(),
            updatedAt: Date(),
        )
        let balance = RecurringPaymentSavingBalance(
            id: UUID(),
            definitionId: definitionId,
            totalSavedAmount: 30000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 10,
            createdAt: Date(),
            updatedAt: Date(),
        )
        let snapshot = BudgetSnapshot(
            budgets: [],
            transactions: [],
            categories: [],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [definition],
            recurringPaymentBalances: [balance],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultRecurringPaymentSavingsUseCase()

        let entries = useCase.entries(snapshot: snapshot, year: 2025, month: 11)
        let entry = try #require(entries.first)

        #expect(entry.name == "旅行")
        #expect(entry.monthlySaving == 10000)
        #expect(entry.progress > 0)
    }
}

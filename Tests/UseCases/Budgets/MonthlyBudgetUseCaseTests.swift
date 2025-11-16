import Foundation
@testable import Kakeibo
import Testing

@Suite
internal struct MonthlyBudgetUseCaseTests {
    @Test("指定月の予算だけを返す")
    internal func filtersBudgetsByMonth() {
        let category = CategoryEntity(name: "食費", displayOrder: 1)
        let budgets = [
            BudgetEntity(amount: 5000, category: category, year: 2025, month: 11),
            BudgetEntity(amount: 6000, category: category, year: 2025, month: 12),
        ]
        let snapshot = BudgetSnapshot(
            budgets: budgets.map { BudgetDTO(from: $0) },
            transactions: [],
            categories: [Category(from: category)],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
        )
        let useCase = DefaultMonthlyBudgetUseCase()

        let results = useCase.monthlyBudgets(snapshot: snapshot, year: 2025, month: 11)

        #expect(results.count == 1)
        #expect(results.first?.startMonth == 11)
    }

    @Test("カテゴリ別エントリで実績が反映される")
    internal func categoryEntriesCalculateActuals() throws {
        let category = CategoryEntity(name: "食費", displayOrder: 1)
        let budget = BudgetEntity(amount: 5000, category: category, year: 2025, month: 11)
        let transaction = TransactionEntity(
            date: Date.from(year: 2025, month: 11, day: 5) ?? Date(),
            title: "ランチ",
            amount: -2000,
            majorCategory: category,
        )
        let snapshot = BudgetSnapshot(
            budgets: [BudgetDTO(from: budget)],
            transactions: [Transaction(from: transaction)],
            categories: [Category(from: category)],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
        )
        let useCase = DefaultMonthlyBudgetUseCase()

        let entries = useCase.categoryEntries(snapshot: snapshot, year: 2025, month: 11)

        let entry = try #require(entries.first)
        #expect(entry.calculation.actualAmount == 2000)
        #expect(entry.calculation.remainingAmount == 3000)
    }

    @Test("全体予算エントリを計算する")
    internal func overallEntryCalculatesTotals() {
        let overallBudget = BudgetEntity(amount: 10000, year: 2025, month: 11)
        let transaction = TransactionEntity(
            date: Date.from(year: 2025, month: 11, day: 1) ?? Date(),
            title: "家賃",
            amount: -8000,
        )
        let snapshot = BudgetSnapshot(
            budgets: [BudgetDTO(from: overallBudget)],
            transactions: [Transaction(from: transaction)],
            categories: [],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
        )
        let useCase = DefaultMonthlyBudgetUseCase()

        let entry = useCase.overallEntry(snapshot: snapshot, year: 2025, month: 11)

        #expect(entry?.calculation.actualAmount == 8000)
        #expect(entry?.calculation.remainingAmount == 2000)
        #expect(entry?.isOverallBudget == true)
    }
}

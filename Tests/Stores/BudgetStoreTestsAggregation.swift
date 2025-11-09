import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsAggregation {
    @Test("予算追加：カテゴリ別予算を集計できる")
    internal func categoryBudgetEntries_calculatesActuals() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費", allowsAnnualBudget: true, displayOrder: 1)
        context.insert(food)

        let transaction = Transaction(
            date: Date.from(year: store.currentYear, month: store.currentMonth) ?? Date(),
            title: "ランチ",
            amount: -2000,
            majorCategory: food,
        )

        context.insert(transaction)
        try context.save()

        try store.addBudget(
            amount: 5000,
            categoryId: food.id,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )

        let entries = store.categoryBudgetEntries
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.calculation.actualAmount == 2000)
        #expect(entry.calculation.remainingAmount == 3000)
        #expect(entry.calculation.isOverBudget == false)
    }

    @Test("年次予算：全体とカテゴリ別の集計を算出する")
    internal func annualBudgetEntries_calculatesYearlyTotals() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費", displayOrder: 1)
        let transport = Category(name: "交通", displayOrder: 2)
        context.insert(food)
        context.insert(transport)

        let year = store.currentYear

        let budgets: [Budget] = [
            Budget(amount: 100_000, year: year, month: 1),
            Budget(amount: 120_000, year: year, month: 2),
            Budget(amount: 50000, category: food, year: year, month: 1),
            Budget(amount: 60000, category: food, year: year, month: 2),
            Budget(amount: 40000, category: transport, year: year, month: 1),
        ]
        budgets.forEach(context.insert)

        let transactions: [Transaction] = [
            Transaction(
                date: makeDate(year: year, month: 1, day: 10),
                title: "食費1",
                amount: -20000,
                majorCategory: food,
            ),
            Transaction(
                date: makeDate(year: year, month: 2, day: 5),
                title: "食費2",
                amount: -30000,
                majorCategory: food,
            ),
            Transaction(
                date: makeDate(year: year, month: 1, day: 15),
                title: "交通費",
                amount: -10000,
                majorCategory: transport,
            ),
        ]
        transactions.forEach(context.insert)
        try context.save()

        let overallEntry = try #require(store.annualOverallBudgetEntry)
        #expect(overallEntry.calculation.budgetAmount == 220_000)
        #expect(overallEntry.calculation.actualAmount == 60000)
        #expect(overallEntry.isOverallBudget)

        let categoryEntries = store.annualCategoryBudgetEntries
        #expect(categoryEntries.count == 2)

        let foodEntry = try #require(categoryEntries.first { $0.title.contains("食費") })
        #expect(foodEntry.calculation.budgetAmount == 110_000)
        #expect(foodEntry.calculation.actualAmount == 50000)

        let transportEntry = try #require(categoryEntries.first { $0.title.contains("交通") })
        #expect(transportEntry.calculation.budgetAmount == 40000)
        #expect(transportEntry.calculation.actualAmount == 10000)
    }

    // MARK: - Helpers

    private func makeStore() throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = BudgetStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}

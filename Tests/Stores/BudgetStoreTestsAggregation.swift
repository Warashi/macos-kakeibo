import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsAggregation {
    @Test("予算追加：カテゴリ別予算を集計できる")
    internal func categoryBudgetEntries_calculatesActuals() async throws {
        let (store, context) = try await makeStore()
        let food = SwiftDataCategory(name: "食費", allowsAnnualBudget: true, displayOrder: 1)
        context.insert(food)

        let transaction = SwiftDataTransaction(
            date: Date.from(year: store.currentYear, month: store.currentMonth) ?? Date(),
            title: "ランチ",
            amount: -2000,
            majorCategory: food,
        )

        context.insert(transaction)
        try context.save()

        await store.refresh()

        let input = BudgetInput(
            amount: 5000,
            categoryId: food.id,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )
        try await store.addBudget(input)

        let entries = store.categoryBudgetEntries
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.calculation.actualAmount == 2000)
        #expect(entry.calculation.remainingAmount == 3000)
        #expect(entry.calculation.isOverBudget == false)
    }

    @Test("年次予算：全体とカテゴリ別の集計を算出する")
    internal func annualBudgetEntries_calculatesYearlyTotals() async throws {
        let (store, context) = try await makeStore()
        let food = SwiftDataCategory(name: "食費", displayOrder: 1)
        let transport = SwiftDataCategory(name: "交通", displayOrder: 2)
        context.insert(food)
        context.insert(transport)

        let year = store.currentYear

        let budgets: [SwiftDataBudget] = [
            SwiftDataBudget(amount: 100_000, year: year, month: 1),
            SwiftDataBudget(amount: 120_000, year: year, month: 2),
            SwiftDataBudget(amount: 50000, category: food, year: year, month: 1),
            SwiftDataBudget(amount: 60000, category: food, year: year, month: 2),
            SwiftDataBudget(amount: 40000, category: transport, year: year, month: 1),
        ]
        budgets.forEach(context.insert)

        let transactions: [SwiftDataTransaction] = [
            SwiftDataTransaction(
                date: makeDate(year: year, month: 1, day: 10),
                title: "食費1",
                amount: -20000,
                majorCategory: food,
            ),
            SwiftDataTransaction(
                date: makeDate(year: year, month: 2, day: 5),
                title: "食費2",
                amount: -30000,
                majorCategory: food,
            ),
            SwiftDataTransaction(
                date: makeDate(year: year, month: 1, day: 15),
                title: "交通費",
                amount: -10000,
                majorCategory: transport,
            ),
        ]
        transactions.forEach(context.insert)
        try context.save()

        await store.refresh()
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

    @MainActor
    private func makeStore() async throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = try await makeBudgetStore(container: container, context: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    private func makeBudgetStore(container: ModelContainer, context _: ModelContext) async throws -> BudgetStore {
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        let calculator = BudgetCalculator()
        let monthlyUseCase = DefaultMonthlyBudgetUseCase(calculator: calculator)
        let annualUseCase = DefaultAnnualBudgetUseCase()
        let recurringPaymentUseCase = DefaultRecurringPaymentSavingsUseCase(calculator: calculator)
        let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)

        return await BudgetStore(
            repository: repository,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            recurringPaymentUseCase: recurringPaymentUseCase,
            mutationUseCase: mutationUseCase,
        )
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}

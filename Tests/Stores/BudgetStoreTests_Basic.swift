import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTests_Basic {
    @Test("初期化：現在の年月で開始する")
    internal func initialization_setsCurrentDate() throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let store = BudgetStore(modelContext: context)
        let now = Date()

        #expect(store.currentYear == now.year)
        #expect(store.currentMonth == now.month)
    }

    @Test("予算追加：全体予算を作成できる")
    internal func addBudget_createsOverallBudget() throws {
        let (store, _) = try makeStore()

        try store.addBudget(
            amount: 50000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )

        #expect(store.monthlyBudgets.count == 1)
        #expect(store.overallBudgetEntry?.calculation.budgetAmount == 50000)
        #expect(store.overallBudgetEntry?.calculation.actualAmount == 0)
    }

    @Test("期間予算は複数月で参照できる")
    internal func periodBudget_appliesAcrossMonths() throws {
        let (store, _) = try makeStore()

        try store.addBudget(
            amount: 4000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear + 1,
            endMonth: 1,
        )

        #expect(store.monthlyBudgets.count == 1)
        store.moveToNextMonth()
        #expect(store.monthlyBudgets.count == 1)
        store.moveToNextMonth()
        #expect(store.monthlyBudgets.count == 1)
    }

    @Test("期間が不正な場合はエラーになる")
    internal func addBudget_invalidPeriodThrows() throws {
        let (store, _) = try makeStore()

        #expect(
            throws: BudgetStoreError.invalidPeriod,
        ) {
            try store.addBudget(
                amount: 1000,
                categoryId: nil,
                startYear: store.currentYear,
                startMonth: store.currentMonth,
                endYear: store.currentYear,
                endMonth: store.currentMonth - 1,
            )
        }
    }

    @Test("予算更新：金額とカテゴリを変更できる")
    internal func updateBudget_changesValues() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費", displayOrder: 1)
        let transport = Category(name: "交通", displayOrder: 2)
        context.insert(food)
        context.insert(transport)

        let budget = Budget(
            amount: 10000,
            category: food,
            year: store.currentYear,
            month: store.currentMonth,
        )
        context.insert(budget)
        try context.save()

        try store.updateBudget(
            budget: budget,
            amount: 12000,
            categoryId: transport.id,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth + 1,
        )

        #expect(budget.amount == 12000)
        #expect(budget.category?.id == transport.id)
        #expect(budget.endMonth == store.currentMonth + 1)
    }

    @Test("予算削除：削除後にリストから除外される")
    internal func deleteBudget_removesBudget() throws {
        let (store, context) = try makeStore()
        let budget = Budget(
            amount: 8000,
            year: store.currentYear,
            month: store.currentMonth,
        )
        context.insert(budget)
        try context.save()

        try store.deleteBudget(budget)

        #expect(store.monthlyBudgets.isEmpty)
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

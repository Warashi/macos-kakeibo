import Foundation
import SwiftData
@testable import Kakeibo
import Testing

@Suite(.serialized)
internal struct BudgetStackBuilderTests {
    @Test("BudgetStore を構築して予算を読み込める")
    func makeStoreLoadsBudgets() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let dependencies = await BudgetStackBuilder.makeDependencies(modelContainer: container)

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let majorId = try await dependencies.repository.createCategory(name: "生活費", parentId: nil)
        let minorId = try await dependencies.repository.createCategory(name: "食費", parentId: majorId)
        let input = BudgetInput(
            amount: Decimal(50_000),
            categoryId: minorId,
            startYear: currentYear,
            startMonth: currentMonth,
            endYear: currentYear,
            endMonth: currentMonth
        )
        try await dependencies.repository.addBudget(input)
        try await dependencies.repository.saveChanges()

        let store = await BudgetStackBuilder.makeStore(modelContainer: container)
        await store.refresh()

        let budgets = await MainActor.run { store.monthlyBudgets }
        #expect(budgets.count == 1)
        #expect(budgets.first?.amount == Decimal(50_000))
    }

    @Test("BudgetModelActor 経由でも BudgetStore を構築できる")
    func makeStoreViaModelActor() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let modelActor = BudgetModelActor(modelContainer: container)
        let dependencies = await BudgetStackBuilder.makeDependencies(modelActor: modelActor)

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let categoryId = try await dependencies.repository.createCategory(name: "住居", parentId: nil)
        let input = BudgetInput(
            amount: Decimal(80_000),
            categoryId: categoryId,
            startYear: year,
            startMonth: month,
            endYear: year,
            endMonth: month
        )
        try await dependencies.repository.addBudget(input)
        try await dependencies.repository.saveChanges()

        let store = await BudgetStackBuilder.makeStore(modelActor: modelActor)
        await store.refresh()

        let budgets = await MainActor.run { store.monthlyBudgets }
        #expect(budgets.count == 1)
        #expect(budgets.first?.amount == Decimal(80_000))
    }
}

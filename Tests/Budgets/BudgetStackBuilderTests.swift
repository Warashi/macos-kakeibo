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

        try await Task { @DatabaseActor in
            let majorId = try dependencies.repository.createCategory(name: "生活費", parentId: nil)
            let minorId = try dependencies.repository.createCategory(name: "食費", parentId: majorId)
            let input = BudgetInput(
                amount: Decimal(50_000),
                categoryId: minorId,
                startYear: currentYear,
                startMonth: currentMonth,
                endYear: currentYear,
                endMonth: currentMonth
            )
            try dependencies.repository.addBudget(input)
            try dependencies.repository.saveChanges()
        }.value

        let store = await BudgetStackBuilder.makeStore(modelContainer: container)
        await store.refresh()

        let budgets = await MainActor.run { store.monthlyBudgets }
        #expect(budgets.count == 1)
        #expect(budgets.first?.amount == Decimal(50_000))
    }
}

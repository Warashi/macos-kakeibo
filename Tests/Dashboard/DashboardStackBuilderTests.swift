import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct DashboardStackBuilderTests {
    @Test("DashboardStore を構築して月次サマリを読み込める")
    func makeStoreLoadsMonthlySummary() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let category = SwiftDataCategory(name: "食費")
        context.insert(category)
        let expenseDate = try #require(Date.from(year: 2025, month: 4, day: 10))
        let transaction = SwiftDataTransaction(
            date: expenseDate,
            title: "ランチ",
            amount: -1500,
            majorCategory: category,
        )
        context.insert(transaction)
        try context.save()

        let store = await DashboardStackBuilder.makeStore(modelContainer: container)
        store.currentYear = expenseDate.year
        store.currentMonth = expenseDate.month
        await store.refresh()

        let summary = store.monthlySummary
        #expect(summary.year == expenseDate.year)
        #expect(summary.month == expenseDate.month)
        #expect(summary.totalExpense == 1500)
        #expect(summary.transactionCount == 1)
    }
}

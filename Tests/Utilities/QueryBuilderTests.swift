import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct QueryBuilderTests {
    @Test("TransactionQueries.list は対象月のみを取得する")
    internal func transactionQueries_filtersByMonth() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let targetMonth = try #require(Date.from(year: 2025, month: 5, day: 10))
        let outsideMonth = try #require(Date.from(year: 2025, month: 6, day: 3))

        context.insert(Transaction(date: targetMonth, title: "今月", amount: -1000))
        context.insert(Transaction(date: outsideMonth, title: "来月", amount: -2000))
        try context.save()

        let query = TransactionQuery(
            month: targetMonth,
            filterKind: .all,
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            institutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
            searchText: "",
            sortOption: .dateDescending,
        )

        let transactions = try context.fetch(TransactionQueries.list(query: query))
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "今月")
    }

    @Test("BudgetQueries.annualConfig は指定年のみ取得する")
    internal func budgetQueries_fetchesAnnualConfig() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        context.insert(AnnualBudgetConfig(year: 2024, totalAmount: 100_000, policy: .automatic))
        context.insert(AnnualBudgetConfig(year: 2025, totalAmount: 120_000, policy: .automatic))
        try context.save()

        let descriptor = BudgetQueries.annualConfig(for: 2025)
        let configs = try context.fetch(descriptor)

        #expect(configs.count == 1)
        #expect(configs.first?.year == 2025)
    }

    @Test("SpecialPaymentQueries.definitions は作成日時の降順で並ぶ")
    internal func specialPaymentQueries_sortsDefinitions() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let earlier = SpecialPaymentDefinition(
            name: "古い支払い",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            leadTimeMonths: 0,
        )
        earlier.createdAt = Date(timeIntervalSince1970: 1000)

        let latest = SpecialPaymentDefinition(
            name: "新しい支払い",
            amount: 20000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            leadTimeMonths: 0,
        )
        latest.createdAt = Date(timeIntervalSince1970: 2000)

        context.insert(earlier)
        context.insert(latest)
        try context.save()

        let descriptor = SpecialPaymentQueries.definitions()
        let definitions = try context.fetch(descriptor)

        #expect(definitions.first?.name == "新しい支払い")
        #expect(definitions.last?.name == "古い支払い")
    }
}

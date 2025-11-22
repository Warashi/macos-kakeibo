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

        context.insert(SwiftDataTransaction(date: targetMonth, title: "今月", amount: -1000))
        context.insert(SwiftDataTransaction(date: outsideMonth, title: "来月", amount: -2000))
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

        context.insert(SwiftDataAnnualBudgetConfig(year: 2024, totalAmount: 100_000, policy: .automatic))
        context.insert(SwiftDataAnnualBudgetConfig(year: 2025, totalAmount: 120_000, policy: .automatic))
        try context.save()

        let descriptor = BudgetQueries.annualConfig(for: 2025)
        let configs = try context.fetch(descriptor)

        #expect(configs.count == 1)
        #expect(configs.first?.year == 2025)
    }

    @Test("RecurringPaymentQueries.definitions は作成日時の降順で並ぶ")
    internal func recurringPaymentQueries_sortsDefinitions() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let earlier = SwiftDataRecurringPaymentDefinition(
            name: "古い支払い",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            leadTimeMonths: 1,
        )
        earlier.createdAt = Date(timeIntervalSince1970: 1000)

        let latest = SwiftDataRecurringPaymentDefinition(
            name: "新しい支払い",
            amount: 20000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            leadTimeMonths: 1,
        )
        latest.createdAt = Date(timeIntervalSince1970: 2000)

        context.insert(earlier)
        context.insert(latest)
        try context.save()

        let descriptor = RecurringPaymentQueries.definitions()
        let definitions = try context.fetch(descriptor)

        #expect(definitions.first?.name == "新しい支払い")
        #expect(definitions.last?.name == "古い支払い")
    }
}

@Suite(.serialized)
internal struct ModelContextObservationTests {
    @Test("observe はメインアクタ外でスナップショットを配送する")
    internal func observe_deliversSnapshotsOffMainActor() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let descriptor = TransactionQueries.allSorted()
        let recorder = ObservationRecorder()

        let handle = context.observe(
            descriptor: descriptor,
            transform: { models in models.count },
            onChange: { count in
                let isMainThread = Thread.isMainThread
                Task {
                    await recorder.record(count: count, isMainThread: isMainThread)
                }
            },
        )

        context.insert(SwiftDataTransaction(date: Date(), title: "テスト", amount: -1000))
        try context.save()

        try? await Task.sleep(for: .milliseconds(100))
        handle.cancel()

        let counts = await recorder.counts
        #expect(counts.contains(1))
        let flags = await recorder.mainThreadFlags
        #expect(flags.contains(false))
    }

    @MainActor
    @Test("observeOnMainActor は変換済みデータをUIスレッドへ配送する")
    internal func observeOnMainActor_deliversTransformedData() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let descriptor = TransactionQueries.allSorted()
        var receivedSnapshots: [[String]] = []

        let handle = context.observeOnMainActor(
            descriptor: descriptor,
            transform: { models in models.map(\.title) },
            onChange: { titles in
                receivedSnapshots.append(titles)
                #expect(Thread.isMainThread)
            },
        )

        context.insert(SwiftDataTransaction(date: Date(), title: "夕食", amount: -1500))
        try context.save()

        try? await Task.sleep(for: .milliseconds(100))
        handle.cancel()

        #expect(receivedSnapshots.last == ["夕食"])
    }
}

// MARK: - Helpers

private actor ObservationRecorder {
    private(set) var counts: [Int] = []
    private(set) var mainThreadFlags: [Bool] = []

    func record(count: Int, isMainThread: Bool) {
        counts.append(count)
        mainThreadFlags.append(isMainThread)
    }
}

import SwiftData
import SwiftUI
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentListView Tests")
@MainActor
internal struct RecurringPaymentListViewTests {
    @Test("RecurringPaymentListView本体を初期化できる")
    internal func recurringPaymentListViewInitialization() {
        let view = RecurringPaymentListView()
        let _: any View = view
    }

    @Test("RecurringPaymentListContentViewにストアを渡して初期化できる")
    internal func recurringPaymentListContentViewInitialization() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let store = RecurringPaymentListStore(repository: repository, budgetRepository: SwiftDataBudgetRepository(modelContainer: container))

        let view = RecurringPaymentListContentView(store: store)
        let _: any View = view
    }

    @Test("空のストアで entries が空であることを確認")
    internal func emptyStoreHasNoEntries() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let store = RecurringPaymentListStore(repository: repository, budgetRepository: SwiftDataBudgetRepository(modelContainer: container))

        let entries = await store.entries()
        #expect(entries.isEmpty)
    }

    @Test("サンプルデータを投入して entries が取得できることを確認")
    internal func storeReturnsEntriesWithSampleData() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // サンプルデータを投入
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        context.insert(definition)
        context.insert(occurrence)
        try context.save()

        // ストアを作成
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let store = RecurringPaymentListStore(repository: repository, budgetRepository: SwiftDataBudgetRepository(modelContainer: container))
        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // エントリが取得できることを確認
        let entries = await store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.name == "自動車税")
        #expect(entries.first?.expectedAmount == 45000)
    }

    @Test("検索テキストフィルタが機能することを確認")
    internal func searchTextFilterWorks() async throws {
        let (store, _) = try await makeStoreWithMultipleEntries()

        // 検索テキストを設定
        store.searchText = "自動車"

        // フィルタされたエントリを確認
        let entries = await store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.name == "自動車税")
    }

    @Test("ステータスフィルタが機能することを確認")
    internal func statusFilterWorks() async throws {
        let (store, _) = try await makeStoreWithMultipleEntries()

        // completedステータスでフィルタ
        store.selectedStatus = .completed

        // フィルタされたエントリを確認
        let entries = await store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.status == .completed)
    }

    @Test("複数エントリでソート機能が正しく動作することを確認")
    internal func sortingWorksWithMultipleEntries() async throws {
        let (store, _) = try await makeStoreWithMultipleEntries()

        // 日付昇順でソート
        store.sortOrder = .dateAscending
        let ascendingEntries = await store.entries()
        #expect(ascendingEntries.count == 3)
        #expect(ascendingEntries[0].scheduledDate < ascendingEntries[1].scheduledDate)
        #expect(ascendingEntries[1].scheduledDate < ascendingEntries[2].scheduledDate)

        // 日付降順でソート
        store.sortOrder = .dateDescending
        let descendingEntries = await store.entries()
        #expect(descendingEntries[0].scheduledDate > descendingEntries[1].scheduledDate)
        #expect(descendingEntries[1].scheduledDate > descendingEntries[2].scheduledDate)
    }

    @Test("複数ステータスのエントリが正しく表示されることを確認")
    internal func multipleStatusEntriesDisplayCorrectly() async throws {
        let (store, _) = try await makeStoreWithMultipleEntries()

        // すべてのエントリを取得
        let allEntries = await store.entries()

        // 各ステータスのエントリが存在することを確認
        #expect(allEntries.contains(where: { $0.status == .saving }))
        #expect(allEntries.contains(where: { $0.status == .completed }))
        #expect(allEntries.contains(where: { $0.status == .planned }))
    }

    @Test("フィルタリセット機能が正しく動作することを確認")
    internal func resetFiltersWorks() async throws {
        let (store, _) = try await makeStoreWithMultipleEntries()

        // フィルタを設定
        store.searchText = "テスト"
        store.selectedStatus = .completed
        store.dateRange.startDate = Date.from(year: 2025, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2025, month: 12) ?? Date()

        // リセット
        store.resetFilters()

        // フィルタがリセットされたことを確認
        #expect(store.searchText == "")
        #expect(store.selectedStatus == nil)
        #expect(store.categoryFilter.selectedMajorCategoryId == nil)
        #expect(store.categoryFilter.selectedMinorCategoryId == nil)

        // 期間が当月〜6ヶ月後にリセットされることを確認
        let now = Date()
        let expectedStart = Calendar.current.startOfMonth(for: now)
        #expect(store.dateRange.startDate.timeIntervalSince(expectedStart ?? now) < 60)
    }

    // MARK: - Helpers

    private func makeStoreWithMultipleEntries() async throws -> (RecurringPaymentListStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // 複数のサンプルデータを作成
        let definition1 = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let definition2 = SwiftDataRecurringPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 4) ?? Date(),
        )

        let definition3 = SwiftDataRecurringPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
        )

        let occurrence1 = SwiftDataRecurringPaymentOccurrence(
            definition: definition1,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        let occurrence2 = SwiftDataRecurringPaymentOccurrence(
            definition: definition2,
            scheduledDate: Date.from(year: 2026, month: 4) ?? Date(),
            expectedAmount: 150_000,
            status: .completed,
            actualDate: Date.from(year: 2026, month: 4),
            actualAmount: 150_000,
        )

        let occurrence3 = SwiftDataRecurringPaymentOccurrence(
            definition: definition3,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 120_000,
            status: .planned,
        )

        context.insert(definition1)
        context.insert(definition2)
        context.insert(definition3)
        context.insert(occurrence1)
        context.insert(occurrence2)
        context.insert(occurrence3)
        try context.save()

        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let store = RecurringPaymentListStore(repository: repository, budgetRepository: SwiftDataBudgetRepository(modelContainer: container))
        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()

        return (store, context)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}

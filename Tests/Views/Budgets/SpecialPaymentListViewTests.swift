import SwiftData
import SwiftUI
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentListView Tests")
@MainActor
internal struct SpecialPaymentListViewTests {
    @Test("SpecialPaymentListView本体を初期化できる")
    internal func specialPaymentListViewInitialization() {
        let view = SpecialPaymentListView()
        let _: any View = view
    }

    @Test("SpecialPaymentListContentViewにストアを渡して初期化できる")
    internal func specialPaymentListContentViewInitialization() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentListStore(modelContext: context)

        let view = SpecialPaymentListContentView(store: store)
        let _: any View = view
    }

    @Test("空のストアで entries が空であることを確認")
    internal func emptyStoreHasNoEntries() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentListStore(modelContext: context)

        #expect(store.entries.isEmpty)
    }

    @Test("サンプルデータを投入して entries が取得できることを確認")
    internal func storeReturnsEntriesWithSampleData() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // サンプルデータを投入
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        context.insert(definition)
        context.insert(occurrence)
        try context.save()

        // ストアを作成
        let store = SpecialPaymentListStore(modelContext: context)
        store.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // エントリが取得できることを確認
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.name == "自動車税")
        #expect(store.entries.first?.expectedAmount == 45000)
    }
}

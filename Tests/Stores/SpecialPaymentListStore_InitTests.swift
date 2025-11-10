import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentListStoreInitTests {
    @Test("初期化：デフォルト期間が当月〜6ヶ月後")
    internal func initialization_defaultPeriod() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let store = SpecialPaymentListStore(modelContext: context)
        let now = Date()

        let expectedStart = Calendar.current.startOfMonth(for: now)
        let expectedEnd = Calendar.current.date(byAdding: .month, value: 6, to: expectedStart ?? now)

        #expect(store.dateRange.startDate.timeIntervalSince(expectedStart ?? now) < 60) // 1分以内
        #expect(store.dateRange.endDate.timeIntervalSince(expectedEnd ?? now) < 60)
        #expect(store.searchText == "")
        #expect(store.categoryFilter.selectedMajorCategoryId == nil)
        #expect(store.categoryFilter.selectedMinorCategoryId == nil)
        #expect(store.selectedStatus == nil)
        #expect(store.sortOrder == .dateAscending)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}

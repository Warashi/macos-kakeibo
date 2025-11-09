import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentListStoreFilterTests {
    @Test("entries: 期間フィルタが適用される")
    internal func entries_periodFilter() throws {
        let (store, context) = try makeStore()

        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        // 期間内
        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        // 期間外（過去）
        let occurrence2 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 1) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
        )

        // 期間外（未来）
        let occurrence3 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2027, month: 1) ?? Date(),
            expectedAmount: 45000,
            status: .planned,
        )

        context.insert(definition)
        context.insert(occurrence1)
        context.insert(occurrence2)
        context.insert(occurrence3)
        try context.save()

        // When: 2026/1〜2026/6の期間
        store.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.endDate = Date.from(year: 2026, month: 6) ?? Date()

        // Then
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.scheduledDate == occurrence1.scheduledDate)
    }

    @Test("entries: 検索テキストフィルタが適用される")
    internal func entries_searchTextFilter() throws {
        let (store, context) = try makeStore()

        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let definition2 = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 4) ?? Date(),
        )

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition1,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        let occurrence2 = SpecialPaymentOccurrence(
            definition: definition2,
            scheduledDate: Date.from(year: 2026, month: 4) ?? Date(),
            expectedAmount: 150_000,
            status: .saving,
        )

        context.insert(definition1)
        context.insert(definition2)
        context.insert(occurrence1)
        context.insert(occurrence2)
        try context.save()

        store.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // When
        store.searchText = "自動車"

        // Then
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.name == "自動車税")
    }

    @Test("entries: ステータスフィルタが適用される")
    internal func entries_statusFilter() throws {
        let (store, context) = try makeStore()

        let definition = SpecialPaymentDefinition(
            name: "テスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 10000,
            status: .saving,
        )

        let occurrence2 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 4) ?? Date(),
            expectedAmount: 10000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 10000,
        )

        context.insert(definition)
        context.insert(occurrence1)
        context.insert(occurrence2)
        try context.save()

        store.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // When
        store.selectedStatus = .completed

        // Then
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.status == .completed)
    }

    @Test("entries: 大項目フィルタで配下の中項目も含まれる")
    internal func entries_majorCategoryFilterIncludesChildren() throws {
        let (store, context) = try makeStore()

        let major = Category(name: "生活費")
        let minor = Category(name: "食費", parent: major)
        let otherMajor = Category(name: "趣味")

        context.insert(major)
        context.insert(minor)
        context.insert(otherMajor)

        let definitionMajor = SpecialPaymentDefinition(
            name: "家賃",
            amount: 80000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
            category: major,
        )

        let definitionMinor = SpecialPaymentDefinition(
            name: "外食",
            amount: 15000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 2) ?? Date(),
            category: minor,
        )

        let definitionOther = SpecialPaymentDefinition(
            name: "サブスク",
            amount: 2000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
            category: otherMajor,
        )

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definitionMajor,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 80000,
            status: .saving,
        )

        let occurrence2 = SpecialPaymentOccurrence(
            definition: definitionMinor,
            scheduledDate: Date.from(year: 2026, month: 2) ?? Date(),
            expectedAmount: 15000,
            status: .saving,
        )

        let occurrence3 = SpecialPaymentOccurrence(
            definition: definitionOther,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 2000,
            status: .saving,
        )

        context.insert(definitionMajor)
        context.insert(definitionMinor)
        context.insert(definitionOther)
        context.insert(occurrence1)
        context.insert(occurrence2)
        context.insert(occurrence3)
        try context.save()

        store.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.endDate = Date.from(year: 2026, month: 12) ?? Date()

        store.selectedMajorCategoryId = major.id

        let filteredDefinitions = Set(store.entries.map(\.definitionId))
        #expect(filteredDefinitions.contains(definitionMajor.id))
        #expect(filteredDefinitions.contains(definitionMinor.id))
        #expect(!filteredDefinitions.contains(definitionOther.id))
    }

    @Test("entries: 中項目フィルタは該当カテゴリのみを対象にする")
    internal func entries_minorCategoryFilterIsPrecise() throws {
        let (store, context) = try makeStore()

        let major = Category(name: "生活費")
        let minor = Category(name: "食費", parent: major)
        let anotherMinor = Category(name: "日用品", parent: major)

        context.insert(major)
        context.insert(minor)
        context.insert(anotherMinor)

        let definitionMinor = SpecialPaymentDefinition(
            name: "外食",
            amount: 15000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 2) ?? Date(),
            category: minor,
        )

        let definitionAnother = SpecialPaymentDefinition(
            name: "日用品",
            amount: 8000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 2) ?? Date(),
            category: anotherMinor,
        )

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definitionMinor,
            scheduledDate: Date.from(year: 2026, month: 2) ?? Date(),
            expectedAmount: 15000,
            status: .saving,
        )

        let occurrence2 = SpecialPaymentOccurrence(
            definition: definitionAnother,
            scheduledDate: Date.from(year: 2026, month: 2) ?? Date(),
            expectedAmount: 8000,
            status: .saving,
        )

        context.insert(definitionMinor)
        context.insert(definitionAnother)
        context.insert(occurrence1)
        context.insert(occurrence2)
        try context.save()

        store.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.endDate = Date.from(year: 2026, month: 12) ?? Date()
        store.selectedMajorCategoryId = major.id
        store.selectedMinorCategoryId = minor.id

        let filteredDefinitions = Set(store.entries.map(\.definitionId))
        #expect(filteredDefinitions == Set([definitionMinor.id]))
    }

    @Test("resetFilters: フィルタがリセットされる")
    internal func resetFilters_clearsAllFilters() throws {
        let (store, _) = try makeStore()

        // Given
        store.searchText = "テスト"
        store.selectedMajorCategoryId = UUID()
        store.selectedMinorCategoryId = UUID()
        store.selectedStatus = .completed
        store.startDate = Date.from(year: 2025, month: 1) ?? Date()
        store.endDate = Date.from(year: 2025, month: 12) ?? Date()

        // When
        store.resetFilters()

        // Then
        #expect(store.searchText == "")
        #expect(store.selectedMajorCategoryId == nil)
        #expect(store.selectedMinorCategoryId == nil)
        #expect(store.selectedStatus == nil)
        // 期間は当月〜6ヶ月後にリセットされる
        let now = Date()
        let expectedStart = Calendar.current.startOfMonth(for: now)
        #expect(store.startDate.timeIntervalSince(expectedStart ?? now) < 60)
    }

    // MARK: - Helpers

    private func makeStore() throws -> (SpecialPaymentListStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentListStore(modelContext: context)
        return (store, context)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}

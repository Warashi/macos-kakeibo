import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentListStoreFilterTests {
    @Test("entries: 期間フィルタが適用される")
    internal func entries_periodFilter() async throws {
        let (store, context) = try await makeStore()

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        // 期間内
        let occurrence1 = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        // 期間外（過去）
        let occurrence2 = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 1) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
        )

        // 期間外（未来）
        let occurrence3 = SwiftDataRecurringPaymentOccurrence(
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
        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 6) ?? Date()

        // Then
        let entries = await store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.scheduledDate == occurrence1.scheduledDate)
    }

    @Test("entries: 検索テキストフィルタが適用される")
    internal func entries_searchTextFilter() async throws {
        let (store, context) = try await makeStore()

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
            status: .saving,
        )

        context.insert(definition1)
        context.insert(definition2)
        context.insert(occurrence1)
        context.insert(occurrence2)
        try context.save()

        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // When
        store.searchText = "自動車"

        // Then
        let entries = await store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.name == "自動車税")
    }

    @Test("entries: ステータスフィルタが適用される")
    internal func entries_statusFilter() async throws {
        let (store, context) = try await makeStore()

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "テスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence1 = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 10000,
            status: .saving,
        )

        let occurrence2 = SwiftDataRecurringPaymentOccurrence(
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

        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()

        // When
        store.selectedStatus = .completed

        // Then
        let entries = await store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.status == RecurringPaymentStatus.completed)
    }

    @Test("entries: 大項目フィルタで配下の中項目も含まれる")
    internal func entries_majorCategoryFilterIncludesChildren() async throws {
        let (store, context) = try await makeStore()
        let fixture = try seedMajorCategoryFixture(in: context)

        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()
        store.categoryFilter.updateCategories([
            Category(from: fixture.major),
            Category(from: fixture.minor),
            Category(from: fixture.otherMajor),
        ])
        store.categoryFilter.selectedMajorCategoryId = fixture.major.id

        let entries = await store.entries()
        let filteredDefinitions = Set(entries.map(\.definitionId))
        #expect(filteredDefinitions.contains(fixture.majorDefinition.id))
        #expect(filteredDefinitions.contains(fixture.minorDefinition.id))
        #expect(!filteredDefinitions.contains(fixture.otherDefinition.id))
    }

    @Test("entries: 中項目フィルタは該当カテゴリのみを対象にする")
    internal func entries_minorCategoryFilterIsPrecise() async throws {
        let (store, context) = try await makeStore()
        let fixture = try seedMinorCategoryFixture(in: context)

        store.dateRange.startDate = Date.from(year: 2026, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2026, month: 12) ?? Date()
        store.categoryFilter.updateCategories([
            Category(from: fixture.major),
            Category(from: fixture.minor),
            Category(from: fixture.anotherMinor),
        ])
        store.categoryFilter.selectedMajorCategoryId = fixture.major.id
        store.categoryFilter.selectedMinorCategoryId = fixture.minor.id

        let entries = await store.entries()
        let filteredDefinitions = Set(entries.map(\.definitionId))
        #expect(filteredDefinitions == Set([fixture.minorDefinition.id]))
    }

    @Test("resetFilters: フィルタがリセットされる")
    internal func resetFilters_clearsAllFilters() async throws {
        let (store, _) = try await makeStore()

        // Given
        store.searchText = "テスト"
        store.categoryFilter.selectedMajorCategoryId = UUID()
        store.categoryFilter.selectedMinorCategoryId = UUID()
        store.selectedStatus = .completed
        store.dateRange.startDate = Date.from(year: 2025, month: 1) ?? Date()
        store.dateRange.endDate = Date.from(year: 2025, month: 12) ?? Date()

        // When
        store.resetFilters()

        // Then
        #expect(store.searchText == "")
        #expect(store.categoryFilter.selectedMajorCategoryId == nil)
        #expect(store.categoryFilter.selectedMinorCategoryId == nil)
        #expect(store.selectedStatus == nil)
        // 期間は当月〜6ヶ月後にリセットされる
        let now = Date()
        let expectedStart = Calendar.current.startOfMonth(for: now)
        #expect(store.dateRange.startDate.timeIntervalSince(expectedStart ?? now) < 60)
    }

    @Test("refreshEntriesはバックグラウンドTaskからでもキャッシュを更新する")
    internal func refreshEntries_updatesCacheFromDetachedTask() async throws {
        let (store, context) = try await makeStore()
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "定期支払いテスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )
        let occurrence = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 2) ?? Date(),
            expectedAmount: 10000,
            status: .planned,
        )
        context.insert(definition)
        context.insert(occurrence)
        try context.save()

        store.dateRange = DateRange(
            startDate: Date.from(year: 2024, month: 1) ?? Date.distantPast,
            endDate: Date.from(year: 2026, month: 12) ?? Date.distantFuture,
        )

        let backgroundTask = Task.detached {
            await store.refreshEntries()
        }
        await backgroundTask.value

        #expect(store.cachedEntries.count == 1)
        #expect(store.cachedEntries.first?.name == "定期支払いテスト")
    }

    // MARK: - Helpers

    private func makeStore() async throws -> (RecurringPaymentListStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let store = RecurringPaymentListStore(repository: repository)
        return (store, context)
    }

    private func seedMajorCategoryFixture(in context: ModelContext) throws -> MajorCategoryFixture {
        let major = SwiftDataCategory(name: "生活費")
        let minor = SwiftDataCategory(name: "食費", parent: major)
        let otherMajor = SwiftDataCategory(name: "趣味")

        context.insert(major)
        context.insert(minor)
        context.insert(otherMajor)

        let definitionMajor = SwiftDataRecurringPaymentDefinition(
            name: "家賃",
            amount: 80000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
            category: major,
        )

        let definitionMinor = SwiftDataRecurringPaymentDefinition(
            name: "外食",
            amount: 15000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 2) ?? Date(),
            category: minor,
        )

        let definitionOther = SwiftDataRecurringPaymentDefinition(
            name: "サブスク",
            amount: 2000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
            category: otherMajor,
        )

        let occurrence1 = SwiftDataRecurringPaymentOccurrence(
            definition: definitionMajor,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 80000,
            status: .saving,
        )

        let occurrence2 = SwiftDataRecurringPaymentOccurrence(
            definition: definitionMinor,
            scheduledDate: Date.from(year: 2026, month: 2) ?? Date(),
            expectedAmount: 15000,
            status: .saving,
        )

        let occurrence3 = SwiftDataRecurringPaymentOccurrence(
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

        return MajorCategoryFixture(
            major: major,
            minor: minor,
            otherMajor: otherMajor,
            majorDefinition: definitionMajor,
            minorDefinition: definitionMinor,
            otherDefinition: definitionOther
        )
    }

    private func seedMinorCategoryFixture(in context: ModelContext) throws -> MinorCategoryFixture {
        let major = SwiftDataCategory(name: "生活費")
        let minor = SwiftDataCategory(name: "食費", parent: major)
        let anotherMinor = SwiftDataCategory(name: "日用品", parent: major)

        context.insert(major)
        context.insert(minor)
        context.insert(anotherMinor)

        let definitionMinor = SwiftDataRecurringPaymentDefinition(
            name: "外食",
            amount: 15000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 2) ?? Date(),
            category: minor,
        )

        let definitionAnother = SwiftDataRecurringPaymentDefinition(
            name: "日用品",
            amount: 8000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date.from(year: 2026, month: 2) ?? Date(),
            category: anotherMinor,
        )

        let occurrence1 = SwiftDataRecurringPaymentOccurrence(
            definition: definitionMinor,
            scheduledDate: Date.from(year: 2026, month: 2) ?? Date(),
            expectedAmount: 15000,
            status: .saving,
        )

        let occurrence2 = SwiftDataRecurringPaymentOccurrence(
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

        return MinorCategoryFixture(
            major: major,
            minor: minor,
            anotherMinor: anotherMinor,
            minorDefinition: definitionMinor
        )
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}

private struct MajorCategoryFixture {
    internal let major: SwiftDataCategory
    internal let minor: SwiftDataCategory
    internal let otherMajor: SwiftDataCategory
    internal let majorDefinition: SwiftDataRecurringPaymentDefinition
    internal let minorDefinition: SwiftDataRecurringPaymentDefinition
    internal let otherDefinition: SwiftDataRecurringPaymentDefinition
}

private struct MinorCategoryFixture {
    internal let major: SwiftDataCategory
    internal let minor: SwiftDataCategory
    internal let anotherMinor: SwiftDataCategory
    internal let minorDefinition: SwiftDataRecurringPaymentDefinition
}

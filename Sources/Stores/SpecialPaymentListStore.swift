import Foundation
import Observation
import SwiftData

// MARK: - SpecialPaymentListStore

/// 特別支払い一覧表示用のストア
@Observable
@MainActor
internal final class SpecialPaymentListStore {
    internal typealias SortOrder = SpecialPaymentListSortOrder

    // MARK: - Dependencies

    private let repository: SpecialPaymentRepository
    private let presenter: SpecialPaymentListPresenter
    private let currentDateProvider: () -> Date

    // MARK: - Filter State

    /// 期間フィルタ開始日
    internal var startDate: Date

    /// 期間フィルタ終了日
    internal var endDate: Date

    /// 検索テキスト（名目での部分一致）
    internal var searchText: String = ""

    /// カテゴリフィルタ（大項目）
    internal var selectedMajorCategoryId: UUID?

    /// カテゴリフィルタ（中項目）
    internal var selectedMinorCategoryId: UUID?

    /// ステータスフィルタ
    internal var selectedStatus: SpecialPaymentStatus?

    /// ソート順
    internal var sortOrder: SortOrder = .dateAscending

    // MARK: - Initialization

    internal init(
        repository: SpecialPaymentRepository,
        presenter: SpecialPaymentListPresenter = SpecialPaymentListPresenter(),
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.presenter = presenter
        self.currentDateProvider = currentDateProvider

        let now = currentDateProvider()
        let start = Calendar.current.startOfMonth(for: now) ?? now
        let end = Calendar.current.date(byAdding: .month, value: 6, to: start) ?? now

        self.startDate = start
        self.endDate = end
    }

    internal convenience init(
        modelContext: ModelContext,
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil,
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        let repository = SpecialPaymentRepositoryFactory.make(
            modelContext: modelContext,
            calendar: calendar,
            businessDayService: businessDayService,
            holidayProvider: holidayProvider,
            currentDateProvider: currentDateProvider
        )
        let presenter = SpecialPaymentListPresenter(calendar: calendar)
        self.init(
            repository: repository,
            presenter: presenter,
            currentDateProvider: currentDateProvider
        )
    }

    // MARK: - Data Access

    // MARK: - Computed Properties

    /// フィルタリング・ソート済みのエントリ一覧
    internal var entries: [SpecialPaymentListEntry] {
        let now = currentDateProvider()
        let occurrences = fetchOccurrences()
        let balances = balanceLookup(for: occurrences)
        let filter = SpecialPaymentListFilter(
            startDate: startDate,
            endDate: endDate,
            searchText: searchText,
            selectedMajorCategoryId: selectedMajorCategoryId,
            selectedMinorCategoryId: selectedMinorCategoryId,
            sortOrder: sortOrder
        )

        return presenter.entries(
            occurrences: occurrences,
            balances: balances,
            filter: filter,
            now: now
        )
    }

    // MARK: - Actions

    /// フィルタをリセット
    internal func resetFilters() {
        searchText = ""
        selectedMajorCategoryId = nil
        selectedMinorCategoryId = nil
        selectedStatus = nil

        let now = currentDateProvider()
        let start = Calendar.current.startOfMonth(for: now) ?? now
        let end = Calendar.current.date(byAdding: .month, value: 6, to: start) ?? now

        startDate = start
        endDate = end
    }

    /// ソート順を切り替え
    internal func toggleSort(by order: SortOrder) {
        sortOrder = order
    }

    // MARK: - Helper Methods

    private func fetchOccurrences() -> [SpecialPaymentOccurrence] {
        let range = SpecialPaymentOccurrenceRange(startDate: startDate, endDate: endDate)
        let statusFilter = selectedStatus.map { Set([$0]) }
        let query = SpecialPaymentOccurrenceQuery(
            range: range,
            statusFilter: statusFilter
        )

        return (try? repository.occurrences(query: query)) ?? []
    }

    private func balanceLookup(for occurrences: [SpecialPaymentOccurrence]) -> [UUID: SpecialPaymentSavingBalance] {
        let definitionIds = Set(occurrences.map { $0.definition.id })
        guard !definitionIds.isEmpty else { return [:] }
        let query = SpecialPaymentBalanceQuery(definitionIds: definitionIds)
        let balances = (try? repository.balances(query: query)) ?? []
        return Dictionary(uniqueKeysWithValues: balances.map { ($0.definition.id, $0) })
    }
}

// MARK: - Calendar Extension

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}

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

    /// 期間フィルタ
    internal var dateRange: DateRange

    /// 検索テキスト（名目での部分一致）
    internal var searchText: String = ""

    /// カテゴリフィルタ
    internal var categoryFilter: CategoryFilterState = .init()

    /// ステータスフィルタ
    internal var selectedStatus: SpecialPaymentStatus?

    /// ソート順
    internal var sortOrder: SortOrder = .dateAscending

    // MARK: - Initialization

    internal init(
        repository: SpecialPaymentRepository,
        presenter: SpecialPaymentListPresenter = SpecialPaymentListPresenter(),
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.repository = repository
        self.presenter = presenter
        self.currentDateProvider = currentDateProvider

        let now = currentDateProvider()
        self.dateRange = DateRange.currentMonthThroughFutureMonths(
            referenceDate: now,
            monthsAhead: 6,
        )
    }

    internal convenience init(
        modelContext: ModelContext,
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        let repository = SpecialPaymentRepositoryFactory.make(
            modelContext: modelContext,
            calendar: calendar,
            businessDayService: businessDayService,
            holidayProvider: holidayProvider,
            currentDateProvider: currentDateProvider,
        )
        let presenter = SpecialPaymentListPresenter(calendar: calendar)
        self.init(
            repository: repository,
            presenter: presenter,
            currentDateProvider: currentDateProvider,
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
            dateRange: dateRange,
            searchText: SearchText(searchText),
            categoryFilter: categoryFilter.selection,
            sortOrder: sortOrder,
        )
        updateCategoryOptionsIfNeeded(from: occurrences)

        return presenter.entries(
            occurrences: occurrences,
            balances: balances,
            filter: filter,
            now: now,
        )
    }

    // MARK: - Actions

    /// フィルタをリセット
    internal func resetFilters() {
        searchText = ""
        categoryFilter.reset()
        selectedStatus = nil

        let now = currentDateProvider()
        dateRange = DateRange.currentMonthThroughFutureMonths(
            referenceDate: now,
            monthsAhead: 6,
        )
    }

    /// ソート順を切り替え
    internal func toggleSort(by order: SortOrder) {
        sortOrder = order
    }

    // MARK: - Helper Methods

    private func fetchOccurrences() -> [SpecialPaymentOccurrence] {
        let range = SpecialPaymentOccurrenceRange(
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
        )
        let statusFilter = selectedStatus.map { Set([$0]) }
        let query = SpecialPaymentOccurrenceQuery(
            range: range,
            statusFilter: statusFilter,
        )

        return (try? repository.occurrences(query: query)) ?? []
    }

    private func balanceLookup(for occurrences: [SpecialPaymentOccurrence]) -> [UUID: SpecialPaymentSavingBalance] {
        let definitionIds = Set(occurrences.map(\.definition.id))
        guard !definitionIds.isEmpty else { return [:] }
        let query = SpecialPaymentBalanceQuery(definitionIds: definitionIds)
        let balances = (try? repository.balances(query: query)) ?? []
        return Dictionary(uniqueKeysWithValues: balances.map { ($0.definition.id, $0) })
    }

    private func updateCategoryOptionsIfNeeded(from occurrences: [SpecialPaymentOccurrence]) {
        guard categoryFilter.availableCategories.isEmpty else { return }

        var categoriesById: [UUID: Category] = [:]
        for occurrence in occurrences {
            guard let category = occurrence.definition.category else {
                continue
            }

            categoriesById[category.id] = category
            if let parent = category.parent {
                categoriesById[parent.id] = parent
            }
        }
        let sorted = Array(categoriesById.values).sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.name < rhs.name
            }
            return lhs.displayOrder < rhs.displayOrder
        }
        categoryFilter.updateCategories(sorted)
    }
}

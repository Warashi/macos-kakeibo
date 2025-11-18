import Foundation
import Observation

// MARK: - RecurringPaymentListStore

/// 定期支払い一覧表示用のストア
@Observable
internal final class RecurringPaymentListStore: @unchecked Sendable {
    internal typealias SortOrder = RecurringPaymentListSortOrder

    private struct EntriesRequestState {
        let dateRange: DateRange
        let searchText: String
        let categorySelection: CategoryFilterState.Selection
        let selectedStatus: RecurringPaymentStatus?
        let sortOrder: SortOrder
    }

    // MARK: - Dependencies

    private let repository: RecurringPaymentRepository
    private let presenter: RecurringPaymentListPresenter
    private let currentDateProvider: () -> Date

    // MARK: - Filter State

    /// 期間フィルタ
    internal var dateRange: DateRange

    /// 検索テキスト（名目での部分一致）
    internal var searchText: String = ""

    /// カテゴリフィルタ
    internal var categoryFilter: CategoryFilterState = .init()

    /// ステータスフィルタ
    internal var selectedStatus: RecurringPaymentStatus?

    /// ソート順
    internal var sortOrder: SortOrder = .dateAscending

    // MARK: - Cached Data

    /// キャッシュされたエントリ一覧（同期的アクセス用）
    internal var cachedEntries: [RecurringPaymentListEntry] = []

    // MARK: - Initialization

    internal init(
        repository: RecurringPaymentRepository,
        presenter: RecurringPaymentListPresenter = RecurringPaymentListPresenter(),
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

    // MARK: - Data Access

    // MARK: - Computed Properties

    /// フィルタリング・ソート済みのエントリ一覧
    internal func entries() async -> [RecurringPaymentListEntry] {
        let requestState = await MainActor.run {
            EntriesRequestState(
                dateRange: dateRange,
                searchText: searchText,
                categorySelection: categoryFilter.selection,
                selectedStatus: selectedStatus,
                sortOrder: sortOrder
            )
        }
        let now = currentDateProvider()
        let occurrences = await fetchOccurrences(
            dateRange: requestState.dateRange,
            selectedStatus: requestState.selectedStatus
        )
        let definitions = await fetchDefinitions()
        let balances = await balanceLookup(for: Array(definitions.keys))
        let categories = await fetchCategoryNames(from: definitions)
        await updateCategoryOptionsIfNeeded(from: definitions, categories: categories)
        let filter = RecurringPaymentListFilter(
            dateRange: requestState.dateRange,
            searchText: SearchText(requestState.searchText),
            categoryFilter: requestState.categorySelection,
            sortOrder: requestState.sortOrder,
        )

        return presenter.entries(
            input: RecurringPaymentListPresenter.EntriesInput(
                occurrences: occurrences,
                definitions: definitions,
                balances: balances,
                categories: categories,
                filter: filter,
                now: now,
            ),
        )
    }

    /// キャッシュを更新
    internal func refreshEntries() async {
        let entries = await self.entries()
        await MainActor.run {
            self.cachedEntries = entries
        }
    }

    // MARK: - Actions

    /// フィルタをリセット
    @MainActor
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
    @MainActor
    internal func toggleSort(by order: SortOrder) {
        sortOrder = order
    }

    // MARK: - Helper Methods

    private func fetchOccurrences(
        dateRange: DateRange,
        selectedStatus: RecurringPaymentStatus?
    ) async -> [RecurringPaymentOccurrence] {
        let range = RecurringPaymentOccurrenceRange(
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
        )
        let statusFilter = selectedStatus.map { Set([$0]) }
        let query = RecurringPaymentOccurrenceQuery(
            range: range,
            statusFilter: statusFilter,
        )

        return (try? await repository.occurrences(query: query)) ?? []
    }

    private func fetchDefinitions() async -> [UUID: RecurringPaymentDefinition] {
        let definitions = (try? await repository.definitions(filter: nil)) ?? []
        return Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    private func balanceLookup(for definitionIds: [UUID]) async -> [UUID: RecurringPaymentSavingBalance] {
        guard !definitionIds.isEmpty else { return [:] }
        let query = RecurringPaymentBalanceQuery(definitionIds: Set(definitionIds))
        let balances = (try? await repository.balances(query: query)) ?? []
        return Dictionary(uniqueKeysWithValues: balances.map { ($0.definitionId, $0) })
    }

    private func fetchCategoryNames(from definitions: [UUID: RecurringPaymentDefinition]) async -> [UUID: String] {
        var categoryNames: [UUID: String] = [:]
        for definition in definitions.values {
            if let categoryId = definition.categoryId {
                categoryNames[categoryId] = definition.name
            }
        }
        return categoryNames
    }

    @MainActor
    private func updateCategoryOptionsIfNeeded(
        from definitions: [UUID: RecurringPaymentDefinition],
        categories: [UUID: String],
    ) async {
        guard categoryFilter.availableCategories.isEmpty else { return }

        var categoriesById: [UUID: (name: String, displayOrder: Int)] = [:]
        for (categoryId, categoryName) in categories {
            categoriesById[categoryId] = (name: categoryName, displayOrder: 0)
        }

        _ = categoriesById.keys.sorted { lhs, rhs in
            guard let lhsInfo = categoriesById[lhs],
                  let rhsInfo = categoriesById[rhs] else {
                return false
            }
            if lhsInfo.displayOrder == rhsInfo.displayOrder {
                return lhsInfo.name < rhsInfo.name
            }
            return lhsInfo.displayOrder < rhsInfo.displayOrder
        }

        categoryFilter.updateCategories([])
    }
}

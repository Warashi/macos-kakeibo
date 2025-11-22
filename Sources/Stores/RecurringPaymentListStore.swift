import Foundation
import Observation

// MARK: - RecurringPaymentListStore

/// 定期支払い一覧表示用のストア
@MainActor
@Observable
internal final class RecurringPaymentListStore {
    internal typealias SortOrder = RecurringPaymentListSortOrder

    private struct EntriesRequestState {
        let dateRange: DateRange
        let searchText: String
        let categorySelection: CategoryFilterState.Selection
        let selectedStatus: RecurringPaymentStatus?
        let sortOrder: SortOrder
    }

    private struct EntriesComputationResult {
        let entries: [RecurringPaymentListEntry]
        let definitions: [UUID: RecurringPaymentDefinition]
        let categories: [UUID: String]
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
        let requestState = EntriesRequestState(
            dateRange: dateRange,
            searchText: searchText,
            categorySelection: categoryFilter.selection,
            selectedStatus: selectedStatus,
            sortOrder: sortOrder,
        )
        let result = await loadEntries(for: requestState)
        updateCategoryOptionsIfNeeded(from: result.definitions, categories: result.categories)
        return result.entries
    }

    /// キャッシュを更新
    internal func refreshEntries() async {
        let entries = await self.entries()
        cachedEntries = entries
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

    private func loadEntries(for state: EntriesRequestState) async -> EntriesComputationResult {
        let repository = self.repository
        let presenter = self.presenter
        let now = currentDateProvider()
        return await Task.detached(priority: .userInitiated) {
            let occurrences = await Self.fetchOccurrences(
                repository: repository,
                dateRange: state.dateRange,
                selectedStatus: state.selectedStatus,
            )
            let definitions = await Self.fetchDefinitions(repository: repository)
            let balances = await Self.balanceLookup(
                repository: repository,
                definitionIds: Array(definitions.keys),
            )
            let categories = await Self.fetchCategoryNames(repository: repository, from: definitions)
            let filter = RecurringPaymentListFilter(
                dateRange: state.dateRange,
                searchText: SearchText(state.searchText),
                categoryFilter: state.categorySelection,
                sortOrder: state.sortOrder,
            )

            let entries = presenter.entries(
                input: RecurringPaymentListPresenter.EntriesInput(
                    occurrences: occurrences,
                    definitions: definitions,
                    balances: balances,
                    categories: categories,
                    filter: filter,
                    now: now,
                ),
            )
            return EntriesComputationResult(entries: entries, definitions: definitions, categories: categories)
        }.value
    }

    private nonisolated static func fetchOccurrences(
        repository: RecurringPaymentRepository,
        dateRange: DateRange,
        selectedStatus: RecurringPaymentStatus?,
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

        return await (try? repository.occurrences(query: query)) ?? []
    }

    private nonisolated static func fetchDefinitions(repository: RecurringPaymentRepository) async
    -> [UUID: RecurringPaymentDefinition] {
        let definitions = await (try? repository.definitions(filter: nil)) ?? []
        return Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    private nonisolated static func balanceLookup(
        repository: RecurringPaymentRepository,
        definitionIds: [UUID],
    ) async -> [UUID: RecurringPaymentSavingBalance] {
        guard !definitionIds.isEmpty else { return [:] }
        let query = RecurringPaymentBalanceQuery(definitionIds: Set(definitionIds))
        let balances = await (try? repository.balances(query: query)) ?? []
        return Dictionary(uniqueKeysWithValues: balances.map { ($0.definitionId, $0) })
    }

    private nonisolated static func fetchCategoryNames(
        repository: RecurringPaymentRepository,
        from definitions: [UUID: RecurringPaymentDefinition],
    ) async -> [UUID: String] {
        let categoryIds = Set(definitions.values.compactMap(\.categoryId))
        guard !categoryIds.isEmpty else { return [:] }
        return await (try? repository.categoryNames(ids: categoryIds)) ?? [:]
    }

    private func updateCategoryOptionsIfNeeded(
        from definitions: [UUID: RecurringPaymentDefinition],
        categories: [UUID: String],
    ) {
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

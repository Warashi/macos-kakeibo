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

    // MARK: - Cached Data

    /// キャッシュされたエントリ一覧（同期的アクセス用）
    internal var cachedEntries: [SpecialPaymentListEntry] = []

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

    // MARK: - Data Access

    // MARK: - Computed Properties

    /// フィルタリング・ソート済みのエントリ一覧
    internal func entries() async -> [SpecialPaymentListEntry] {
        let now = currentDateProvider()
        let occurrences = await fetchOccurrences()
        let definitions = await fetchDefinitions()
        let balances = await balanceLookup(for: Array(definitions.keys))
        let categories = await fetchCategoryNames(from: definitions)
        let filter = SpecialPaymentListFilter(
            dateRange: dateRange,
            searchText: SearchText(searchText),
            categoryFilter: categoryFilter.selection,
            sortOrder: sortOrder,
        )
        await updateCategoryOptionsIfNeeded(from: definitions, categories: categories)

        return presenter.entries(
            input: SpecialPaymentListPresenter.EntriesInput(
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
        cachedEntries = await entries()
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

    private func fetchOccurrences() async -> [SpecialPaymentOccurrenceDTO] {
        let range = SpecialPaymentOccurrenceRange(
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
        )
        let statusFilter = selectedStatus.map { Set([$0]) }
        let query = SpecialPaymentOccurrenceQuery(
            range: range,
            statusFilter: statusFilter,
        )

        return await (try? repository.occurrences(query: query)) ?? []
    }

    private func fetchDefinitions() async -> [UUID: SpecialPaymentDefinitionDTO] {
        let definitions = await (try? repository.definitions(filter: nil)) ?? []
        return Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    private func balanceLookup(for definitionIds: [UUID]) async -> [UUID: SpecialPaymentSavingBalanceDTO] {
        guard !definitionIds.isEmpty else { return [:] }
        let query = SpecialPaymentBalanceQuery(definitionIds: Set(definitionIds))
        let balances = await (try? repository.balances(query: query)) ?? []
        return Dictionary(uniqueKeysWithValues: balances.map { ($0.definitionId, $0) })
    }

    private func fetchCategoryNames(from definitions: [UUID: SpecialPaymentDefinitionDTO]) async -> [UUID: String] {
        var categoryNames: [UUID: String] = [:]
        for definition in definitions.values {
            if let categoryId = definition.categoryId {
                categoryNames[categoryId] = definition.name
            }
        }
        return categoryNames
    }

    private func updateCategoryOptionsIfNeeded(
        from definitions: [UUID: SpecialPaymentDefinitionDTO],
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

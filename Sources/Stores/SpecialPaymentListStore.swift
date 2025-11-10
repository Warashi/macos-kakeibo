import Foundation
import Observation
import SwiftData

// MARK: - SpecialPaymentListStore

/// 特別支払い一覧表示用のストア
@Observable
@MainActor
internal final class SpecialPaymentListStore {
    // MARK: - Dependencies

    private let repository: SpecialPaymentRepository
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
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
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
        self.init(
            repository: repository,
            currentDateProvider: currentDateProvider
        )
    }

    // MARK: - Sort Order

    internal enum SortOrder {
        case dateAscending
        case dateDescending
        case nameAscending
        case nameDescending
        case amountAscending
        case amountDescending
    }

    // MARK: - Data Access

    // MARK: - Computed Properties

    /// フィルタリング・ソート済みのエントリ一覧
    internal var entries: [SpecialPaymentListEntry] {
        let occurrences = fetchOccurrences()
        let balanceMap = balanceLookup(for: occurrences)
        let now = currentDateProvider()

        let filtered = occurrences
            .filter { occurrence in
                // 期間フィルタ
                guard occurrence.scheduledDate >= startDate,
                      occurrence.scheduledDate <= endDate else {
                    return false
                }

                // 検索テキストフィルタ
                if !searchText.isEmpty {
                    let normalizedSearch = searchText.lowercased()
                    let normalizedName = occurrence.definition.name.lowercased()
                    guard normalizedName.contains(normalizedSearch) else {
                        return false
                    }
                }

                // カテゴリフィルタ
                if !matchesCategoryFilter(for: occurrence.definition.category) {
                    return false
                }

                // ステータスフィルタ
                if let status = selectedStatus {
                    guard occurrence.status == status else {
                        return false
                    }
                }

                return true
            }
            .map { occurrence in
                let balance = balanceMap[occurrence.definition.id]
                return SpecialPaymentListEntry.from(
                    occurrence: occurrence,
                    balance: balance,
                    now: now
                )
            }

        return sortEntries(filtered)
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

    private func sortEntries(_ entries: [SpecialPaymentListEntry]) -> [SpecialPaymentListEntry] {
        switch sortOrder {
        case .dateAscending:
            entries.sorted { $0.scheduledDate < $1.scheduledDate }
        case .dateDescending:
            entries.sorted { $0.scheduledDate > $1.scheduledDate }
        case .nameAscending:
            entries.sorted { $0.name < $1.name }
        case .nameDescending:
            entries.sorted { $0.name > $1.name }
        case .amountAscending:
            entries.sorted { $0.expectedAmount < $1.expectedAmount }
        case .amountDescending:
            entries.sorted { $0.expectedAmount > $1.expectedAmount }
        }
    }

    private func matchesCategoryFilter(for category: Category?) -> Bool {
        if let minorId = selectedMinorCategoryId {
            return category?.id == minorId
        }

        if let majorId = selectedMajorCategoryId {
            guard let category else { return false }
            if category.isMajor {
                return category.id == majorId
            }
            return category.parent?.id == majorId
        }

        return true
    }

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

// MARK: - SpecialPaymentListEntry

/// 特別支払い一覧の表示用エントリ
internal struct SpecialPaymentListEntry: Identifiable, Sendable {
    // MARK: - Properties

    /// OccurrenceのID
    internal let id: UUID

    /// DefinitionのID
    internal let definitionId: UUID

    /// 名称
    internal let name: String

    /// カテゴリID
    internal let categoryId: UUID?

    /// カテゴリ名
    internal let categoryName: String?

    /// 予定日
    internal let scheduledDate: Date

    /// 予定額
    internal let expectedAmount: Decimal

    /// 実績額
    internal let actualAmount: Decimal?

    /// ステータス
    internal let status: SpecialPaymentStatus

    /// 積立残高
    internal let savingsBalance: Decimal

    /// 進捗率（0.0〜1.0）
    internal let savingsProgress: Double

    /// 残日数
    internal let daysUntilDue: Int

    /// 紐付けられた取引ID
    internal let transactionId: UUID?

    /// 差異アラート
    internal let hasDiscrepancy: Bool

    // MARK: - Computed Properties

    /// 期限超過フラグ
    internal var isOverdue: Bool {
        daysUntilDue < 0 && status != .completed
    }

    /// 積立完了フラグ
    internal var isFullySaved: Bool {
        savingsProgress >= 1.0
    }

    /// 差異金額（実績額が予定額と異なる場合）
    internal var discrepancyAmount: Decimal? {
        guard let actualAmount else { return nil }
        let diff = actualAmount.safeSubtract(expectedAmount)
        return diff != 0 ? diff : nil
    }

    // MARK: - Initialization

    internal init(
        id: UUID,
        definitionId: UUID,
        name: String,
        categoryId: UUID?,
        categoryName: String?,
        scheduledDate: Date,
        expectedAmount: Decimal,
        actualAmount: Decimal?,
        status: SpecialPaymentStatus,
        savingsBalance: Decimal,
        savingsProgress: Double,
        daysUntilDue: Int,
        transactionId: UUID?,
        hasDiscrepancy: Bool,
    ) {
        self.id = id
        self.definitionId = definitionId
        self.name = name
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.scheduledDate = scheduledDate
        self.expectedAmount = expectedAmount
        self.actualAmount = actualAmount
        self.status = status
        self.savingsBalance = savingsBalance
        self.savingsProgress = savingsProgress
        self.daysUntilDue = daysUntilDue
        self.transactionId = transactionId
        self.hasDiscrepancy = hasDiscrepancy
    }
}

// MARK: - Factory

internal extension SpecialPaymentListEntry {
    /// OccurrenceからEntryを生成
    /// - Parameters:
    ///   - occurrence: SpecialPaymentOccurrence
    ///   - balance: SpecialPaymentSavingBalance（積立残高）
    ///   - now: 基準日（残日数計算用）
    /// - Returns: SpecialPaymentListEntry
    static func from(
        occurrence: SpecialPaymentOccurrence,
        balance: SpecialPaymentSavingBalance?,
        now: Date = Date(),
    ) -> SpecialPaymentListEntry {
        let definition = occurrence.definition

        // 積立残高
        let savingsBalance = balance?.balance ?? 0

        // 進捗率
        let savingsProgress: Double
        if occurrence.expectedAmount > 0 {
            let progress = NSDecimalNumber(decimal: savingsBalance).doubleValue /
                NSDecimalNumber(decimal: occurrence.expectedAmount).doubleValue
            savingsProgress = min(1.0, max(0.0, progress))
        } else {
            savingsProgress = 0.0
        }

        // 残日数
        let daysUntilDue = Calendar.current.dateComponents(
            [.day],
            from: now,
            to: occurrence.scheduledDate,
        ).day ?? 0

        // 差異アラート
        let hasDiscrepancy: Bool = if let actualAmount = occurrence.actualAmount {
            actualAmount != occurrence.expectedAmount
        } else {
            false
        }

        return SpecialPaymentListEntry(
            id: occurrence.id,
            definitionId: definition.id,
            name: definition.name,
            categoryId: definition.category?.id,
            categoryName: definition.category?.fullName,
            scheduledDate: occurrence.scheduledDate,
            expectedAmount: occurrence.expectedAmount,
            actualAmount: occurrence.actualAmount,
            status: occurrence.status,
            savingsBalance: savingsBalance,
            savingsProgress: savingsProgress,
            daysUntilDue: daysUntilDue,
            transactionId: occurrence.transaction?.id,
            hasDiscrepancy: hasDiscrepancy,
        )
    }
}

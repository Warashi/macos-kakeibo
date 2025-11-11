import Foundation

internal enum SpecialPaymentListSortOrder {
    case dateAscending
    case dateDescending
    case nameAscending
    case nameDescending
    case amountAscending
    case amountDescending
}

internal struct SpecialPaymentListFilter {
    internal let dateRange: DateRange
    internal let searchText: SearchText
    internal let categoryFilter: CategoryFilterState.Selection
    internal let sortOrder: SpecialPaymentListSortOrder
}

internal struct SpecialPaymentListPresenter {
    private let calendar: Calendar

    internal init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    internal func entries(
        occurrences: [SpecialPaymentOccurrence],
        balances: [UUID: SpecialPaymentSavingBalance],
        filter: SpecialPaymentListFilter,
        now: Date,
    ) -> [SpecialPaymentListEntry] {
        let entries = occurrences.compactMap { occurrence -> SpecialPaymentListEntry? in
            guard matches(
                occurrence: occurrence,
                filter: filter,
            ) else {
                return nil
            }
            let balance = balances[occurrence.definition.id]
            return entry(
                occurrence: occurrence,
                balance: balance,
                now: now,
            )
        }

        return sortEntries(entries, order: filter.sortOrder)
    }

    private func matches(
        occurrence: SpecialPaymentOccurrence,
        filter: SpecialPaymentListFilter,
    ) -> Bool {
        guard filter.dateRange.contains(occurrence.scheduledDate) else {
            return false
        }

        if !filter.searchText.matches(haystack: occurrence.definition.name) {
            return false
        }

        return filter.categoryFilter.matches(category: occurrence.definition.category)
    }

    private func sortEntries(
        _ entries: [SpecialPaymentListEntry],
        order: SpecialPaymentListSortOrder,
    ) -> [SpecialPaymentListEntry] {
        switch order {
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

    internal func entry(
        occurrence: SpecialPaymentOccurrence,
        balance: SpecialPaymentSavingBalance?,
        now: Date,
    ) -> SpecialPaymentListEntry {
        let definition = occurrence.definition
        let savingsBalance = balance?.balance ?? 0

        let savingsProgress: Double
        if occurrence.expectedAmount > 0 {
            let progress = NSDecimalNumber(decimal: savingsBalance).doubleValue /
                NSDecimalNumber(decimal: occurrence.expectedAmount).doubleValue
            savingsProgress = min(1.0, max(0.0, progress))
        } else {
            savingsProgress = 0.0
        }

        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: now,
            to: occurrence.scheduledDate,
        ).day ?? 0

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

// MARK: - SpecialPaymentListEntry DTO

internal struct SpecialPaymentListEntry: Identifiable, Sendable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let name: String
    internal let categoryId: UUID?
    internal let categoryName: String?
    internal let scheduledDate: Date
    internal let expectedAmount: Decimal
    internal let actualAmount: Decimal?
    internal let status: SpecialPaymentStatus
    internal let savingsBalance: Decimal
    internal let savingsProgress: Double
    internal let daysUntilDue: Int
    internal let transactionId: UUID?
    internal let hasDiscrepancy: Bool

    internal var isOverdue: Bool {
        daysUntilDue < 0 && status != .completed
    }

    internal var isFullySaved: Bool {
        savingsProgress >= 1.0
    }

    internal var discrepancyAmount: Decimal? {
        guard let actualAmount else { return nil }
        let diff = actualAmount.safeSubtract(expectedAmount)
        return diff != 0 ? diff : nil
    }
}

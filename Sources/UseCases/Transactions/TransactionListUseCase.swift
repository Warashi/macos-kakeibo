import Foundation

internal struct TransactionListFilter {
    internal var month: Date
    internal var searchText: String
    internal var filterKind: TransactionFilterKind
    internal var institutionId: UUID?
    internal var majorCategoryId: UUID?
    internal var minorCategoryId: UUID?
    internal var includeOnlyCalculationTarget: Bool
    internal var excludeTransfers: Bool
    internal var sortOption: TransactionSortOption

    internal var asQuery: TransactionQuery {
        TransactionQuery(
            month: month,
            filterKind: filterKind,
            includeOnlyCalculationTarget: includeOnlyCalculationTarget,
            excludeTransfers: excludeTransfers,
            institutionId: institutionId,
            majorCategoryId: majorCategoryId,
            minorCategoryId: minorCategoryId,
            searchText: searchText,
            sortOption: sortOption,
        )
    }
}

internal protocol TransactionListUseCaseProtocol {
    func loadReferenceData() throws -> TransactionReferenceData
    func loadTransactions(filter: TransactionListFilter) throws -> [Transaction]
    @discardableResult
    @MainActor
    func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @MainActor ([Transaction]) -> Void
    ) throws -> ObservationToken
}

internal final class DefaultTransactionListUseCase: TransactionListUseCaseProtocol {
    private let repository: TransactionRepository

    internal init(repository: TransactionRepository) {
        self.repository = repository
    }

    internal func loadReferenceData() throws -> TransactionReferenceData {
        let institutions = try repository.fetchInstitutions()
        let categories = try repository.fetchCategories()
        return TransactionReferenceData(institutions: institutions, categories: categories)
    }

    internal func loadTransactions(filter: TransactionListFilter) throws -> [Transaction] {
        let transactions = try repository.fetchTransactions(query: filter.asQuery)
        return Self.filterTransactions(transactions, filter: filter)
    }

    @discardableResult
    @MainActor
    internal func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @MainActor ([Transaction]) -> Void
    ) throws -> ObservationToken {
        let token = try repository.observeTransactions(query: filter.asQuery) { transactions in
            let filtered = Self.filterTransactions(transactions, filter: filter)
            onChange(filtered)
        }
        return token
    }
}

private extension DefaultTransactionListUseCase {
    static func filterTransactions(
        _ transactions: [Transaction],
        filter: TransactionListFilter
    ) -> [Transaction] {
        let keyword = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.sort(
            transactions: transactions.filter { transaction in
                Self.matchesFilter(transaction: transaction, filter: filter, keyword: keyword)
            },
            option: filter.sortOption
        )
    }

    static func matchesFilter(transaction: Transaction, filter: TransactionListFilter, keyword: String) -> Bool {
        guard Self.matchesCalculationTarget(transaction: transaction, includeOnly: filter.includeOnlyCalculationTarget) else {
            return false
        }

        guard Self.matchesTransfer(transaction: transaction, excludeTransfers: filter.excludeTransfers) else {
            return false
        }

        guard Self.matchesKind(transaction: transaction, filterKind: filter.filterKind) else {
            return false
        }

        guard Self.matchesInstitution(transaction: transaction, institutionId: filter.institutionId) else {
            return false
        }

        guard Self.matchesCategory(
            transaction: transaction,
            majorCategoryId: filter.majorCategoryId,
            minorCategoryId: filter.minorCategoryId
        ) else {
            return false
        }

        guard keyword.isEmpty || Self.matchesSearch(transaction: transaction, keyword: keyword) else {
            return false
        }

        return true
    }

    static func matchesCalculationTarget(transaction: Transaction, includeOnly: Bool) -> Bool {
        !includeOnly || transaction.isIncludedInCalculation
    }

    static func matchesTransfer(transaction: Transaction, excludeTransfers: Bool) -> Bool {
        !excludeTransfers || !transaction.isTransfer
    }

    static func matchesKind(transaction: Transaction, filterKind: TransactionFilterKind) -> Bool {
        switch filterKind {
        case .income:
            transaction.isIncome
        case .expense:
            transaction.isExpense
        case .all:
            true
        }
    }

    static func matchesInstitution(transaction: Transaction, institutionId: UUID?) -> Bool {
        guard let institutionId else { return true }
        return transaction.financialInstitution?.id == institutionId
    }

    static func matchesCategory(
        transaction: Transaction,
        majorCategoryId: UUID?,
        minorCategoryId: UUID?
    ) -> Bool {
        if let minorCategoryId {
            return transaction.minorCategory?.id == minorCategoryId
        }

        guard let majorCategoryId else { return true }
        if transaction.majorCategory?.id == majorCategoryId {
            return true
        }
        return transaction.minorCategory?.parent?.id == majorCategoryId
    }

    static func matchesSearch(transaction: Transaction, keyword: String) -> Bool {
        let lowercased = keyword.lowercased()

        let haystacks = [
            transaction.title.lowercased(),
            transaction.memo.lowercased(),
            transaction.categoryFullName.lowercased(),
            transaction.financialInstitution?.name.lowercased() ?? "",
        ]
        return haystacks.contains { $0.contains(lowercased) }
    }

    static func sort(transactions: [Transaction], option: TransactionSortOption) -> [Transaction] {
        transactions.sorted { lhs, rhs in
            switch option {
            case .dateDescending:
                if lhs.date == rhs.date {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.date > rhs.date
            case .dateAscending:
                if lhs.date == rhs.date {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.date < rhs.date
            case .amountDescending:
                let lhsAmount = lhs.absoluteAmount
                let rhsAmount = rhs.absoluteAmount
                if lhsAmount == rhsAmount {
                    return lhs.date > rhs.date
                }
                return lhsAmount > rhsAmount
            case .amountAscending:
                let lhsAmount = lhs.absoluteAmount
                let rhsAmount = rhs.absoluteAmount
                if lhsAmount == rhsAmount {
                    return lhs.date < rhs.date
                }
                return lhsAmount < rhsAmount
            }
        }
    }
}

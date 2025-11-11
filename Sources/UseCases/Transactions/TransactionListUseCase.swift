import Foundation

internal struct TransactionListFilter {
    internal var month: Date
    internal var searchText: SearchText
    internal var filterKind: TransactionFilterKind
    internal var institutionId: UUID?
    internal var categoryFilter: CategoryFilterState.Selection
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
            majorCategoryId: categoryFilter.majorCategoryId,
            minorCategoryId: categoryFilter.minorCategoryId,
            searchText: searchText.normalizedValue ?? "",
            sortOption: sortOption,
        )
    }
}

@DatabaseActor
internal protocol TransactionListUseCaseProtocol {
    func loadReferenceData() async throws -> TransactionReferenceData
    func loadTransactions(filter: TransactionListFilter) async throws -> [TransactionDTO]
    @discardableResult
    func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) async throws -> ObservationToken
}

@DatabaseActor
internal final class DefaultTransactionListUseCase: TransactionListUseCaseProtocol {
    private let repository: TransactionRepository

    internal init(repository: TransactionRepository) {
        self.repository = repository
    }

    internal func loadReferenceData() async throws -> TransactionReferenceData {
        let institutions = try repository.fetchInstitutions()
        let categories = try repository.fetchCategories()
        return TransactionReferenceData(institutions: institutions, categories: categories)
    }

    internal func loadTransactions(filter: TransactionListFilter) async throws -> [TransactionDTO] {
        let transactions = try repository.fetchTransactions(query: filter.asQuery)
        return Self.filterTransactions(transactions, filter: filter)
    }

    @discardableResult
    internal func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) async throws -> ObservationToken {
        let token = try repository.observeTransactions(query: filter.asQuery) { transactions in
            let filtered = Self.filterTransactions(transactions, filter: filter)
            onChange(filtered)
        }
        do {
            let initial = try loadTransactions(filter: filter)
            await MainActor.run {
                onChange(initial)
            }
        } catch {
            token.cancel()
            throw error
        }
        return token
    }
}

private extension DefaultTransactionListUseCase {
    static func filterTransactions(
        _ transactions: [TransactionDTO],
        filter: TransactionListFilter,
    ) -> [TransactionDTO] {
        let keyword = filter.searchText.comparisonValue
        return Self.sort(
            transactions: transactions.filter { transaction in
                Self.matchesFilter(transaction: transaction, filter: filter, keyword: keyword)
            },
            option: filter.sortOption,
        )
    }

    static func matchesFilter(
        transaction: TransactionDTO,
        filter: TransactionListFilter,
        keyword: String?,
    ) -> Bool {
        guard Self.matchesCalculationTarget(
            transaction: transaction,
            includeOnly: filter.includeOnlyCalculationTarget,
        ) else {
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

        guard filter.categoryFilter.matchesIds(
            majorCategoryId: transaction.majorCategoryId,
            minorCategoryId: transaction.minorCategoryId,
        ) else {
            return false
        }

        if let keyword,
           !Self.matchesSearch(transaction: transaction, keyword: keyword) {
            return false
        }

        return true
    }

    static func matchesCalculationTarget(transaction: TransactionDTO, includeOnly: Bool) -> Bool {
        !includeOnly || transaction.isIncludedInCalculation
    }

    static func matchesTransfer(transaction: TransactionDTO, excludeTransfers: Bool) -> Bool {
        !excludeTransfers || !transaction.isTransfer
    }

    static func matchesKind(transaction: TransactionDTO, filterKind: TransactionFilterKind) -> Bool {
        switch filterKind {
        case .income:
            transaction.isIncome
        case .expense:
            transaction.isExpense
        case .all:
            true
        }
    }

    static func matchesInstitution(transaction: TransactionDTO, institutionId: UUID?) -> Bool {
        guard let institutionId else { return true }
        return transaction.financialInstitutionId == institutionId
    }

    static func matchesSearch(transaction: TransactionDTO, keyword: String) -> Bool {
        let haystacks = [
            transaction.title,
            transaction.memo,
        ]
        let loweredKeyword = keyword.lowercased()
        return haystacks.contains { $0.lowercased().contains(loweredKeyword) }
    }

    static func sort(transactions: [TransactionDTO], option: TransactionSortOption) -> [TransactionDTO] {
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

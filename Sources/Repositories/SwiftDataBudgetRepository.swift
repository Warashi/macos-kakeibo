import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    private let recurringPaymentRepository: RecurringPaymentRepository

    internal init(
        modelContext: ModelContext,
        recurringPaymentRepository: RecurringPaymentRepository? = nil,
    ) {
        self.modelContext = modelContext
        self.recurringPaymentRepository = recurringPaymentRepository
            ?? RecurringPaymentRepositoryFactory.make(modelContext: modelContext)
    }

    internal func fetchSnapshot(for year: Int) throws -> BudgetSnapshot {
        let budgets = try modelContext.fetch(BudgetQueries.allBudgets())

        // 年の範囲の取引のみ取得（パフォーマンス最適化）
        let transactions: [Transaction] = if let startDate = Date.from(year: year, month: 1),
                                             let endDate = Date.from(year: year + 1, month: 1) {
            try modelContext.fetch(TransactionQueries.between(
                startDate: startDate,
                endDate: endDate,
            ))
        } else {
            []
        }

        let categories = try modelContext.fetch(CategoryQueries.sortedForDisplay())
        let definitions = try recurringPaymentRepository.definitions(filter: nil)
        let balances = try recurringPaymentRepository.balances(query: nil)
        let occurrences = try recurringPaymentRepository.occurrences(query: nil)
        let config = try modelContext.fetch(BudgetQueries.annualConfig(for: year)).first

        // SwiftDataモデルをDTOに変換
        let budgetDTOs = budgets.map { BudgetDTO(from: $0) }
        let transactionDTOs = transactions.map { TransactionDTO(from: $0) }
        let categoryDTOs = categories.map { CategoryDTO(from: $0) }
        let configDTO = config.map { AnnualBudgetConfigDTO(from: $0) }

        return BudgetSnapshot(
            budgets: budgetDTOs,
            transactions: transactionDTOs,
            categories: categoryDTOs,
            annualBudgetConfig: configDTO,
            recurringPaymentDefinitions: definitions,
            recurringPaymentBalances: balances,
            recurringPaymentOccurrences: occurrences,
        )
    }

    internal func category(id: UUID) throws -> Category? {
        try modelContext.fetch(CategoryQueries.byId(id)).first
    }

    internal func annualBudgetConfig(for year: Int) throws -> AnnualBudgetConfig? {
        try modelContext.fetch(BudgetQueries.annualConfig(for: year)).first
    }

    internal func insertBudget(_ budget: Budget) {
        modelContext.insert(budget)
    }

    internal func deleteBudget(_ budget: Budget) {
        modelContext.delete(budget)
    }

    internal func updateBudget(input: BudgetUpdateInput) throws {
        guard let budget = try modelContext.fetch(BudgetQueries.byId(input.id)).first else {
            throw RepositoryError.notFound
        }
        budget.amount = input.input.amount
        if let categoryId = input.input.categoryId {
            budget.category = try category(id: categoryId)
        } else {
            budget.category = nil
        }
        budget.startYear = input.input.startYear
        budget.startMonth = input.input.startMonth
        budget.endYear = input.input.endYear
        budget.endMonth = input.input.endMonth
        budget.updatedAt = Date()
    }

    internal func deleteBudget(id: UUID) throws {
        guard let budget = try modelContext.fetch(BudgetQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(budget)
    }

    internal func insertAnnualBudgetConfig(_ config: AnnualBudgetConfig) {
        modelContext.insert(config)
    }

    internal func deleteAllocation(_ allocation: AnnualBudgetAllocation) {
        modelContext.delete(allocation)
    }

    internal func saveChanges() throws {
        try modelContext.save()
    }
}

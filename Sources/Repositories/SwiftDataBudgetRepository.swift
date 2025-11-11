import Foundation
import SwiftData

internal final class SwiftDataBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    private let specialPaymentRepository: SpecialPaymentRepository

    internal init(
        modelContext: ModelContext,
        specialPaymentRepository: SpecialPaymentRepository? = nil,
    ) {
        self.modelContext = modelContext
        self.specialPaymentRepository = specialPaymentRepository
            ?? SpecialPaymentRepositoryFactory.make(modelContext: modelContext)
    }

    internal func fetchSnapshot(for year: Int) throws -> BudgetSnapshot {
        let budgets = try modelContext.fetch(BudgetQueries.allBudgets())
        let transactions = try modelContext.fetch(TransactionQueries.all())
        let categories = try modelContext.fetch(CategoryQueries.sortedForDisplay())
        let definitions = try specialPaymentRepository.definitions(filter: nil)
        let balances = try specialPaymentRepository.balances(query: nil)
        let config = try modelContext.fetch(BudgetQueries.annualConfig(for: year)).first
        return BudgetSnapshot(
            budgets: budgets,
            transactions: transactions,
            categories: categories,
            annualBudgetConfig: config,
            specialPaymentDefinitions: definitions,
            specialPaymentBalances: balances,
        )
    }

    internal func category(id: UUID) throws -> Category? {
        try modelContext.fetch(CategoryQueries.byId(id)).first
    }

    internal func insertBudget(_ budget: Budget) {
        modelContext.insert(budget)
    }

    internal func deleteBudget(_ budget: Budget) {
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

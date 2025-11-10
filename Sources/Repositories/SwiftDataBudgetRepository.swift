import Foundation
import SwiftData

internal final class SwiftDataBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    private let specialPaymentRepository: SpecialPaymentRepository

    internal init(
        modelContext: ModelContext,
        specialPaymentRepository: SpecialPaymentRepository? = nil
    ) {
        self.modelContext = modelContext
        self.specialPaymentRepository = specialPaymentRepository
            ?? SpecialPaymentRepositoryFactory.make(modelContext: modelContext)
    }

    internal func fetchSnapshot(for year: Int) throws -> BudgetSnapshot {
        let budgets = try modelContext.fetch(FetchDescriptor<Budget>())
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        let categories = try modelContext.fetch(
            FetchDescriptor<Category>(
                sortBy: [
                    SortDescriptor(\.displayOrder),
                    SortDescriptor(\.name, order: .forward),
                ]
            )
        )
        let definitions = try specialPaymentRepository.definitions(filter: nil)
        let balances = try specialPaymentRepository.balances(query: nil)
        var configDescriptor = FetchDescriptor<AnnualBudgetConfig>(
            predicate: #Predicate { $0.year == year }
        )
        configDescriptor.fetchLimit = 1
        let config = try modelContext.fetch(configDescriptor).first
        return BudgetSnapshot(
            budgets: budgets,
            transactions: transactions,
            categories: categories,
            annualBudgetConfig: config,
            specialPaymentDefinitions: definitions,
            specialPaymentBalances: balances
        )
    }

    internal func category(id: UUID) throws -> Category? {
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
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

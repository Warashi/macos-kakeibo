import Foundation
import SwiftData

@DatabaseActor
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
        let definitions = try specialPaymentRepository.definitions(filter: nil)
        let balances = try specialPaymentRepository.balances(query: nil)
        let occurrences = try specialPaymentRepository.occurrences(query: nil)
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
            specialPaymentDefinitions: definitions,
            specialPaymentBalances: balances,
            specialPaymentOccurrences: occurrences,
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

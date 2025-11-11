import Foundation

@DatabaseActor
internal protocol BudgetRepository {
    func fetchSnapshot(for year: Int) throws -> BudgetSnapshot
    func category(id: UUID) throws -> Category?
    func insertBudget(_ budget: Budget)
    func deleteBudget(_ budget: Budget)
    func insertAnnualBudgetConfig(_ config: AnnualBudgetConfig)
    func deleteAllocation(_ allocation: AnnualBudgetAllocation)
    func saveChanges() throws
}

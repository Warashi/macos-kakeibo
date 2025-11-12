import Foundation

@DatabaseActor
internal protocol BudgetRepository: Sendable {
    func fetchSnapshot(for year: Int) throws -> BudgetSnapshot
    func category(id: UUID) throws -> Category?
    func insertBudget(_ budget: Budget)
    func deleteBudget(_ budget: Budget)
    func updateBudget(
        id: UUID,
        amount: Decimal,
        category: Category?,
        startYear: Int,
        startMonth: Int,
        endYear: Int,
        endMonth: Int,
    ) throws
    func deleteBudget(id: UUID) throws
    func insertAnnualBudgetConfig(_ config: AnnualBudgetConfig)
    func deleteAllocation(_ allocation: AnnualBudgetAllocation)
    func saveChanges() throws
}

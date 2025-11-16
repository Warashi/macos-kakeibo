import Foundation

@DatabaseActor
internal protocol BudgetRepository: Sendable {
    func fetchSnapshot(for year: Int) throws -> BudgetSnapshot
    func category(id: UUID) throws -> CategoryDTO?
    func findCategoryByName(_ name: String, parentId: UUID?) throws -> CategoryDTO?
    func createCategory(name: String, parentId: UUID?) throws -> UUID
    func findInstitutionByName(_ name: String) throws -> FinancialInstitutionDTO?
    func createInstitution(name: String) throws -> UUID
    func annualBudgetConfig(for year: Int) throws -> AnnualBudgetConfigDTO?
    func addBudget(_ input: BudgetInput) throws
    func updateBudget(input: BudgetUpdateInput) throws
    func deleteBudget(id: UUID) throws
    func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws
    func saveChanges() throws
}

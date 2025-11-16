import Foundation

@DatabaseActor
internal protocol BudgetRepository: Sendable {
    func fetchSnapshot(for year: Int) throws -> BudgetSnapshot
    func category(id: UUID) throws -> CategoryDTO?
    func findCategoryByName(_ name: String, parentId: UUID?) throws -> CategoryDTO?
    func createCategory(name: String, parentId: UUID?) throws -> UUID
    func countCategories() throws -> Int
    func findInstitutionByName(_ name: String) throws -> FinancialInstitutionDTO?
    func createInstitution(name: String) throws -> UUID
    func countFinancialInstitutions() throws -> Int
    func annualBudgetConfig(for year: Int) throws -> AnnualBudgetConfigDTO?
    func countAnnualBudgetConfigs() throws -> Int
    func addBudget(_ input: BudgetInput) throws
    func updateBudget(input: BudgetUpdateInput) throws
    func deleteBudget(id: UUID) throws
    func countBudgets() throws -> Int
    func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws
    func saveChanges() throws
}

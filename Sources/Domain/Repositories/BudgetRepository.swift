import Foundation

internal protocol BudgetRepository: Sendable {
    func fetchSnapshot(for year: Int) async throws -> BudgetSnapshot
    func category(id: UUID) async throws -> Category?
    func findCategoryByName(_ name: String, parentId: UUID?) async throws -> Category?
    func createCategory(name: String, parentId: UUID?) async throws -> UUID
    func countCategories() async throws -> Int
    func findInstitutionByName(_ name: String) async throws -> FinancialInstitution?
    func createInstitution(name: String) async throws -> UUID
    func countFinancialInstitutions() async throws -> Int
    func annualBudgetConfig(for year: Int) async throws -> AnnualBudgetConfig?
    func countAnnualBudgetConfigs() async throws -> Int
    func addBudget(_ input: BudgetInput) async throws
    func updateBudget(input: BudgetUpdateInput) async throws
    func deleteBudget(id: UUID) async throws
    func deleteAllBudgets() async throws
    func deleteAllAnnualBudgetConfigs() async throws
    func deleteAllCategories() async throws
    func deleteAllFinancialInstitutions() async throws
    func countBudgets() async throws -> Int
    func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws
    func saveChanges() async throws
}

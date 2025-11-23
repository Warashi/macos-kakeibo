import Foundation
@testable import Kakeibo

internal final class InMemoryBudgetRepository: BudgetRepository {
    internal var categories: [UUID: Kakeibo.Category]
    internal var institutions: [UUID: FinancialInstitution]
    internal private(set) var saveCallCount: Int = 0

    internal init(
        categories: [Kakeibo.Category] = [],
        institutions: [FinancialInstitution] = [],
    ) {
        self.categories = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.institutions = Dictionary(uniqueKeysWithValues: institutions.map { ($0.id, $0) })
    }

    internal func fetchSnapshot(for year: Int) async throws -> BudgetSnapshot {
        BudgetSnapshot(
            budgets: [],
            transactions: [],
            categories: Array(categories.values),
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
    }

    internal func category(id: UUID) async throws -> Kakeibo.Category? {
        categories[id]
    }

    internal func fetchAllCategories() async throws -> [Kakeibo.Category] {
        Array(categories.values).sorted { $0.displayOrder < $1.displayOrder }
    }

    internal func findCategoryByName(_ name: String, parentId: UUID?) async throws -> Kakeibo.Category? {
        categories.values.first { $0.name == name && $0.parentId == parentId }
    }

    internal func createCategory(name: String, parentId: UUID?) async throws -> UUID {
        let id = UUID()
        let now = Date()
        let dto = Kakeibo.Category(
            id: id,
            name: name,
            displayOrder: categories.count,
            allowsAnnualBudget: false,
            parentId: parentId,
            createdAt: now,
            updatedAt: now,
        )
        categories[id] = dto
        return id
    }

    internal func countCategories() async throws -> Int {
        categories.count
    }

    internal func findInstitutionByName(_ name: String) async throws -> FinancialInstitution? {
        institutions.values.first { $0.name == name }
    }

    internal func createInstitution(name: String) async throws -> UUID {
        let id = UUID()
        let now = Date()
        let dto = FinancialInstitution(
            id: id,
            name: name,
            displayOrder: institutions.count,
            createdAt: now,
            updatedAt: now,
        )
        institutions[id] = dto
        return id
    }

    internal func countFinancialInstitutions() async throws -> Int {
        institutions.count
    }

    internal func annualBudgetConfig(for year: Int) async throws -> AnnualBudgetConfig? {
        nil
    }

    internal func countAnnualBudgetConfigs() async throws -> Int {
        0
    }

    internal func addBudget(_ input: BudgetInput) async throws {
        unsupported(#function)
    }

    internal func updateBudget(input: BudgetUpdateInput) async throws {
        unsupported(#function)
    }

    internal func deleteBudget(id: UUID) async throws {
        unsupported(#function)
    }

    internal func deleteAllBudgets() async throws {}

    internal func deleteAllAnnualBudgetConfigs() async throws {}

    internal func deleteAllCategories() async throws {
        categories.removeAll()
    }

    internal func deleteAllFinancialInstitutions() async throws {
        institutions.removeAll()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws {
        unsupported(#function)
    }

    internal func countBudgets() async throws -> Int {
        0
    }

    internal func saveChanges() async throws {
        saveCallCount += 1
    }
}

private extension InMemoryBudgetRepository {
    func unsupported(_ function: StaticString) -> Never {
        preconditionFailure("\(function) is not supported in InMemoryBudgetRepository")
    }
}

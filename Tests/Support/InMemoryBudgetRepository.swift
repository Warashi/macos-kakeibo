import Foundation
@testable import Kakeibo

internal final class InMemoryBudgetRepository: BudgetRepository {
    internal var categories: [UUID: Kakeibo.Category]
    internal var institutions: [UUID: FinancialInstitution]
    internal private(set) var saveCallCount: Int = 0

    internal init(
        categories: [Kakeibo.Category] = [],
        institutions: [FinancialInstitution] = []
    ) {
        self.categories = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.institutions = Dictionary(uniqueKeysWithValues: institutions.map { ($0.id, $0) })
    }

    internal func fetchSnapshot(for year: Int) throws -> BudgetSnapshot {
        BudgetSnapshot(
            budgets: [],
            transactions: [],
            categories: Array(categories.values),
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: []
        )
    }

    internal func category(id: UUID) throws -> Kakeibo.Category? {
        categories[id]
    }

    internal func findCategoryByName(_ name: String, parentId: UUID?) throws -> Kakeibo.Category? {
        categories.values.first { $0.name == name && $0.parentId == parentId }
    }

    internal func createCategory(name: String, parentId: UUID?) throws -> UUID {
        let id = UUID()
        let now = Date()
        let dto = Kakeibo.Category(
            id: id,
            name: name,
            displayOrder: categories.count,
            allowsAnnualBudget: false,
            parentId: parentId,
            createdAt: now,
            updatedAt: now
        )
        categories[id] = dto
        return id
    }

    internal func countCategories() throws -> Int {
        categories.count
    }

    internal func findInstitutionByName(_ name: String) throws -> FinancialInstitution? {
        institutions.values.first { $0.name == name }
    }

    internal func createInstitution(name: String) throws -> UUID {
        let id = UUID()
        let now = Date()
        let dto = FinancialInstitution(
            id: id,
            name: name,
            displayOrder: institutions.count,
            createdAt: now,
            updatedAt: now
        )
        institutions[id] = dto
        return id
    }

    internal func countFinancialInstitutions() throws -> Int {
        institutions.count
    }

    internal func annualBudgetConfig(for year: Int) throws -> AnnualBudgetConfigDTO? {
        nil
    }

    internal func countAnnualBudgetConfigs() throws -> Int {
        0
    }

    internal func addBudget(_ input: BudgetInput) throws {
        unsupported(#function)
    }

    internal func updateBudget(input: BudgetUpdateInput) throws {
        unsupported(#function)
    }

    internal func deleteBudget(id: UUID) throws {
        unsupported(#function)
    }

    internal func deleteAllBudgets() throws {}

    internal func deleteAllAnnualBudgetConfigs() throws {}

    internal func deleteAllCategories() throws {
        categories.removeAll()
    }

    internal func deleteAllFinancialInstitutions() throws {
        institutions.removeAll()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws {
        unsupported(#function)
    }

    internal func countBudgets() throws -> Int {
        0
    }

    internal func saveChanges() throws {
        saveCallCount += 1
    }
}

private extension InMemoryBudgetRepository {
    func unsupported(_ function: StaticString) -> Never {
        preconditionFailure("\(function) is not supported in InMemoryBudgetRepository")
    }
}

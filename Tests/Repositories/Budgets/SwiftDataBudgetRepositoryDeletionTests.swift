import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataBudgetRepositoryDeletion", .serialized)
internal struct SwiftDataBudgetRepositoryDeletionTests {
    @Test("全削除APIで関連データを消せる")
    internal func deletesAllRecords() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = SwiftDataBudgetRepository(modelContainer: container)

        let budgetInput = BudgetInput(
            amount: Decimal(20000),
            categoryId: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 1,
        )
        try await repository.addBudget(budgetInput)
        try await repository.saveChanges()
        #expect(try await repository.countBudgets() == 1)

        try await repository.deleteAllBudgets()
        #expect(try await repository.countBudgets() == 0)

        let configInput = AnnualBudgetConfigInput(
            year: 2025,
            totalAmount: Decimal(100_000),
            policy: .automatic,
            allocations: [],
        )
        try await repository.upsertAnnualBudgetConfig(configInput)
        try await repository.saveChanges()
        #expect(try await repository.countAnnualBudgetConfigs() == 1)

        try await repository.deleteAllAnnualBudgetConfigs()
        #expect(try await repository.countAnnualBudgetConfigs() == 0)

        let majorId = try await repository.createCategory(name: "食費", parentId: nil)
        _ = try await repository.createCategory(name: "外食", parentId: majorId)
        try await repository.saveChanges()
        #expect(try await repository.countCategories() == 2)

        try await repository.deleteAllCategories()
        #expect(try await repository.countCategories() == 0)

        _ = try await repository.createInstitution(name: "メイン口座")
        try await repository.saveChanges()
        #expect(try await repository.countFinancialInstitutions() == 1)

        try await repository.deleteAllFinancialInstitutions()
        #expect(try await repository.countFinancialInstitutions() == 0)
    }
}

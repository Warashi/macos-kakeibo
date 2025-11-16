import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataBudgetRepositoryDeletion", .serialized)
@DatabaseActor
internal struct SwiftDataBudgetRepositoryDeletionTests {
    @Test("全削除APIで関連データを消せる")
    internal func deletesAllRecords() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataBudgetRepository(modelContext: context, modelContainer: container)

        let budgetInput = BudgetInput(
            amount: Decimal(20_000),
            categoryId: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 1
        )
        try repository.addBudget(budgetInput)
        try repository.saveChanges()
        #expect(try repository.countBudgets() == 1)

        try repository.deleteAllBudgets()
        #expect(try repository.countBudgets() == 0)

        let configInput = AnnualBudgetConfigInput(
            year: 2025,
            totalAmount: Decimal(100_000),
            policy: .automatic,
            allocations: []
        )
        try repository.upsertAnnualBudgetConfig(configInput)
        try repository.saveChanges()
        #expect(try repository.countAnnualBudgetConfigs() == 1)

        try repository.deleteAllAnnualBudgetConfigs()
        #expect(try repository.countAnnualBudgetConfigs() == 0)

        let majorId = try repository.createCategory(name: "食費", parentId: nil)
        _ = try repository.createCategory(name: "外食", parentId: majorId)
        try repository.saveChanges()
        #expect(try repository.countCategories() == 2)

        try repository.deleteAllCategories()
        #expect(try repository.countCategories() == 0)

        _ = try repository.createInstitution(name: "メイン口座")
        try repository.saveChanges()
        #expect(try repository.countFinancialInstitutions() == 1)

        try repository.deleteAllFinancialInstitutions()
        #expect(try repository.countFinancialInstitutions() == 0)
    }
}

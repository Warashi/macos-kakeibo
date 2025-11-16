import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataBudgetRepositoryStatistics", .serialized)
@DatabaseActor
internal struct SwiftDataBudgetRepositoryStatisticsTests {
    @Test("各エンティティの件数をカウントできる")
    internal func countsRecords() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataBudgetRepository(modelContext: context, modelContainer: container)

        #expect(try repository.countCategories() == 0)
        #expect(try repository.countFinancialInstitutions() == 0)
        #expect(try repository.countAnnualBudgetConfigs() == 0)
        #expect(try repository.countBudgets() == 0)

        let majorId = try repository.createCategory(name: "食費", parentId: nil)
        _ = try repository.createCategory(name: "外食", parentId: majorId)
        try repository.saveChanges()

        #expect(try repository.countCategories() == 2)

        _ = try repository.createInstitution(name: "メイン口座")
        try repository.saveChanges()

        #expect(try repository.countFinancialInstitutions() == 1)

        let budgetInput = BudgetInput(
            amount: Decimal(30_000),
            categoryId: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 1
        )
        try repository.addBudget(budgetInput)
        try repository.saveChanges()

        #expect(try repository.countBudgets() == 1)

        let configInput = AnnualBudgetConfigInput(
            year: 2025,
            totalAmount: Decimal(100_000),
            policy: .automatic,
            allocations: []
        )
        try repository.upsertAnnualBudgetConfig(configInput)
        try repository.saveChanges()

        #expect(try repository.countAnnualBudgetConfigs() == 1)
    }
}

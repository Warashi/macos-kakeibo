import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataBudgetRepositoryStatistics", .serialized)
internal struct SwiftDataBudgetRepositoryStatisticsTests {
    @Test("各エンティティの件数をカウントできる")
    internal func countsRecords() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        await repository.useSharedContext(context)

        #expect(try await repository.countCategories() == 0)
        #expect(try await repository.countFinancialInstitutions() == 0)
        #expect(try await repository.countAnnualBudgetConfigs() == 0)
        #expect(try await repository.countBudgets() == 0)

        let majorId = try await repository.createCategory(name: "食費", parentId: nil)
        _ = try await repository.createCategory(name: "外食", parentId: majorId)
        try await repository.saveChanges()

        #expect(try await repository.countCategories() == 2)

        _ = try await repository.createInstitution(name: "メイン口座")
        try await repository.saveChanges()

        #expect(try await repository.countFinancialInstitutions() == 1)

        let budgetInput = BudgetInput(
            amount: Decimal(30000),
            categoryId: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 1,
        )
        try await repository.addBudget(budgetInput)
        try await repository.saveChanges()

        #expect(try await repository.countBudgets() == 1)

        let configInput = AnnualBudgetConfigInput(
            year: 2025,
            totalAmount: Decimal(100_000),
            policy: .automatic,
            allocations: [],
        )
        try await repository.upsertAnnualBudgetConfig(configInput)
        try await repository.saveChanges()

        #expect(try await repository.countAnnualBudgetConfigs() == 1)
    }
}

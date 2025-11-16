import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsAnnualConfig {
    @Test("年次特別枠：登録と更新")
    internal func upsertAnnualBudgetConfig_createsAndUpdates() async throws {
        let (store, context) = try await makeStore()
        let food = CategoryEntity(name: "食費")
        let travel = CategoryEntity(name: "旅行")
        context.insert(food)
        context.insert(travel)
        try context.save()

        #expect(store.annualBudgetConfig == nil)

        try await store.upsertAnnualBudgetConfig(
            totalAmount: 300_000,
            policy: .manual,
            allocations: [
                AnnualAllocationDraft(categoryId: food.id, amount: 200_000, policyOverride: .automatic),
                AnnualAllocationDraft(categoryId: travel.id, amount: 100_000),
            ],
        )

        let createdConfig = try #require(store.annualBudgetConfig)
        #expect(createdConfig.totalAmount == 300_000)
        #expect(createdConfig.policy == .manual)
        #expect(createdConfig.allocations.count == 2)

        let allocationMap = Dictionary(uniqueKeysWithValues: createdConfig.allocations
            .map { ($0.categoryId, $0) })
        #expect(allocationMap[food.id]?.amount == 200_000)
        #expect(allocationMap[travel.id]?.amount == 100_000)
        #expect(allocationMap[food.id]?.policyOverride == .automatic)
        #expect(allocationMap[travel.id]?.policyOverride == nil)
        #expect(food.allowsAnnualBudget)
        #expect(travel.allowsAnnualBudget)

        try await store.upsertAnnualBudgetConfig(
            totalAmount: 500_000,
            policy: .disabled,
            allocations: [
                AnnualAllocationDraft(categoryId: travel.id, amount: 300_000, policyOverride: .manual),
            ],
        )

        let updatedConfig = try #require(store.annualBudgetConfig)
        #expect(updatedConfig.totalAmount == 500_000)
        #expect(updatedConfig.policy == .disabled)
        #expect(updatedConfig.allocations.count == 1)
        let updatedAllocation = updatedConfig.allocations.first { $0.categoryId == travel.id }
        #expect(updatedAllocation?.amount == 300_000)
        #expect(updatedAllocation?.policyOverride == .manual)
    }

    @Test("年次特別枠：カテゴリ重複はエラー")
    internal func upsertAnnualBudgetConfig_duplicateCategories() async throws {
        let (store, context) = try await makeStore()
        let food = CategoryEntity(name: "食費")
        context.insert(food)
        try context.save()

        await #expect(
            throws: BudgetStoreError.duplicateAnnualAllocationCategory,
        ) {
            try await store.upsertAnnualBudgetConfig(
                totalAmount: 100_000,
                policy: .automatic,
                allocations: [
                    AnnualAllocationDraft(categoryId: food.id, amount: 60000),
                    AnnualAllocationDraft(categoryId: food.id, amount: 40000),
                ],
            )
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeStore() async throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = try await makeBudgetStore(container: container, context: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    @DatabaseActor
    private func makeBudgetStore(container: ModelContainer, context: ModelContext) async throws -> BudgetStore {
        let repository = SwiftDataBudgetRepository(modelContext: context, modelContainer: container)
        let calculator = BudgetCalculator()
        let monthlyUseCase = DefaultMonthlyBudgetUseCase(calculator: calculator)
        let annualUseCase = DefaultAnnualBudgetUseCase()
        let recurringPaymentUseCase = DefaultRecurringPaymentSavingsUseCase(calculator: calculator)
        let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)

        return await BudgetStore(
            repository: repository,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            recurringPaymentUseCase: recurringPaymentUseCase,
            mutationUseCase: mutationUseCase,
        )
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}

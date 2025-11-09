import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsAnnualConfig {
    @Test("年次特別枠：登録と更新")
    internal func upsertAnnualBudgetConfig_createsAndUpdates() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費")
        let travel = Category(name: "旅行")
        context.insert(food)
        context.insert(travel)
        try context.save()

        #expect(store.annualBudgetConfig == nil)

        try store.upsertAnnualBudgetConfig(
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
            .map { ($0.category.id, $0) })
        #expect(allocationMap[food.id]?.amount == 200_000)
        #expect(allocationMap[travel.id]?.amount == 100_000)
        #expect(allocationMap[food.id]?.policyOverride == .automatic)
        #expect(allocationMap[travel.id]?.policyOverride == nil)

        try store.upsertAnnualBudgetConfig(
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
        let updatedAllocation = updatedConfig.allocations.first { $0.category.id == travel.id }
        #expect(updatedAllocation?.amount == 300_000)
        #expect(updatedAllocation?.policyOverride == .manual)
    }

    @Test("年次特別枠：カテゴリ重複はエラー")
    internal func upsertAnnualBudgetConfig_duplicateCategories() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費")
        context.insert(food)
        try context.save()

        #expect(
            throws: BudgetStoreError.duplicateAnnualAllocationCategory,
        ) {
            try store.upsertAnnualBudgetConfig(
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

    private func makeStore() throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = BudgetStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}

import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
@MainActor
internal struct BudgetMutationUseCaseTests {
    @Test("月次予算を追加できる")
    internal func addsBudget() async throws {
        let (container, context) = try makeContainerAndContext()
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        await repository.useSharedContext(context)
        let useCase = DefaultBudgetMutationUseCase(repository: repository)

        let input = BudgetInput(
            amount: 5000,
            categoryId: nil,
            startYear: 2025,
            startMonth: 11,
            endYear: 2025,
            endMonth: 11,
        )
        try await useCase.addBudget(input: input)

        let snapshot = try await repository.fetchSnapshot(for: 2025)
        #expect(snapshot.budgets.count == 1)
        #expect(snapshot.budgets.first?.amount == 5000)
    }

    @Test("予算更新で期間とカテゴリを変更できる")
    internal func updatesBudget() async throws {
        let (container, context) = try makeContainerAndContext()
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        await repository.useSharedContext(context)
        let useCase = DefaultBudgetMutationUseCase(repository: repository)
        let category = SwiftDataCategory(name: "食費", displayOrder: 1)
        context.insert(category)
        let budget = SwiftDataBudget(amount: 4000, year: 2025, month: 11)
        context.insert(budget)
        try context.save()

        let input = BudgetInput(
            amount: 6000,
            categoryId: category.id,
            startYear: 2025,
            startMonth: 11,
            endYear: 2025,
            endMonth: 12,
        )
        let budgetModel = Budget(from: budget)
        try await useCase.updateBudget(budgetModel, input: input)

        #expect(budget.amount == 6000)
        #expect(budget.category?.id == category.id)
        #expect(budget.endMonth == 12)
    }

    @Test("年次特別枠を新規登録できる")
    internal func upsertsAnnualBudgetConfig() async throws {
        let (container, context) = try makeContainerAndContext()
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        await repository.useSharedContext(context)
        let useCase = DefaultBudgetMutationUseCase(repository: repository)
        let category = SwiftDataCategory(name: "教育費", allowsAnnualBudget: true, displayOrder: 1)
        context.insert(category)
        try context.save()

        let input = AnnualBudgetConfigInput(
            year: 2025,
            totalAmount: 200_000,
            policy: .automatic,
            allocations: [
                AnnualAllocationDraft(categoryId: category.id, amount: 200_000),
            ],
        )
        try await useCase.upsertAnnualBudgetConfig(input)

        let snapshot = try await repository.fetchSnapshot(for: 2025)
        let config = try #require(snapshot.annualBudgetConfig)
        #expect(config.totalAmount == 200_000)
        #expect(config.allocations.count == 1)
    }

    @Test("不正な期間はエラーになる")
    internal func invalidPeriodThrows() async throws {
        let (container, context) = try makeContainerAndContext()
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        await repository.useSharedContext(context)
        let useCase = DefaultBudgetMutationUseCase(repository: repository)

        let input = BudgetInput(
            amount: 1000,
            categoryId: nil,
            startYear: 2025,
            startMonth: 12,
            endYear: 2025,
            endMonth: 10,
        )

        await #expect(throws: BudgetStoreError.invalidPeriod) {
            try await useCase.addBudget(input: input)
        }
    }
}

private extension BudgetMutationUseCaseTests {
    func makeContainerAndContext() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        return (container, ModelContext(container))
    }
}

import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataBudgetRepository: BudgetRepository {
    private lazy var recurringPaymentRepository: RecurringPaymentRepository = SwiftDataRecurringPaymentRepository(
        modelContainer: modelContainer
    )

    private var context: ModelContext { modelContext }

    internal func fetchSnapshot(for year: Int) async throws -> BudgetSnapshot {
        let budgets = try context.fetch(BudgetQueries.allBudgets())

        // 年の範囲の取引のみ取得（パフォーマンス最適化）
        let transactions: [SwiftDataTransaction] = if let startDate = Date.from(year: year, month: 1),
                                                      let endDate = Date.from(year: year + 1, month: 1) {
            try context.fetch(TransactionQueries.between(
                startDate: startDate,
                endDate: endDate,
            ))
        } else {
            []
        }

        let categories = try context.fetch(CategoryQueries.sortedForDisplay())
        let definitions = try await recurringPaymentRepository.definitions(filter: nil)
        let balances = try await recurringPaymentRepository.balances(query: nil)
        let occurrences = try await recurringPaymentRepository.occurrences(query: nil)
        let config = try context.fetch(BudgetQueries.annualConfig(for: year)).first

        // SwiftDataモデルをドメインモデルに変換
        let budgetModels = budgets.map { Budget(from: $0) }
        let transactionModels = transactions.map { Transaction(from: $0) }
        let categoryModels = categories.map { Category(from: $0) }
        let configModel = config.map { AnnualBudgetConfig(from: $0) }

        return BudgetSnapshot(
            budgets: budgetModels,
            transactions: transactionModels,
            categories: categoryModels,
            annualBudgetConfig: configModel,
            recurringPaymentDefinitions: definitions,
            recurringPaymentBalances: balances,
            recurringPaymentOccurrences: occurrences,
        )
    }

    internal func category(id: UUID) async throws -> Category? {
        try context.fetch(CategoryQueries.byId(id)).first.map { Category(from: $0) }
    }

    internal func findCategoryByName(_ name: String, parentId: UUID?) async throws -> Category? {
        let descriptor: ModelFetchRequest<SwiftDataCategory> = if let parentId {
            CategoryQueries.firstMatching(
                predicate: #Predicate { category in
                    category.name == name && category.parent?.id == parentId
                },
            )
        } else {
            CategoryQueries.firstMatching(
                predicate: #Predicate { category in
                    category.name == name && category.parent == nil
                },
            )
        }
        return try context.fetch(descriptor).first.map { Category(from: $0) }
    }

    internal func createCategory(name: String, parentId: UUID?) async throws -> UUID {
        let parent = try await resolveCategory(id: parentId)
        let category = SwiftDataCategory(name: name, parent: parent)
        context.insert(category)
        return category.id
    }

    internal func countCategories() async throws -> Int {
        try context.count(SwiftDataCategory.self)
    }

    internal func findInstitutionByName(_ name: String) async throws -> FinancialInstitution? {
        try context.fetch(FinancialInstitutionQueries.byName(name)).first.map { FinancialInstitution(from: $0) }
    }

    internal func createInstitution(name: String) async throws -> UUID {
        let institution = SwiftDataFinancialInstitution(name: name)
        context.insert(institution)
        return institution.id
    }

    internal func countFinancialInstitutions() async throws -> Int {
        try context.count(SwiftDataFinancialInstitution.self)
    }

    internal func annualBudgetConfig(for year: Int) async throws -> AnnualBudgetConfig? {
        try context.fetch(BudgetQueries.annualConfig(for: year)).first.map { AnnualBudgetConfig(from: $0) }
    }

    internal func countAnnualBudgetConfigs() async throws -> Int {
        try context.count(SwiftDataAnnualBudgetConfig.self)
    }

    internal func addBudget(_ input: BudgetInput) async throws {
        let budget = SwiftDataBudget(
            amount: input.amount,
            category: try await resolveCategory(id: input.categoryId),
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        context.insert(budget)
    }

    internal func countBudgets() async throws -> Int {
        try context.count(SwiftDataBudget.self)
    }

    internal func updateBudget(input: BudgetUpdateInput) async throws {
        guard let budget = try context.fetch(BudgetQueries.byId(input.id)).first else {
            throw RepositoryError.notFound
        }
        budget.amount = input.input.amount
        if let categoryId = input.input.categoryId {
            budget.category = try await resolveCategory(id: categoryId)
        } else {
            budget.category = nil
        }
        budget.startYear = input.input.startYear
        budget.startMonth = input.input.startMonth
        budget.endYear = input.input.endYear
        budget.endMonth = input.input.endMonth
        budget.updatedAt = Date()
    }

    internal func deleteBudget(id: UUID) async throws {
        guard let budget = try context.fetch(BudgetQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        context.delete(budget)
    }

    internal func deleteAllBudgets() async throws {
        let descriptor: ModelFetchRequest<SwiftDataBudget> = ModelFetchFactory.make()
        let budgets = try context.fetch(descriptor)
        for budget in budgets {
            context.delete(budget)
        }
        try await saveChanges()
    }

    internal func deleteAllAnnualBudgetConfigs() async throws {
        let descriptor: ModelFetchRequest<SwiftDataAnnualBudgetConfig> = ModelFetchFactory.make()
        let configs = try context.fetch(descriptor)
        for config in configs {
            context.delete(config)
        }
        try await saveChanges()
    }

    internal func deleteAllCategories() async throws {
        let descriptor: ModelFetchRequest<SwiftDataCategory> = ModelFetchFactory.make()
        let categories = try context.fetch(descriptor)
        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)
        for category in minors + majors {
            context.delete(category)
        }
        try await saveChanges()
    }

    internal func deleteAllFinancialInstitutions() async throws {
        let descriptor: ModelFetchRequest<SwiftDataFinancialInstitution> = ModelFetchFactory.make()
        let institutions = try context.fetch(descriptor)
        for institution in institutions {
            context.delete(institution)
        }
        try await saveChanges()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws {
        let config = try context.fetch(BudgetQueries.annualConfig(for: input.year)).first
            ?? SwiftDataAnnualBudgetConfig(
                year: input.year,
                totalAmount: input.totalAmount,
                policy: input.policy,
            )
        if config.modelContext == nil {
            context.insert(config)
        }

        let now = Date()
        config.totalAmount = input.totalAmount
        config.policy = input.policy
        config.updatedAt = now

        let existingAllocations = Dictionary(uniqueKeysWithValues: config.allocations.map { allocation in
            (allocation.category.id, allocation)
        })
        var seenCategoryIds: Set<UUID> = []

        for draft in input.allocations {
            guard let category = try await resolveCategory(id: draft.categoryId) else {
                throw RepositoryError.notFound
            }

            if !category.allowsAnnualBudget {
                category.allowsAnnualBudget = true
                category.updatedAt = now
            }

            seenCategoryIds.insert(category.id)

            if let allocation = existingAllocations[category.id] {
                allocation.amount = draft.amount
                allocation.policyOverride = draft.policyOverride
                allocation.updatedAt = now
            } else {
                let allocation = SwiftDataAnnualBudgetAllocation(
                    amount: draft.amount,
                    category: category,
                    policyOverride: draft.policyOverride,
                )
                allocation.updatedAt = now
                config.allocations.append(allocation)
            }
        }

        let allocationsToRemove = config.allocations.filter { !seenCategoryIds.contains($0.category.id) }
        for allocation in allocationsToRemove {
            if let index = config.allocations.firstIndex(where: { $0.id == allocation.id }) {
                config.allocations.remove(at: index)
            }
            context.delete(allocation)
        }
    }

    internal func saveChanges() async throws {
        try context.save()
    }
}

private extension SwiftDataBudgetRepository {
    func resolveCategory(id: UUID?) async throws -> SwiftDataCategory? {
        guard let id else { return nil }
        guard let category = try context.fetch(CategoryQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        return category
    }
}

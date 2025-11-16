import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    private let recurringPaymentRepository: RecurringPaymentRepository

    internal init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        recurringPaymentRepository: RecurringPaymentRepository? = nil,
    ) {
        self.modelContext = modelContext
        self.recurringPaymentRepository = recurringPaymentRepository
            ?? RecurringPaymentRepositoryFactory.make(modelContainer: modelContainer)
    }

    internal convenience init(
        modelContainer: ModelContainer,
        recurringPaymentRepository: RecurringPaymentRepository? = nil,
    ) {
        self.init(
            modelContext: ModelContext(modelContainer),
            modelContainer: modelContainer,
            recurringPaymentRepository: recurringPaymentRepository
        )
    }

    internal func fetchSnapshot(for year: Int) throws -> BudgetSnapshot {
        let budgets = try modelContext.fetch(BudgetQueries.allBudgets())

        // 年の範囲の取引のみ取得（パフォーマンス最適化）
        let transactions: [TransactionEntity] = if let startDate = Date.from(year: year, month: 1),
                                             let endDate = Date.from(year: year + 1, month: 1) {
            try modelContext.fetch(TransactionQueries.between(
                startDate: startDate,
                endDate: endDate,
            ))
        } else {
            []
        }

        let categories = try modelContext.fetch(CategoryQueries.sortedForDisplay())
        let definitions = try recurringPaymentRepository.definitions(filter: nil)
        let balances = try recurringPaymentRepository.balances(query: nil)
        let occurrences = try recurringPaymentRepository.occurrences(query: nil)
        let config = try modelContext.fetch(BudgetQueries.annualConfig(for: year)).first

        // SwiftDataモデルをDTOに変換
        let budgetDTOs = budgets.map { Budget(from: $0) }
        let transactionDTOs = transactions.map { Transaction(from: $0) }
        let categoryDTOs = categories.map { Category(from: $0) }
        let configDTO = config.map { AnnualBudgetConfig(from: $0) }

        return BudgetSnapshot(
            budgets: budgetDTOs,
            transactions: transactionDTOs,
            categories: categoryDTOs,
            annualBudgetConfig: configDTO,
            recurringPaymentDefinitions: definitions,
            recurringPaymentBalances: balances,
            recurringPaymentOccurrences: occurrences,
        )
    }

    internal func category(id: UUID) throws -> Category? {
        try modelContext.fetch(CategoryQueries.byId(id)).first.map { Category(from: $0) }
    }

    internal func findCategoryByName(_ name: String, parentId: UUID?) throws -> Category? {
        let descriptor: ModelFetchRequest<CategoryEntity>
        if let parentId {
            descriptor = CategoryQueries.firstMatching(
                predicate: #Predicate { category in
                    category.name == name && category.parent?.id == parentId
                }
            )
        } else {
            descriptor = CategoryQueries.firstMatching(
                predicate: #Predicate { category in
                    category.name == name && category.parent == nil
                }
            )
        }
        return try modelContext.fetch(descriptor).first.map { Category(from: $0) }
    }

    internal func createCategory(name: String, parentId: UUID?) throws -> UUID {
        let parent = try resolveCategory(id: parentId)
        let category = CategoryEntity(name: name, parent: parent)
        modelContext.insert(category)
        return category.id
    }

    internal func countCategories() throws -> Int {
        try modelContext.count(CategoryEntity.self)
    }

    internal func findInstitutionByName(_ name: String) throws -> FinancialInstitution? {
        try modelContext.fetch(FinancialInstitutionQueries.byName(name)).first.map { FinancialInstitution(from: $0) }
    }

    internal func createInstitution(name: String) throws -> UUID {
        let institution = FinancialInstitutionEntity(name: name)
        modelContext.insert(institution)
        return institution.id
    }

    internal func countFinancialInstitutions() throws -> Int {
        try modelContext.count(FinancialInstitutionEntity.self)
    }

    internal func annualBudgetConfig(for year: Int) throws -> AnnualBudgetConfig? {
        try modelContext.fetch(BudgetQueries.annualConfig(for: year)).first.map { AnnualBudgetConfig(from: $0) }
    }

    internal func countAnnualBudgetConfigs() throws -> Int {
        try modelContext.count(AnnualBudgetConfigEntity.self)
    }

    internal func addBudget(_ input: BudgetInput) throws {
        let budget = BudgetEntity(
            amount: input.amount,
            category: try resolveCategory(id: input.categoryId),
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth
        )
        modelContext.insert(budget)
    }

    internal func countBudgets() throws -> Int {
        try modelContext.count(BudgetEntity.self)
    }

    internal func updateBudget(input: BudgetUpdateInput) throws {
        guard let budget = try modelContext.fetch(BudgetQueries.byId(input.id)).first else {
            throw RepositoryError.notFound
        }
        budget.amount = input.input.amount
        if let categoryId = input.input.categoryId {
            budget.category = try resolveCategory(id: categoryId)
        } else {
            budget.category = nil
        }
        budget.startYear = input.input.startYear
        budget.startMonth = input.input.startMonth
        budget.endYear = input.input.endYear
        budget.endMonth = input.input.endMonth
        budget.updatedAt = Date()
    }

    internal func deleteBudget(id: UUID) throws {
        guard let budget = try modelContext.fetch(BudgetQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(budget)
    }

    internal func deleteAllBudgets() throws {
        let descriptor: ModelFetchRequest<BudgetEntity> = ModelFetchFactory.make()
        let budgets = try modelContext.fetch(descriptor)
        for budget in budgets {
            modelContext.delete(budget)
        }
        try saveChanges()
    }

    internal func deleteAllAnnualBudgetConfigs() throws {
        let descriptor: ModelFetchRequest<AnnualBudgetConfigEntity> = ModelFetchFactory.make()
        let configs = try modelContext.fetch(descriptor)
        for config in configs {
            modelContext.delete(config)
        }
        try saveChanges()
    }

    internal func deleteAllCategories() throws {
        let descriptor: ModelFetchRequest<CategoryEntity> = ModelFetchFactory.make()
        let categories = try modelContext.fetch(descriptor)
        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)
        for category in minors + majors {
            modelContext.delete(category)
        }
        try saveChanges()
    }

    internal func deleteAllFinancialInstitutions() throws {
        let descriptor: ModelFetchRequest<FinancialInstitutionEntity> = ModelFetchFactory.make()
        let institutions = try modelContext.fetch(descriptor)
        for institution in institutions {
            modelContext.delete(institution)
        }
        try saveChanges()
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws {
        let config = try modelContext.fetch(BudgetQueries.annualConfig(for: input.year)).first
            ?? AnnualBudgetConfigEntity(
                year: input.year,
                totalAmount: input.totalAmount,
                policy: input.policy
            )
        if config.modelContext == nil {
            modelContext.insert(config)
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
            guard let category = try resolveCategory(id: draft.categoryId) else {
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
                let allocation = AnnualBudgetAllocation(
                    amount: draft.amount,
                    category: category,
                    policyOverride: draft.policyOverride
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
            modelContext.delete(allocation)
        }
    }

    internal func saveChanges() throws {
        try modelContext.save()
    }
}

private extension SwiftDataBudgetRepository {
    func resolveCategory(id: UUID?) throws -> CategoryEntity? {
        guard let id else { return nil }
        guard let category = try modelContext.fetch(CategoryQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        return category
    }
}

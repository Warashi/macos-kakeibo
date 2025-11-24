import Foundation
import SwiftData

/// SwiftDataを使用したBackupRepositoryの実装
internal actor SwiftDataBackupRepository: BackupRepository {
    private let modelContainer: ModelContainer

    internal init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - BackupRepository

    internal func fetchAllEntities() async throws -> BackupEntitiesData {
        let modelContext = ModelContext(modelContainer)
        let transactions = try modelContext.fetchAll(SwiftDataTransaction.self)
        let categories = try modelContext.fetchAll(SwiftDataCategory.self)
        let budgets = try modelContext.fetchAll(SwiftDataBudget.self)
        let configs = try modelContext.fetchAll(SwiftDataAnnualBudgetConfig.self)
        let allocations = try modelContext.fetchAll(SwiftDataAnnualBudgetAllocation.self)
        let institutions = try modelContext.fetchAll(SwiftDataFinancialInstitution.self)
        let definitions = try modelContext.fetchAll(SwiftDataRecurringPaymentDefinition.self)
        let occurrences = try modelContext.fetchAll(SwiftDataRecurringPaymentOccurrence.self)
        let balances = try modelContext.fetchAll(SwiftDataRecurringPaymentSavingBalance.self)
        let holidays = try modelContext.fetchAll(SwiftDataCustomHoliday.self)

        return BackupEntitiesData(
            transactions: transactions.map(BackupTransactionDTO.init),
            categories: categories.map(BackupCategory.init),
            budgets: budgets.map(BackupBudgetDTO.init),
            annualBudgetConfigs: configs.map(BackupAnnualBudgetConfig.init),
            annualBudgetAllocations: allocations.map(BackupAnnualBudgetAllocationDTO.init),
            financialInstitutions: institutions.map(BackupFinancialInstitutionDTO.init),
            recurringPaymentDefinitions: definitions.map(BackupRecurringPaymentDefinitionDTO.init),
            recurringPaymentOccurrences: occurrences.map(BackupRecurringPaymentOccurrenceDTO.init),
            recurringPaymentSavingBalances: balances.map(BackupRecurringPaymentSavingBalanceDTO.init),
            customHolidays: holidays.map(BackupCustomHolidayDTO.init),
        )
    }

    internal func clearAllData() async throws {
        let modelContext = ModelContext(modelContainer)
        try clearAllData(in: modelContext)
        try modelContext.save()
    }

    internal func restoreEntities(_ data: BackupEntitiesData) async throws {
        let modelContext = ModelContext(modelContainer)
        try clearAllData(in: modelContext)

        // 依存関係の順序に従って復元
        let institutions = try insertFinancialInstitutions(data.financialInstitutions, context: modelContext)
        let categories = try insertCategories(data.categories, context: modelContext)
        try insertCustomHolidays(data.customHolidays, context: modelContext)
        let configs = try insertAnnualBudgetConfigs(data.annualBudgetConfigs, context: modelContext)
        try insertAnnualBudgetAllocations(
            data.annualBudgetAllocations,
            categories: categories,
            configs: configs,
            context: modelContext,
        )
        try insertBudgets(data.budgets, categories: categories, context: modelContext)
        let definitions = try insertRecurringPaymentDefinitions(
            data.recurringPaymentDefinitions,
            categories: categories,
            context: modelContext,
        )
        let transactions = try insertTransactions(
            data.transactions,
            categories: categories,
            institutions: institutions,
            context: modelContext,
        )
        try insertRecurringPaymentOccurrences(
            data.recurringPaymentOccurrences,
            definitions: definitions,
            transactions: transactions,
            context: modelContext,
        )
        try insertRecurringPaymentSavingBalances(
            data.recurringPaymentSavingBalances,
            definitions: definitions,
            context: modelContext,
        )

        try modelContext.save()
    }

    // MARK: - Clear

    private func clearAllData(in context: ModelContext) throws {
        // 依存関係の順序に注意して削除
        try deleteAll(SwiftDataRecurringPaymentOccurrence.self, in: context)
        try deleteAll(SwiftDataRecurringPaymentSavingBalance.self, in: context)
        try deleteAll(SwiftDataRecurringPaymentDefinition.self, in: context)
        try deleteAll(SwiftDataAnnualBudgetAllocation.self, in: context)
        try deleteAll(SwiftDataTransaction.self, in: context)
        try deleteAll(SwiftDataBudget.self, in: context)
        try deleteAll(SwiftDataAnnualBudgetConfig.self, in: context)
        try deleteCategoriesSafely(in: context)
        try deleteAll(SwiftDataFinancialInstitution.self, in: context)
        try deleteAll(SwiftDataCustomHoliday.self, in: context)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }

    /// 親子関係を維持しながらカテゴリを削除
    private func deleteCategoriesSafely(in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<SwiftDataCategory> = ModelFetchFactory.make()
        let categories = try context.fetch(descriptor)
        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)

        for category in minors + majors {
            context.delete(category)
        }
    }

    // MARK: - Insert

    @discardableResult
    private func insertFinancialInstitutions(
        _ dtos: [BackupFinancialInstitutionDTO],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataFinancialInstitution] {
        var result: [UUID: SwiftDataFinancialInstitution] = [:]
        for dto in dtos {
            let institution = SwiftDataFinancialInstitution(
                id: dto.id,
                name: dto.name,
                displayOrder: dto.displayOrder,
            )
            institution.createdAt = dto.createdAt
            institution.updatedAt = dto.updatedAt
            context.insert(institution)
            result[dto.id] = institution
        }
        return result
    }

    @discardableResult
    private func insertCategories(
        _ dtos: [BackupCategory],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataCategory] {
        var result: [UUID: SwiftDataCategory] = [:]

        for dto in dtos {
            let category = SwiftDataCategory(
                id: dto.id,
                name: dto.name,
                allowsAnnualBudget: dto.allowsAnnualBudget,
                displayOrder: dto.displayOrder,
            )
            category.createdAt = dto.createdAt
            category.updatedAt = dto.updatedAt
            context.insert(category)
            result[dto.id] = category
        }

        for dto in dtos {
            guard let parentId = dto.parentId,
                  let parent = result[parentId],
                  let category = result[dto.id] else {
                continue
            }
            category.parent = parent
        }

        return result
    }

    private func insertBudgets(
        _ dtos: [BackupBudgetDTO],
        categories: [UUID: SwiftDataCategory],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let budget = SwiftDataBudget(
                id: dto.id,
                amount: dto.amount,
                category: dto.categoryId.flatMap { categories[$0] },
                startYear: dto.startYear,
                startMonth: dto.startMonth,
                endYear: dto.endYear,
                endMonth: dto.endMonth,
            )
            budget.createdAt = dto.createdAt
            budget.updatedAt = dto.updatedAt
            context.insert(budget)
        }
    }

    @discardableResult
    private func insertAnnualBudgetConfigs(
        _ dtos: [BackupAnnualBudgetConfig],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataAnnualBudgetConfig] {
        var result: [UUID: SwiftDataAnnualBudgetConfig] = [:]
        for dto in dtos {
            let config = SwiftDataAnnualBudgetConfig(
                id: dto.id,
                year: dto.year,
                totalAmount: dto.totalAmount,
                policy: dto.policy,
            )
            config.createdAt = dto.createdAt
            config.updatedAt = dto.updatedAt
            context.insert(config)
            result[dto.id] = config
        }
        return result
    }

    @discardableResult
    private func insertTransactions(
        _ dtos: [BackupTransactionDTO],
        categories: [UUID: SwiftDataCategory],
        institutions: [UUID: SwiftDataFinancialInstitution],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataTransaction] {
        var result: [UUID: SwiftDataTransaction] = [:]
        for dto in dtos {
            let transaction = SwiftDataTransaction(
                id: dto.id,
                date: dto.date,
                title: dto.title,
                amount: dto.amount,
                memo: dto.memo,
                isIncludedInCalculation: dto.isIncludedInCalculation,
                isTransfer: dto.isTransfer,
                financialInstitution: dto.financialInstitutionId.flatMap { institutions[$0] },
                majorCategory: dto.majorCategoryId.flatMap { categories[$0] },
                minorCategory: dto.minorCategoryId.flatMap { categories[$0] },
            )
            transaction.createdAt = dto.createdAt
            transaction.updatedAt = dto.updatedAt
            context.insert(transaction)
            result[dto.id] = transaction
        }
        return result
    }

    private func insertCustomHolidays(
        _ dtos: [BackupCustomHolidayDTO],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let holiday = SwiftDataCustomHoliday(
                id: dto.id,
                date: dto.date,
                name: dto.name,
                isRecurring: dto.isRecurring,
            )
            holiday.createdAt = dto.createdAt
            holiday.updatedAt = dto.updatedAt
            context.insert(holiday)
        }
    }

    private func insertAnnualBudgetAllocations(
        _ dtos: [BackupAnnualBudgetAllocationDTO],
        categories: [UUID: SwiftDataCategory],
        configs: [UUID: SwiftDataAnnualBudgetConfig],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            guard let category = categories[dto.categoryId] else { continue }
            let allocation = SwiftDataAnnualBudgetAllocation(
                id: dto.id,
                amount: dto.amount,
                category: category,
            )
            if let policyOverrideRawValue = dto.policyOverrideRawValue {
                allocation.policyOverrideRawValue = policyOverrideRawValue
            }
            if let configId = dto.configId {
                allocation.config = configs[configId]
            }
            allocation.createdAt = dto.createdAt
            allocation.updatedAt = dto.updatedAt
            context.insert(allocation)
        }
    }

    @discardableResult
    private func insertRecurringPaymentDefinitions(
        _ dtos: [BackupRecurringPaymentDefinitionDTO],
        categories: [UUID: SwiftDataCategory],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataRecurringPaymentDefinition] {
        var result: [UUID: SwiftDataRecurringPaymentDefinition] = [:]
        for dto in dtos {
            let definition = SwiftDataRecurringPaymentDefinition(
                id: dto.id,
                name: dto.name,
                notes: dto.notes,
                amount: dto.amount,
                recurrenceIntervalMonths: dto.recurrenceIntervalMonths,
                firstOccurrenceDate: dto.firstOccurrenceDate,
                endDate: dto.endDate,
                category: dto.categoryId.flatMap { categories[$0] },
                savingStrategy: dto.savingStrategy,
                customMonthlySavingAmount: dto.customMonthlySavingAmount,
                dateAdjustmentPolicy: dto.dateAdjustmentPolicy,
                recurrenceDayPattern: dto.recurrenceDayPattern,
            )
            definition.createdAt = dto.createdAt
            definition.updatedAt = dto.updatedAt
            context.insert(definition)
            result[dto.id] = definition
        }
        return result
    }

    private func insertRecurringPaymentOccurrences(
        _ dtos: [BackupRecurringPaymentOccurrenceDTO],
        definitions: [UUID: SwiftDataRecurringPaymentDefinition],
        transactions: [UUID: SwiftDataTransaction],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            guard let definition = definitions[dto.definitionId] else { continue }
            let occurrence = SwiftDataRecurringPaymentOccurrence(
                id: dto.id,
                definition: definition,
                scheduledDate: dto.scheduledDate,
                expectedAmount: dto.expectedAmount,
                status: dto.status,
                actualDate: dto.actualDate,
                actualAmount: dto.actualAmount,
                transaction: dto.transactionId.flatMap { transactions[$0] },
            )
            occurrence.createdAt = dto.createdAt
            occurrence.updatedAt = dto.updatedAt
            context.insert(occurrence)
        }
    }

    private func insertRecurringPaymentSavingBalances(
        _ dtos: [BackupRecurringPaymentSavingBalanceDTO],
        definitions: [UUID: SwiftDataRecurringPaymentDefinition],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            guard let definition = definitions[dto.definitionId] else { continue }
            let balance = SwiftDataRecurringPaymentSavingBalance(
                id: dto.id,
                definition: definition,
                totalSavedAmount: dto.totalSavedAmount,
                totalPaidAmount: dto.totalPaidAmount,
                lastUpdatedYear: dto.lastUpdatedYear,
                lastUpdatedMonth: dto.lastUpdatedMonth,
            )
            balance.createdAt = dto.createdAt
            balance.updatedAt = dto.updatedAt
            context.insert(balance)
        }
    }
}

import Foundation
import SwiftData

extension BackupManager {
    @discardableResult
    internal func insertFinancialInstitutions(
        _ dtos: [BackupFinancialInstitutionDTO],
        context: ModelContext
    ) throws -> [UUID: SwiftDataFinancialInstitution] {
        var result: [UUID: SwiftDataFinancialInstitution] = [:]
        for dto in dtos {
            let institution = SwiftDataFinancialInstitution(
                id: dto.id,
                name: dto.name,
                displayOrder: dto.displayOrder
            )
            institution.createdAt = dto.createdAt
            institution.updatedAt = dto.updatedAt
            context.insert(institution)
            result[dto.id] = institution
        }
        return result
    }

    @discardableResult
    internal func insertCategories(
        _ dtos: [BackupCategory],
        context: ModelContext
    ) throws -> [UUID: SwiftDataCategory] {
        var result: [UUID: SwiftDataCategory] = [:]

        for dto in dtos {
            let category = SwiftDataCategory(
                id: dto.id,
                name: dto.name,
                allowsAnnualBudget: dto.allowsAnnualBudget,
                displayOrder: dto.displayOrder
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

    internal func insertBudgets(
        _ dtos: [BackupBudgetDTO],
        categories: [UUID: SwiftDataCategory],
        context: ModelContext
    ) throws {
        for dto in dtos {
            let budget = SwiftDataBudget(
                id: dto.id,
                amount: dto.amount,
                category: dto.categoryId.flatMap { categories[$0] },
                startYear: dto.startYear,
                startMonth: dto.startMonth,
                endYear: dto.endYear,
                endMonth: dto.endMonth
            )
            budget.createdAt = dto.createdAt
            budget.updatedAt = dto.updatedAt
            context.insert(budget)
        }
    }

    @discardableResult
    internal func insertAnnualBudgetConfigs(
        _ dtos: [BackupAnnualBudgetConfig],
        context: ModelContext
    ) throws -> [UUID: SwiftDataAnnualBudgetConfig] {
        var result: [UUID: SwiftDataAnnualBudgetConfig] = [:]
        for dto in dtos {
            let config = SwiftDataAnnualBudgetConfig(
                id: dto.id,
                year: dto.year,
                totalAmount: dto.totalAmount,
                policy: dto.policy
            )
            config.createdAt = dto.createdAt
            config.updatedAt = dto.updatedAt
            context.insert(config)
            result[dto.id] = config
        }
        return result
    }

    @discardableResult
    internal func insertTransactions(
        _ dtos: [BackupTransactionDTO],
        categories: [UUID: SwiftDataCategory],
        institutions: [UUID: SwiftDataFinancialInstitution],
        context: ModelContext
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
                minorCategory: dto.minorCategoryId.flatMap { categories[$0] }
            )
            transaction.createdAt = dto.createdAt
            transaction.updatedAt = dto.updatedAt
            context.insert(transaction)
            result[dto.id] = transaction
        }
        return result
    }

    internal func insertCustomHolidays(
        _ dtos: [BackupCustomHolidayDTO],
        context: ModelContext
    ) throws {
        for dto in dtos {
            let holiday = SwiftDataCustomHoliday(
                id: dto.id,
                date: dto.date,
                name: dto.name,
                isRecurring: dto.isRecurring
            )
            holiday.createdAt = dto.createdAt
            holiday.updatedAt = dto.updatedAt
            context.insert(holiday)
        }
    }

    internal func insertAnnualBudgetAllocations(
        _ dtos: [BackupAnnualBudgetAllocationDTO],
        categories: [UUID: SwiftDataCategory],
        configs: [UUID: SwiftDataAnnualBudgetConfig],
        context: ModelContext
    ) throws {
        for dto in dtos {
            guard let category = categories[dto.categoryId] else { continue }
            let allocation = SwiftDataAnnualBudgetAllocation(
                id: dto.id,
                amount: dto.amount,
                category: category
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
    internal func insertRecurringPaymentDefinitions(
        _ dtos: [BackupRecurringPaymentDefinitionDTO],
        categories: [UUID: SwiftDataCategory],
        context: ModelContext
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
                recurrenceDayPattern: dto.recurrenceDayPattern
            )
            definition.createdAt = dto.createdAt
            definition.updatedAt = dto.updatedAt
            context.insert(definition)
            result[dto.id] = definition
        }
        return result
    }

    internal func insertRecurringPaymentOccurrences(
        _ dtos: [BackupRecurringPaymentOccurrenceDTO],
        definitions: [UUID: SwiftDataRecurringPaymentDefinition],
        transactions: [UUID: SwiftDataTransaction],
        context: ModelContext
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
                transaction: dto.transactionId.flatMap { transactions[$0] }
            )
            occurrence.createdAt = dto.createdAt
            occurrence.updatedAt = dto.updatedAt
            context.insert(occurrence)
        }
    }

    internal func insertRecurringPaymentSavingBalances(
        _ dtos: [BackupRecurringPaymentSavingBalanceDTO],
        definitions: [UUID: SwiftDataRecurringPaymentDefinition],
        context: ModelContext
    ) throws {
        for dto in dtos {
            guard let definition = definitions[dto.definitionId] else { continue }
            let balance = SwiftDataRecurringPaymentSavingBalance(
                id: dto.id,
                definition: definition,
                totalSavedAmount: dto.totalSavedAmount,
                totalPaidAmount: dto.totalPaidAmount,
                lastUpdatedYear: dto.lastUpdatedYear,
                lastUpdatedMonth: dto.lastUpdatedMonth
            )
            balance.createdAt = dto.createdAt
            balance.updatedAt = dto.updatedAt
            context.insert(balance)
        }
    }
}

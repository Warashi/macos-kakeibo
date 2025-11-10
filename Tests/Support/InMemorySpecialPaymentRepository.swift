@testable import Kakeibo
import Foundation

internal final class InMemorySpecialPaymentRepository: SpecialPaymentRepository {
    private var definitionsStorage: [UUID: SpecialPaymentDefinition]
    private var balancesStorage: [UUID: SpecialPaymentSavingBalance]
    private var categoryLookup: [UUID: Category]
    private let scheduleService: SpecialPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal init(
        definitions: [SpecialPaymentDefinition] = [],
        balances: [SpecialPaymentSavingBalance] = [],
        categories: [Category] = [],
        scheduleService: SpecialPaymentScheduleService = SpecialPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.definitionsStorage = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        self.balancesStorage = Dictionary(uniqueKeysWithValues: balances.map { ($0.definition.id, $0) })
        var lookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        for definition in definitions {
            if let category = definition.category {
                lookup[category.id] = category
            }
        }
        self.categoryLookup = lookup
        self.scheduleService = scheduleService
        self.currentDateProvider = currentDateProvider
    }

    internal func definitions(filter: SpecialPaymentDefinitionFilter?) throws -> [SpecialPaymentDefinition] {
        var results = Array(definitionsStorage.values)
        if let ids = filter?.ids {
            results = results.filter { ids.contains($0.id) }
        }
        if let searchText = filter?.searchText?.lowercased(), !searchText.isEmpty {
            results = results.filter { $0.name.lowercased().contains(searchText) }
        }
        if let categoryIds = filter?.categoryIds, !categoryIds.isEmpty {
            results = results.filter { definition in
                guard let categoryId = definition.category?.id else {
                    return false
                }
                return categoryIds.contains(categoryId)
            }
        }
        return results
    }

    internal func occurrences(query: SpecialPaymentOccurrenceQuery?) throws -> [SpecialPaymentOccurrence] {
        var results = definitionsStorage.values.flatMap(\.occurrences)
        if let ids = query?.definitionIds {
            results = results.filter { ids.contains($0.definition.id) }
        }
        if let range = query?.range {
            results = results.filter { $0.scheduledDate >= range.startDate && $0.scheduledDate <= range.endDate }
        }
        if let statuses = query?.statusFilter, !statuses.isEmpty {
            results = results.filter { statuses.contains($0.status) }
        }
        return results.sorted(by: { $0.scheduledDate < $1.scheduledDate })
    }

    internal func balances(query: SpecialPaymentBalanceQuery?) throws -> [SpecialPaymentSavingBalance] {
        var results = Array(balancesStorage.values)
        if let ids = query?.definitionIds {
            results = results.filter { ids.contains($0.definition.id) }
        }
        return results
    }

    @discardableResult
    internal func createDefinition(_ input: SpecialPaymentDefinitionInput) throws -> SpecialPaymentDefinition {
        let category = try resolvedCategory(id: input.categoryId)

        let definition = SpecialPaymentDefinition(
            name: input.name,
            notes: input.notes,
            amount: input.amount,
            recurrenceIntervalMonths: input.recurrenceIntervalMonths,
            firstOccurrenceDate: input.firstOccurrenceDate,
            leadTimeMonths: input.leadTimeMonths,
            category: category,
            savingStrategy: input.savingStrategy,
            customMonthlySavingAmount: input.customMonthlySavingAmount,
            dateAdjustmentPolicy: input.dateAdjustmentPolicy,
            recurrenceDayPattern: input.recurrenceDayPattern
        )

        let errors = definition.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        definitionsStorage[definition.id] = definition
        if let category {
            categoryLookup[category.id] = category
        }
        return definition
    }

    internal func updateDefinition(_ definition: SpecialPaymentDefinition, input: SpecialPaymentDefinitionInput) throws {
        let category = try resolvedCategory(id: input.categoryId)

        definition.name = input.name
        definition.notes = input.notes
        definition.amount = input.amount
        definition.recurrenceIntervalMonths = input.recurrenceIntervalMonths
        definition.firstOccurrenceDate = input.firstOccurrenceDate
        definition.leadTimeMonths = input.leadTimeMonths
        definition.category = category
        definition.savingStrategy = input.savingStrategy
        definition.customMonthlySavingAmount = input.customMonthlySavingAmount
        definition.dateAdjustmentPolicy = input.dateAdjustmentPolicy
        definition.recurrenceDayPattern = input.recurrenceDayPattern
        definition.updatedAt = currentDateProvider()

        let errors = definition.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        definitionsStorage[definition.id] = definition
        if let category {
            categoryLookup[category.id] = category
        }
    }

    internal func deleteDefinition(_ definition: SpecialPaymentDefinition) throws {
        definitionsStorage.removeValue(forKey: definition.id)
        balancesStorage.removeValue(forKey: definition.id)
    }

    @discardableResult
    internal func synchronize(
        definition: SpecialPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?
    ) throws -> SpecialPaymentSynchronizationSummary {
        guard definition.recurrenceIntervalMonths > 0 else {
            throw SpecialPaymentDomainError.invalidRecurrence
        }
        guard horizonMonths >= 0 else {
            throw SpecialPaymentDomainError.invalidHorizon
        }

        let now = referenceDate ?? currentDateProvider()
        let plan = scheduleService.synchronizationPlan(
            for: definition,
            referenceDate: now,
            horizonMonths: horizonMonths
        )

        guard !plan.occurrences.isEmpty else {
            return SpecialPaymentSynchronizationSummary(
                syncedAt: now,
                createdCount: 0,
                updatedCount: 0,
                removedCount: 0
            )
        }

        definition.occurrences = plan.occurrences
        definition.updatedAt = now
        definitionsStorage[definition.id] = definition

        return SpecialPaymentSynchronizationSummary(
            syncedAt: now,
            createdCount: plan.created.count,
            updatedCount: plan.updated.count,
            removedCount: plan.removed.count
        )
    }

    @discardableResult
    internal func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int
    ) throws -> SpecialPaymentSynchronizationSummary {
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = input.transaction
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        return try synchronize(
            definition: occurrence.definition,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider()
        )
    }

    @discardableResult
    internal func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int
    ) throws -> SpecialPaymentSynchronizationSummary? {
        let now = currentDateProvider()
        let wasCompleted = occurrence.status == .completed
        let willBeCompleted = input.status == .completed

        occurrence.status = input.status
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = input.transaction
        occurrence.updatedAt = now

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        guard wasCompleted != willBeCompleted else {
            return nil
        }

        return try synchronize(
            definition: occurrence.definition,
            horizonMonths: horizonMonths,
            referenceDate: now
        )
    }

    internal func saveChanges() throws {
        // No-op for in-memory implementation
    }

    private func resolvedCategory(id: UUID?) throws -> Category? {
        guard let id else { return nil }
        guard let category = categoryLookup[id] else {
            throw SpecialPaymentDomainError.categoryNotFound
        }
        return category
    }
}

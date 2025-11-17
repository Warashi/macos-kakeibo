import Foundation
@testable import Kakeibo

internal final class InMemoryRecurringPaymentRepository: RecurringPaymentRepository {
    private var definitionsStorage: [UUID: SwiftDataRecurringPaymentDefinition]
    private var balancesStorage: [UUID: SwiftDataRecurringPaymentSavingBalance]
    private var categoryLookup: [UUID: Kakeibo.SwiftDataCategory]
    private let scheduleService: RecurringPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal init(
        definitions: [SwiftDataRecurringPaymentDefinition] = [],
        balances: [SwiftDataRecurringPaymentSavingBalance] = [],
        categories: [Kakeibo.SwiftDataCategory] = [],
        scheduleService: RecurringPaymentScheduleService = RecurringPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.definitionsStorage = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        self.balancesStorage = Dictionary(uniqueKeysWithValues: balances.map { ($0.definition.id, $0) })
        var lookup: [UUID: Kakeibo.SwiftDataCategory] = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        for definition in definitions {
            if let category = definition.category {
                lookup[category.id] = category
            }
        }
        self.categoryLookup = lookup
        self.scheduleService = scheduleService
        self.currentDateProvider = currentDateProvider
    }

    internal func definitions(filter: RecurringPaymentDefinitionFilter?) throws -> [RecurringPaymentDefinition] {
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
        return results.map { RecurringPaymentDefinition(from: $0) }
    }

    internal func occurrences(query: RecurringPaymentOccurrenceQuery?) throws -> [RecurringPaymentOccurrence] {
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
            .map { RecurringPaymentOccurrence(from: $0) }
    }

    internal func balances(query: RecurringPaymentBalanceQuery?) throws -> [RecurringPaymentSavingBalance] {
        var results = Array(balancesStorage.values)
        if let ids = query?.definitionIds {
            results = results.filter { ids.contains($0.definition.id) }
        }
        return results.map { RecurringPaymentSavingBalance(from: $0) }
    }

    @discardableResult
    internal func createDefinition(_ input: RecurringPaymentDefinitionInput) throws -> UUID {
        let category = try resolvedSwiftDataCategory(id: input.categoryId)

        let definition = SwiftDataRecurringPaymentDefinition(
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
            recurrenceDayPattern: input.recurrenceDayPattern,
        )

        let errors = definition.validate()
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        definitionsStorage[definition.id] = definition
        if let category {
            categoryLookup[category.id] = category
        }
        return definition.id
    }

    internal func updateDefinition(
        definitionId: UUID,
        input: RecurringPaymentDefinitionInput,
    ) throws {
        guard let definition = definitionsStorage[definitionId] else {
            throw RecurringPaymentDomainError.definitionNotFound
        }

        let category = try resolvedSwiftDataCategory(id: input.categoryId)

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
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        definitionsStorage[definition.id] = definition
        if let category {
            categoryLookup[category.id] = category
        }
    }

    internal func deleteDefinition(definitionId: UUID) throws {
        definitionsStorage.removeValue(forKey: definitionId)
        balancesStorage.removeValue(forKey: definitionId)
    }

    @discardableResult
    internal func synchronize(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary {
        guard let definition = definitionsStorage[definitionId] else {
            throw RecurringPaymentDomainError.definitionNotFound
        }

        guard definition.recurrenceIntervalMonths > 0 else {
            throw RecurringPaymentDomainError.invalidRecurrence
        }
        guard horizonMonths >= 0 else {
            throw RecurringPaymentDomainError.invalidHorizon
        }

        let now = referenceDate ?? currentDateProvider()
        let plan = scheduleService.synchronizationPlan(
            for: definition,
            referenceDate: now,
            horizonMonths: horizonMonths,
        )

        guard !plan.occurrences.isEmpty else {
            return RecurringPaymentSynchronizationSummary(
                syncedAt: now,
                createdCount: 0,
                updatedCount: 0,
                removedCount: 0,
            )
        }

        definition.occurrences = plan.occurrences
        definition.updatedAt = now
        definitionsStorage[definition.id] = definition

        return RecurringPaymentSynchronizationSummary(
            syncedAt: now,
            createdCount: plan.created.count,
            updatedCount: plan.updated.count,
            removedCount: plan.removed.count,
        )
    }

    @discardableResult
    internal func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary {
        guard let occurrence = findOccurrence(id: occurrenceId) else {
            throw RecurringPaymentDomainError.occurrenceNotFound
        }

        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        // Note: In-memory repository doesn't support transaction associations
        // occurrence.transaction = input.transaction
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        return try synchronize(
            definitionId: occurrence.definition.id,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider(),
        )
    }

    @discardableResult
    internal func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary? {
        guard let occurrence = findOccurrence(id: occurrenceId) else {
            throw RecurringPaymentDomainError.occurrenceNotFound
        }

        let now = currentDateProvider()
        let wasCompleted = occurrence.status == .completed
        let willBeCompleted = input.status == .completed

        occurrence.status = input.status
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        // Note: In-memory repository doesn't support transaction associations
        // occurrence.transaction = input.transaction
        occurrence.updatedAt = now

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        guard wasCompleted != willBeCompleted else {
            return nil
        }

        return try synchronize(
            definitionId: occurrence.definition.id,
            horizonMonths: horizonMonths,
            referenceDate: now,
        )
    }

    internal func saveChanges() throws {
        // No-op for in-memory implementation
    }

    private func resolvedSwiftDataCategory(id: UUID?) throws -> Kakeibo.SwiftDataCategory? {
        guard let id else { return nil }
        guard let category = categoryLookup[id] else {
            throw RecurringPaymentDomainError.categoryNotFound
        }
        return category
    }

    private func findOccurrence(id: UUID) -> SwiftDataRecurringPaymentOccurrence? {
        definitionsStorage.values.flatMap(\.occurrences).first { $0.id == id }
    }
}

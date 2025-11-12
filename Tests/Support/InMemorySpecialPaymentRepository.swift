import Foundation
@testable import Kakeibo

internal final class InMemorySpecialPaymentRepository: SpecialPaymentRepository {
    private var definitionsStorage: [UUID: SpecialPaymentDefinition]
    private var balancesStorage: [UUID: SpecialPaymentSavingBalance]
    private var categoryLookup: [UUID: Kakeibo.Category]
    private let scheduleService: SpecialPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal init(
        definitions: [SpecialPaymentDefinition] = [],
        balances: [SpecialPaymentSavingBalance] = [],
        categories: [Kakeibo.Category] = [],
        scheduleService: SpecialPaymentScheduleService = SpecialPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.definitionsStorage = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        self.balancesStorage = Dictionary(uniqueKeysWithValues: balances.map { ($0.definition.id, $0) })
        var lookup: [UUID: Kakeibo.Category] = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        for definition in definitions {
            if let category = definition.category {
                lookup[category.id] = category
            }
        }
        self.categoryLookup = lookup
        self.scheduleService = scheduleService
        self.currentDateProvider = currentDateProvider
    }

    internal func definitions(filter: SpecialPaymentDefinitionFilter?) throws -> [SpecialPaymentDefinitionDTO] {
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
        return results.map { SpecialPaymentDefinitionDTO(from: $0) }
    }

    internal func occurrences(query: SpecialPaymentOccurrenceQuery?) throws -> [SpecialPaymentOccurrenceDTO] {
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
        return results.sorted(by: { $0.scheduledDate < $1.scheduledDate }).map { SpecialPaymentOccurrenceDTO(from: $0) }
    }

    internal func balances(query: SpecialPaymentBalanceQuery?) throws -> [SpecialPaymentSavingBalanceDTO] {
        var results = Array(balancesStorage.values)
        if let ids = query?.definitionIds {
            results = results.filter { ids.contains($0.definition.id) }
        }
        return results.map { SpecialPaymentSavingBalanceDTO(from: $0) }
    }

    internal func findOccurrence(id: UUID) throws -> SpecialPaymentOccurrence {
        for definition in definitionsStorage.values {
            if let occurrence = definition.occurrences.first(where: { $0.id == id }) {
                return occurrence
            }
        }
        throw SpecialPaymentDomainError.occurrenceNotFound
    }

    @discardableResult
    internal func createDefinition(_ input: SpecialPaymentDefinitionInput) throws -> UUID {
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
            recurrenceDayPattern: input.recurrenceDayPattern,
        )

        let errors = definition.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        definitionsStorage[definition.id] = definition
        if let category {
            categoryLookup[category.id] = category
        }
        return definition.id
    }

    internal func updateDefinition(
        definitionId: UUID,
        input: SpecialPaymentDefinitionInput,
    ) throws {
        guard let definition = definitionsStorage[definitionId] else {
            throw SpecialPaymentDomainError.definitionNotFound
        }

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

    internal func deleteDefinition(definitionId: UUID) throws {
        definitionsStorage.removeValue(forKey: definitionId)
        balancesStorage.removeValue(forKey: definitionId)
    }

    @discardableResult
    internal func synchronize(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> SpecialPaymentSynchronizationSummary {
        guard let definition = definitionsStorage[definitionId] else {
            throw SpecialPaymentDomainError.definitionNotFound
        }

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
            horizonMonths: horizonMonths,
        )

        guard !plan.occurrences.isEmpty else {
            return SpecialPaymentSynchronizationSummary(
                syncedAt: now,
                createdCount: 0,
                updatedCount: 0,
                removedCount: 0,
            )
        }

        definition.occurrences = plan.occurrences
        definition.updatedAt = now
        definitionsStorage[definition.id] = definition

        return SpecialPaymentSynchronizationSummary(
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
    ) throws -> SpecialPaymentSynchronizationSummary {
        guard let occurrence = findOccurrence(id: occurrenceId) else {
            throw SpecialPaymentDomainError.occurrenceNotFound
        }

        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        // Note: In-memory repository doesn't support transaction associations
        // occurrence.transaction = input.transaction
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
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
    ) throws -> SpecialPaymentSynchronizationSummary? {
        guard let occurrence = findOccurrence(id: occurrenceId) else {
            throw SpecialPaymentDomainError.occurrenceNotFound
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
            throw SpecialPaymentDomainError.validationFailed(errors)
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

    private func resolvedCategory(id: UUID?) throws -> Kakeibo.Category? {
        guard let id else { return nil }
        guard let category = categoryLookup[id] else {
            throw SpecialPaymentDomainError.categoryNotFound
        }
        return category
    }

    private func findOccurrence(id: UUID) -> SpecialPaymentOccurrence? {
        definitionsStorage.values.flatMap(\.occurrences).first { $0.id == id }
    }
}

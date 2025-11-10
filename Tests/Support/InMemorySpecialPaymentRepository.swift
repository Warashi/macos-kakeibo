@testable import Kakeibo
import Foundation

internal final class InMemorySpecialPaymentRepository: SpecialPaymentRepository {
    private var definitionsStorage: [UUID: SpecialPaymentDefinition]
    private var balancesStorage: [UUID: SpecialPaymentSavingBalance]
    private let scheduleService: SpecialPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal init(
        definitions: [SpecialPaymentDefinition] = [],
        balances: [SpecialPaymentSavingBalance] = [],
        scheduleService: SpecialPaymentScheduleService = SpecialPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.definitionsStorage = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        self.balancesStorage = Dictionary(uniqueKeysWithValues: balances.map { ($0.definition.id, $0) })
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
}

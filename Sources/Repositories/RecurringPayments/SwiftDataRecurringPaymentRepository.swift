import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataRecurringPaymentRepository: RecurringPaymentRepository {
    private let modelContainer: ModelContainer
    private let sharedContext: ModelContext?
    private let scheduleService: RecurringPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal init(
        modelContainer: ModelContainer,
        scheduleService: RecurringPaymentScheduleService = RecurringPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() },
        sharedContext: ModelContext? = nil
    ) {
        self.modelContainer = modelContainer
        self.sharedContext = sharedContext
        self.scheduleService = scheduleService
        self.currentDateProvider = currentDateProvider
    }

    private func makeContext() -> ModelContext {
        if let sharedContext {
            return sharedContext
        }
        return ModelContext(modelContainer)
    }

    // Convenience initializer removed to encourage ModelContainer-based usage.

    internal func definitions(filter: RecurringPaymentDefinitionFilter?) throws -> [RecurringPaymentDefinitionDTO] {
        let context = makeContext()
        let descriptor = RecurringPaymentQueries.definitions(
            predicate: definitionPredicate(for: filter),
        )

        var results = try context.fetch(descriptor)
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

        return results.map { RecurringPaymentDefinitionDTO(from: $0) }
    }

    internal func occurrences(query: RecurringPaymentOccurrenceQuery?) throws -> [RecurringPaymentOccurrenceDTO] {
        let context = makeContext()
        let descriptor = RecurringPaymentQueries.occurrences(
            predicate: occurrencePredicate(for: query),
        )

        var results = try context.fetch(descriptor)

        if let statuses = query?.statusFilter, !statuses.isEmpty {
            results = results.filter { statuses.contains($0.status) }
        }

        if let definitionIds = query?.definitionIds, !definitionIds.isEmpty {
            results = results.filter { definitionIds.contains($0.definition.id) }
        }

        return results.map { RecurringPaymentOccurrenceDTO(from: $0) }
    }

    internal func balances(query: RecurringPaymentBalanceQuery?) throws -> [RecurringPaymentSavingBalanceDTO] {
        let context = makeContext()
        let descriptor = RecurringPaymentQueries.balances(
            predicate: balancePredicate(for: query),
        )

        return try context.fetch(descriptor).map { RecurringPaymentSavingBalanceDTO(from: $0) }
    }

    @discardableResult
    internal func createDefinition(_ input: RecurringPaymentDefinitionInput) throws -> UUID {
        let context = makeContext()
        let category = try resolvedCategory(id: input.categoryId, context: context)

        let definition = RecurringPaymentDefinition(
            name: input.name,
            notes: input.notes,
            amount: input.amount,
            recurrenceIntervalMonths: input.recurrenceIntervalMonths,
            firstOccurrenceDate: input.firstOccurrenceDate,
            endDate: input.endDate,
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

        context.insert(definition)
        try context.save()
        return definition.id
    }

    internal func updateDefinition(
        definitionId: UUID,
        input: RecurringPaymentDefinitionInput,
    ) throws {
        let context = makeContext()
        let definition = try findDefinition(id: definitionId, context: context)
        let category = try resolvedCategory(id: input.categoryId, context: context)

        definition.name = input.name
        definition.notes = input.notes
        definition.amount = input.amount
        definition.recurrenceIntervalMonths = input.recurrenceIntervalMonths
        definition.firstOccurrenceDate = input.firstOccurrenceDate
        definition.endDate = input.endDate
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

        try context.save()
    }

    internal func deleteDefinition(definitionId: UUID) throws {
        let context = makeContext()
        let definition = try findDefinition(id: definitionId, context: context)
        context.delete(definition)
        try context.save()
    }

    @discardableResult
    internal func synchronize(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date? = nil,
    ) throws -> RecurringPaymentSynchronizationSummary {
        let context = makeContext()
        let definition = try findDefinition(id: definitionId, context: context)

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

        plan.created.forEach { context.insert($0) }
        plan.removed.forEach { context.delete($0) }

        definition.occurrences = plan.occurrences
        definition.updatedAt = now

        try context.save()

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
        let context = makeContext()
        let occurrence = try findOccurrence(id: occurrenceId, context: context)

        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = try input.transaction.map { dto in
            try findTransaction(id: dto.id, context: context)
        }
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        try context.save()

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
        let context = makeContext()
        let occurrence = try findOccurrence(id: occurrenceId, context: context)
        let now = currentDateProvider()
        let wasCompleted = occurrence.status == .completed
        let willBeCompleted = input.status == .completed

        occurrence.status = input.status
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = try input.transaction.map { dto in
            try findTransaction(id: dto.id, context: context)
        }
        occurrence.updatedAt = now

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        try context.save()

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
        // Each repository method persists immediately; no shared context to save.
    }
}

private extension SwiftDataRecurringPaymentRepository {
    func findOccurrence(id: UUID, context: ModelContext) throws -> RecurringPaymentOccurrence {
        let predicate = #Predicate<RecurringPaymentOccurrence> { occurrence in
            occurrence.id == id
        }
        let descriptor = RecurringPaymentQueries.occurrences(predicate: predicate)
        guard let occurrence = try context.fetch(descriptor).first else {
            throw RecurringPaymentDomainError.occurrenceNotFound
        }
        return occurrence
    }
    func findDefinition(id: UUID, context: ModelContext) throws -> RecurringPaymentDefinition {
        let predicate = #Predicate<RecurringPaymentDefinition> { definition in
            definition.id == id
        }
        let descriptor = RecurringPaymentQueries.definitions(predicate: predicate)
        guard let definition = try context.fetch(descriptor).first else {
            throw RecurringPaymentDomainError.definitionNotFound
        }
        return definition
    }

    func findTransaction(id: UUID, context: ModelContext) throws -> Transaction {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.id == id
        }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        guard let transaction = try context.fetch(descriptor).first else {
            throw RecurringPaymentDomainError.validationFailed(["取引が見つかりません"])
        }
        return transaction
    }

    func definitionPredicate(
        for filter: RecurringPaymentDefinitionFilter?,
    ) -> Predicate<RecurringPaymentDefinition>? {
        guard let identifiers = filter?.ids, !identifiers.isEmpty else {
            return nil
        }

        return #Predicate<RecurringPaymentDefinition> { definition in
            identifiers.contains(definition.id)
        }
    }

    func occurrencePredicate(
        for query: RecurringPaymentOccurrenceQuery?,
    ) -> Predicate<RecurringPaymentOccurrence>? {
        guard let range = query?.range else {
            return nil
        }

        let start = range.startDate
        let end = range.endDate

        return #Predicate<RecurringPaymentOccurrence> { occurrence in
            occurrence.scheduledDate >= start && occurrence.scheduledDate <= end
        }
    }

    func balancePredicate(
        for query: RecurringPaymentBalanceQuery?,
    ) -> Predicate<RecurringPaymentSavingBalance>? {
        guard let identifiers = query?.definitionIds, !identifiers.isEmpty else {
            return nil
        }

        return #Predicate<RecurringPaymentSavingBalance> { balance in
            identifiers.contains(balance.definition.id)
        }
    }

    func resolvedCategory(id: UUID?, context: ModelContext) throws -> CategoryEntity? {
        guard let id else { return nil }
        guard let category = try context.fetch(CategoryQueries.byId(id)).first else {
            throw RecurringPaymentDomainError.categoryNotFound
        }
        return category
    }
}

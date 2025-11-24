import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataRecurringPaymentRepository: RecurringPaymentRepository {
    private var scheduleService: RecurringPaymentScheduleService = RecurringPaymentScheduleService()
    private var currentDateProvider: () -> Date = { Date() }

    private var currentContext: ModelContext { modelContext }

    internal func useScheduleService(_ service: RecurringPaymentScheduleService) {
        scheduleService = service
    }

    internal func useCurrentDateProvider(_ provider: @escaping @Sendable () -> Date) {
        currentDateProvider = provider
    }

    internal func configure(
        calendar: Calendar = Calendar(identifier: .gregorian),
        currentDateProvider: @escaping @Sendable () -> Date = { Date() },
    ) {
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let customRepository = SwiftDataCustomHolidayRepository(modelContainer: modelContainer, calendar: calendar)
        let customProvider = CustomHolidayProvider(repository: customRepository)
        let compositeProvider = CompositeHolidayProvider(providers: [japaneseProvider, customProvider])
        scheduleService = RecurringPaymentScheduleService(
            calendar: calendar,
            holidayProvider: compositeProvider,
        )
        self.currentDateProvider = currentDateProvider
    }

    // Convenience initializer removed to encourage ModelContainer-based usage.

    internal func definitions(filter: RecurringPaymentDefinitionFilter?) async throws -> [RecurringPaymentDefinition] {
        let context = currentContext
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

        return results.map { RecurringPaymentDefinition(from: $0) }
    }

    internal func occurrences(query: RecurringPaymentOccurrenceQuery?) async throws -> [RecurringPaymentOccurrence] {
        let context = currentContext
        let descriptor = RecurringPaymentQueries.occurrences(
            predicate: occurrencePredicate(for: query),
        )

        var results = try context.fetch(descriptor)

        if let statuses = query?.statusFilter, !statuses.isEmpty {
            results = results.filter { statuses.contains($0.status) }
        }

        if let definitionIds = query?.definitionIds, !definitionIds.isEmpty {
            results = results.filter { definitionIds.contains($0.definitionId) }
        }

        return results.map { RecurringPaymentOccurrence(from: $0) }
    }

    internal func balances(query: RecurringPaymentBalanceQuery?) async throws -> [RecurringPaymentSavingBalance] {
        let context = currentContext
        let descriptor = RecurringPaymentQueries.balances(
            predicate: balancePredicate(for: query),
        )

        return try context.fetch(descriptor).map { RecurringPaymentSavingBalance(from: $0) }
    }

    internal func categoryNames(ids: Set<UUID>) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }

        let context = currentContext
        let predicate = #Predicate<SwiftDataCategory> { category in
            ids.contains(category.id)
        }
        let descriptor = FetchDescriptor<SwiftDataCategory>(predicate: predicate)

        let categories = try context.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.fullName) })
    }

    @discardableResult
    internal func createDefinition(_ input: RecurringPaymentDefinitionInput) async throws -> UUID {
        let context = currentContext
        let category = try await resolvedCategory(id: input.categoryId, context: context)

        let definition = SwiftDataRecurringPaymentDefinition(
            name: input.name,
            notes: input.notes,
            amount: input.amount,
            recurrenceIntervalMonths: input.recurrenceIntervalMonths,
            firstOccurrenceDate: input.firstOccurrenceDate,
            endDate: input.endDate,
            category: category,
            savingStrategy: input.savingStrategy,
            customMonthlySavingAmount: input.customMonthlySavingAmount,
            dateAdjustmentPolicy: input.dateAdjustmentPolicy,
            recurrenceDayPattern: input.recurrenceDayPattern,
            matchKeywords: input.matchKeywords,
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
    ) async throws -> Bool {
        let context = currentContext
        let definition = try await findDefinition(id: definitionId, context: context)
        let category = try await resolvedCategory(id: input.categoryId, context: context)

        let errors = validateDefinition(input: input, category: category)
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        // 開始日が過去に変更されたかどうかを検出
        let oldFirstOccurrenceDate = definition.firstOccurrenceDate
        let needsBackfill = input.firstOccurrenceDate < oldFirstOccurrenceDate

        definition.name = input.name
        definition.notes = input.notes
        definition.amount = input.amount
        definition.recurrenceIntervalMonths = input.recurrenceIntervalMonths
        definition.firstOccurrenceDate = input.firstOccurrenceDate
        definition.endDate = input.endDate
        definition.category = category
        definition.savingStrategy = input.savingStrategy
        definition.customMonthlySavingAmount = input.customMonthlySavingAmount
        definition.dateAdjustmentPolicy = input.dateAdjustmentPolicy
        definition.recurrenceDayPattern = input.recurrenceDayPattern
        definition.matchKeywords = input.matchKeywords
        definition.updatedAt = currentDateProvider()

        try context.save()

        return needsBackfill
    }

    internal func deleteDefinition(definitionId: UUID) async throws {
        let context = currentContext
        let definition = try await findDefinition(id: definitionId, context: context)

        let occurrencesToDelete = try context.fetch(
            RecurringPaymentQueries.occurrences(
                predicate: #Predicate { $0.definitionId == definitionId },
            ),
        )
        if !occurrencesToDelete.isEmpty {
            occurrencesToDelete.forEach { context.delete($0) }
            try context.save()
        }

        context.delete(definition)
        try context.save()
    }

    @discardableResult
    internal func synchronize(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date? = nil,
        backfillFromFirstDate: Bool = false,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        let context = currentContext
        let definition = try await findDefinition(id: definitionId, context: context)

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
            backfillFromFirstDate: backfillFromFirstDate,
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
        if !plan.removed.isEmpty {
            plan.removed.forEach { context.delete($0) }
            try context.save()
        }

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
    ) async throws -> RecurringPaymentSynchronizationSummary {
        let context = currentContext
        let occurrence = try await findOccurrence(id: occurrenceId, context: context)
        let transactionModel = try await resolvedTransaction(from: input.transaction, context: context)
        let now = currentDateProvider()
        let updateValues = OccurrenceUpdateValues(
            status: .completed,
            actualDate: input.actualDate,
            actualAmount: input.actualAmount,
            transaction: transactionModel,
        )

        let errors = validateOccurrenceUpdate(
            occurrence: occurrence,
            values: updateValues,
        )
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        occurrence.actualDate = updateValues.actualDate
        occurrence.actualAmount = updateValues.actualAmount
        occurrence.transaction = updateValues.transaction
        occurrence.status = updateValues.status
        occurrence.updatedAt = now

        try context.save()

        return try await synchronize(
            definitionId: occurrence.definitionId,
            horizonMonths: horizonMonths,
            referenceDate: now,
            backfillFromFirstDate: false,
        )
    }

    @discardableResult
    internal func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary? {
        let context = currentContext
        let occurrence = try await findOccurrence(id: occurrenceId, context: context)
        let now = currentDateProvider()
        let wasCompleted = occurrence.status == .completed
        let transactionModel = try await resolvedTransaction(from: input.transaction, context: context)
        let updateValues = OccurrenceUpdateValues(
            status: input.status,
            actualDate: input.actualDate,
            actualAmount: input.actualAmount,
            transaction: transactionModel,
        )
        let willBeCompleted = updateValues.status == .completed

        let errors = validateOccurrenceUpdate(
            occurrence: occurrence,
            values: updateValues,
        )
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        occurrence.status = updateValues.status
        occurrence.actualDate = updateValues.actualDate
        occurrence.actualAmount = updateValues.actualAmount
        occurrence.transaction = updateValues.transaction
        occurrence.updatedAt = now

        try context.save()

        guard wasCompleted != willBeCompleted else {
            return nil
        }

        return try await synchronize(
            definitionId: occurrence.definitionId,
            horizonMonths: horizonMonths,
            referenceDate: now,
            backfillFromFirstDate: false,
        )
    }

    @discardableResult
    internal func skipOccurrence(
        occurrenceId: UUID,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary {
        let context = currentContext
        let occurrence = try await findOccurrence(id: occurrenceId, context: context)
        let now = currentDateProvider()
        let updateValues = OccurrenceUpdateValues(
            status: .skipped,
            actualDate: nil,
            actualAmount: nil,
            transaction: nil,
        )

        let errors = validateOccurrenceUpdate(
            occurrence: occurrence,
            values: updateValues,
        )
        guard errors.isEmpty else {
            throw RecurringPaymentDomainError.validationFailed(errors)
        }

        occurrence.status = updateValues.status
        occurrence.actualDate = updateValues.actualDate
        occurrence.actualAmount = updateValues.actualAmount
        occurrence.transaction = updateValues.transaction
        occurrence.updatedAt = now

        try context.save()

        return try await synchronize(
            definitionId: occurrence.definitionId,
            horizonMonths: horizonMonths,
            referenceDate: now,
            backfillFromFirstDate: false,
        )
    }

    internal func saveChanges() async throws {
        // Each repository method persists immediately; no shared context to save.
    }
}

private extension SwiftDataRecurringPaymentRepository {
    func findOccurrence(id: UUID, context: ModelContext) async throws -> SwiftDataRecurringPaymentOccurrence {
        let predicate = #Predicate<SwiftDataRecurringPaymentOccurrence> { occurrence in
            occurrence.id == id
        }
        let descriptor = RecurringPaymentQueries.occurrences(predicate: predicate)
        guard let occurrence = try context.fetch(descriptor).first else {
            throw RecurringPaymentDomainError.occurrenceNotFound
        }
        return occurrence
    }

    func findDefinition(id: UUID, context: ModelContext) async throws -> SwiftDataRecurringPaymentDefinition {
        let predicate = #Predicate<SwiftDataRecurringPaymentDefinition> { definition in
            definition.id == id
        }
        let descriptor = RecurringPaymentQueries.definitions(predicate: predicate)
        guard let definition = try context.fetch(descriptor).first else {
            throw RecurringPaymentDomainError.definitionNotFound
        }
        return definition
    }

    func findTransaction(id: UUID, context: ModelContext) async throws -> SwiftDataTransaction {
        let predicate = #Predicate<SwiftDataTransaction> { transaction in
            transaction.id == id
        }
        let descriptor = FetchDescriptor<SwiftDataTransaction>(predicate: predicate)
        guard let transaction = try context.fetch(descriptor).first else {
            throw RecurringPaymentDomainError.validationFailed(["取引が見つかりません"])
        }
        return transaction
    }

    func definitionPredicate(
        for filter: RecurringPaymentDefinitionFilter?,
    ) -> Predicate<SwiftDataRecurringPaymentDefinition>? {
        guard let identifiers = filter?.ids, !identifiers.isEmpty else {
            return nil
        }

        return #Predicate<SwiftDataRecurringPaymentDefinition> { definition in
            identifiers.contains(definition.id)
        }
    }

    func occurrencePredicate(
        for query: RecurringPaymentOccurrenceQuery?,
    ) -> Predicate<SwiftDataRecurringPaymentOccurrence>? {
        guard let range = query?.range else {
            return nil
        }

        let start = range.startDate
        let end = range.endDate

        return #Predicate<SwiftDataRecurringPaymentOccurrence> { occurrence in
            occurrence.scheduledDate >= start && occurrence.scheduledDate <= end
        }
    }

    func balancePredicate(
        for query: RecurringPaymentBalanceQuery?,
    ) -> Predicate<SwiftDataRecurringPaymentSavingBalance>? {
        guard let identifiers = query?.definitionIds, !identifiers.isEmpty else {
            return nil
        }

        return #Predicate<SwiftDataRecurringPaymentSavingBalance> { balance in
            identifiers.contains(balance.definition.id)
        }
    }

    func resolvedCategory(id: UUID?, context: ModelContext) async throws -> SwiftDataCategory? {
        guard let id else { return nil }
        guard let category = try context.fetch(CategoryQueries.byId(id)).first else {
            throw RecurringPaymentDomainError.categoryNotFound
        }
        return category
    }

    func validateDefinition(
        input: RecurringPaymentDefinitionInput,
        category: SwiftDataCategory?,
    ) -> [String] {
        let candidate = SwiftDataRecurringPaymentDefinition(
            name: input.name,
            notes: input.notes,
            amount: input.amount,
            recurrenceIntervalMonths: input.recurrenceIntervalMonths,
            firstOccurrenceDate: input.firstOccurrenceDate,
            endDate: input.endDate,
            category: category,
            savingStrategy: input.savingStrategy,
            customMonthlySavingAmount: input.customMonthlySavingAmount,
            dateAdjustmentPolicy: input.dateAdjustmentPolicy,
            recurrenceDayPattern: input.recurrenceDayPattern,
            matchKeywords: input.matchKeywords,
        )
        return candidate.validate()
    }

    func validateOccurrenceUpdate(
        occurrence: SwiftDataRecurringPaymentOccurrence,
        values: OccurrenceUpdateValues,
    ) -> [String] {
        let candidate = SwiftDataRecurringPaymentOccurrence(
            definition: occurrence.definition,
            scheduledDate: occurrence.scheduledDate,
            expectedAmount: occurrence.expectedAmount,
            status: values.status,
            actualDate: values.actualDate,
            actualAmount: values.actualAmount,
            transaction: values.transaction,
        )
        return candidate.validate()
    }

    func resolvedTransaction(
        from dto: Transaction?,
        context: ModelContext,
    ) async throws -> SwiftDataTransaction? {
        guard let dto else { return nil }
        return try await findTransaction(id: dto.id, context: context)
    }
}

private struct OccurrenceUpdateValues {
    internal let status: RecurringPaymentStatus
    internal let actualDate: Date?
    internal let actualAmount: Decimal?
    internal let transaction: SwiftDataTransaction?
}

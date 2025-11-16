import Foundation

internal struct RecurringPaymentDefinitionFilter {
    internal let ids: Set<UUID>?
    internal let searchText: String?
    internal let categoryIds: Set<UUID>?

    internal init(
        ids: Set<UUID>? = nil,
        searchText: String? = nil,
        categoryIds: Set<UUID>? = nil,
    ) {
        self.ids = ids?.isEmpty == true ? nil : ids
        if let text = searchText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.searchText = text
        } else {
            self.searchText = nil
        }
        self.categoryIds = categoryIds?.isEmpty == true ? nil : categoryIds
    }
}

internal struct RecurringPaymentOccurrenceRange {
    internal let startDate: Date
    internal let endDate: Date

    internal init(startDate: Date, endDate: Date) {
        self.startDate = min(startDate, endDate)
        self.endDate = max(startDate, endDate)
    }
}

internal struct RecurringPaymentOccurrenceQuery {
    internal let range: RecurringPaymentOccurrenceRange?
    internal let statusFilter: Set<RecurringPaymentStatus>?
    internal let definitionIds: Set<UUID>?

    internal init(
        range: RecurringPaymentOccurrenceRange? = nil,
        statusFilter: Set<RecurringPaymentStatus>? = nil,
        definitionIds: Set<UUID>? = nil,
    ) {
        self.range = range
        self.statusFilter = statusFilter?.isEmpty == true ? nil : statusFilter
        self.definitionIds = definitionIds?.isEmpty == true ? nil : definitionIds
    }
}

internal struct RecurringPaymentBalanceQuery {
    internal let definitionIds: Set<UUID>?

    internal init(definitionIds: Set<UUID>? = nil) {
        self.definitionIds = definitionIds?.isEmpty == true ? nil : definitionIds
    }
}

internal struct RecurringPaymentSynchronizationSummary {
    internal let syncedAt: Date
    internal let createdCount: Int
    internal let updatedCount: Int
    internal let removedCount: Int
}

@DatabaseActor
internal protocol RecurringPaymentRepository: Sendable {
    func definitions(filter: RecurringPaymentDefinitionFilter?) throws -> [RecurringPaymentDefinitionDTO]
    func occurrences(query: RecurringPaymentOccurrenceQuery?) throws -> [RecurringPaymentOccurrenceDTO]
    func balances(query: RecurringPaymentBalanceQuery?) throws -> [RecurringPaymentSavingBalanceDTO]

    @discardableResult
    func createDefinition(_ input: RecurringPaymentDefinitionInput) throws -> UUID
    func updateDefinition(definitionId: UUID, input: RecurringPaymentDefinitionInput) throws
    func deleteDefinition(definitionId: UUID) throws

    @discardableResult
    func synchronize(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
    ) throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) throws -> RecurringPaymentSynchronizationSummary?

    func saveChanges() throws
}

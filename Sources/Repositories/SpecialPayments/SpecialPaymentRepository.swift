import Foundation

internal struct SpecialPaymentDefinitionFilter {
    internal let ids: Set<UUID>?
    internal let searchText: String?
    internal let categoryIds: Set<UUID>?

    internal init(
        ids: Set<UUID>? = nil,
        searchText: String? = nil,
        categoryIds: Set<UUID>? = nil
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

internal struct SpecialPaymentOccurrenceRange {
    internal let startDate: Date
    internal let endDate: Date

    internal init(startDate: Date, endDate: Date) {
        self.startDate = min(startDate, endDate)
        self.endDate = max(startDate, endDate)
    }
}

internal struct SpecialPaymentOccurrenceQuery {
    internal let range: SpecialPaymentOccurrenceRange?
    internal let statusFilter: Set<SpecialPaymentStatus>?
    internal let definitionIds: Set<UUID>?

    internal init(
        range: SpecialPaymentOccurrenceRange? = nil,
        statusFilter: Set<SpecialPaymentStatus>? = nil,
        definitionIds: Set<UUID>? = nil
    ) {
        self.range = range
        self.statusFilter = statusFilter?.isEmpty == true ? nil : statusFilter
        self.definitionIds = definitionIds?.isEmpty == true ? nil : definitionIds
    }
}

internal struct SpecialPaymentBalanceQuery {
    internal let definitionIds: Set<UUID>?

    internal init(definitionIds: Set<UUID>? = nil) {
        self.definitionIds = definitionIds?.isEmpty == true ? nil : definitionIds
    }
}

internal struct SpecialPaymentSynchronizationSummary {
    internal let syncedAt: Date
    internal let createdCount: Int
    internal let updatedCount: Int
    internal let removedCount: Int
}

internal protocol SpecialPaymentRepository {
    func definitions(filter: SpecialPaymentDefinitionFilter?) throws -> [SpecialPaymentDefinition]
    func occurrences(query: SpecialPaymentOccurrenceQuery?) throws -> [SpecialPaymentOccurrence]
    func balances(query: SpecialPaymentBalanceQuery?) throws -> [SpecialPaymentSavingBalance]

    @discardableResult
    func createDefinition(_ input: SpecialPaymentDefinitionInput) throws -> SpecialPaymentDefinition
    func updateDefinition(_ definition: SpecialPaymentDefinition, input: SpecialPaymentDefinitionInput) throws
    func deleteDefinition(_ definition: SpecialPaymentDefinition) throws

    @discardableResult
    func synchronize(
        definition: SpecialPaymentDefinition,
        horizonMonths: Int,
        referenceDate: Date?
    ) throws -> SpecialPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int
    ) throws -> SpecialPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int
    ) throws -> SpecialPaymentSynchronizationSummary?

    func saveChanges() throws
}

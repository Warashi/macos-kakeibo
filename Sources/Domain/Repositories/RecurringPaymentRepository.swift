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

internal protocol RecurringPaymentRepository: Sendable {
    func definitions(filter: RecurringPaymentDefinitionFilter?) async throws -> [RecurringPaymentDefinition]
    func occurrences(query: RecurringPaymentOccurrenceQuery?) async throws -> [RecurringPaymentOccurrence]
    func balances(query: RecurringPaymentBalanceQuery?) async throws -> [RecurringPaymentSavingBalance]
    func categoryNames(ids: Set<UUID>) async throws -> [UUID: String]

    @discardableResult
    func createDefinition(_ input: RecurringPaymentDefinitionInput) async throws -> UUID

    /// 定期支払い定義を更新
    /// - Returns: 開始日が過去に変更された場合true
    func updateDefinition(definitionId: UUID, input: RecurringPaymentDefinitionInput) async throws -> Bool

    func deleteDefinition(definitionId: UUID) async throws

    @discardableResult
    func synchronize(
        definitionId: UUID,
        horizonMonths: Int,
        referenceDate: Date?,
        backfillFromFirstDate: Bool,
    ) async throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary

    @discardableResult
    func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int,
    ) async throws -> RecurringPaymentSynchronizationSummary?

    func saveChanges() async throws
}

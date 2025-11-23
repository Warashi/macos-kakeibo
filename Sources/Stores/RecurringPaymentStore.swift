import Foundation
import Observation

@Observable
internal final class RecurringPaymentStore {
    private let repository: RecurringPaymentRepository
    private let currentDateProvider: () -> Date

    internal private(set) var lastSyncedAt: Date?

    internal init(
        repository: RecurringPaymentRepository,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.repository = repository
        self.currentDateProvider = currentDateProvider
    }

    // MARK: - Public API

    internal func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int = RecurringPaymentScheduleService.defaultHorizonMonths,
        referenceDate: Date? = nil,
        backfillFromFirstDate: Bool = false,
    ) async throws {
        let summary = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
            backfillFromFirstDate: backfillFromFirstDate,
        )

        lastSyncedAt = summary.syncedAt
    }

    internal func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int = RecurringPaymentScheduleService.defaultHorizonMonths,
    ) async throws {
        let summary = try await repository.markOccurrenceCompleted(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )
        lastSyncedAt = summary.syncedAt
    }

    /// Occurrenceの実績データとステータスを更新
    /// - Parameters:
    ///   - occurrenceId: 更新対象のOccurrenceのID
    ///   - input: 更新内容
    ///   - horizonMonths: スケジュール生成期間
    internal func updateOccurrence(
        occurrenceId: UUID,
        input: OccurrenceUpdateInput,
        horizonMonths: Int = RecurringPaymentScheduleService.defaultHorizonMonths,
    ) async throws {
        let summary = try await repository.updateOccurrence(
            occurrenceId: occurrenceId,
            input: input,
            horizonMonths: horizonMonths,
        )

        if let summary {
            lastSyncedAt = summary.syncedAt
        }
    }
}

// MARK: - CRUD Operations

extension RecurringPaymentStore {
    /// 定期支払い定義を作成
    internal func createDefinition(
        _ input: RecurringPaymentDefinitionInput,
        horizonMonths: Int = RecurringPaymentScheduleService.defaultHorizonMonths,
    ) async throws {
        let definitionId = try await repository.createDefinition(input)
        let summary = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider(),
            backfillFromFirstDate: false,
        )
        lastSyncedAt = summary.syncedAt
    }

    /// 定期支払い定義を更新
    internal func updateDefinition(
        definitionId: UUID,
        input: RecurringPaymentDefinitionInput,
        horizonMonths: Int = RecurringPaymentScheduleService.defaultHorizonMonths,
    ) async throws {
        let needsBackfill = try await repository.updateDefinition(definitionId: definitionId, input: input)
        let summary = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider(),
            backfillFromFirstDate: needsBackfill,
        )
        lastSyncedAt = summary.syncedAt
    }

    /// 定期支払い定義を削除
    internal func deleteDefinition(definitionId: UUID) async throws {
        try await repository.deleteDefinition(definitionId: definitionId)
    }
}

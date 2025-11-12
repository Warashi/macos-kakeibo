import Foundation
import Observation
import SwiftData

/// 特別支払い定義の入力パラメータ
internal struct SpecialPaymentDefinitionInput {
    internal let name: String
    internal let notes: String
    internal let amount: Decimal
    internal let recurrenceIntervalMonths: Int
    internal let firstOccurrenceDate: Date
    internal let leadTimeMonths: Int
    internal let categoryId: UUID?
    internal let savingStrategy: SpecialPaymentSavingStrategy
    internal let customMonthlySavingAmount: Decimal?
    internal let dateAdjustmentPolicy: DateAdjustmentPolicy
    internal let recurrenceDayPattern: DayOfMonthPattern?

    internal init(
        name: String,
        notes: String = "",
        amount: Decimal,
        recurrenceIntervalMonths: Int,
        firstOccurrenceDate: Date,
        leadTimeMonths: Int = 0,
        categoryId: UUID? = nil,
        savingStrategy: SpecialPaymentSavingStrategy = .evenlyDistributed,
        customMonthlySavingAmount: Decimal? = nil,
        dateAdjustmentPolicy: DateAdjustmentPolicy = .none,
        recurrenceDayPattern: DayOfMonthPattern? = nil,
    ) {
        self.name = name
        self.notes = notes
        self.amount = amount
        self.recurrenceIntervalMonths = recurrenceIntervalMonths
        self.firstOccurrenceDate = firstOccurrenceDate
        self.leadTimeMonths = leadTimeMonths
        self.categoryId = categoryId
        self.savingStrategy = savingStrategy
        self.customMonthlySavingAmount = customMonthlySavingAmount
        self.dateAdjustmentPolicy = dateAdjustmentPolicy
        self.recurrenceDayPattern = recurrenceDayPattern
    }
}

/// 特別支払いOccurrence完了時の入力パラメータ
internal struct OccurrenceCompletionInput {
    internal let actualDate: Date
    internal let actualAmount: Decimal
    internal let transaction: TransactionDTO?

    internal init(
        actualDate: Date,
        actualAmount: Decimal,
        transaction: TransactionDTO? = nil,
    ) {
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transaction = transaction
    }
}

/// 特別支払いOccurrence更新時の入力パラメータ
internal struct OccurrenceUpdateInput {
    internal let status: SpecialPaymentStatus
    internal let actualDate: Date?
    internal let actualAmount: Decimal?
    internal let transaction: TransactionDTO?

    internal init(
        status: SpecialPaymentStatus,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transaction: TransactionDTO? = nil,
    ) {
        self.status = status
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transaction = transaction
    }
}

@Observable
@MainActor
internal final class SpecialPaymentStore {
    private let repository: SpecialPaymentRepository
    private let currentDateProvider: () -> Date

    internal private(set) var lastSyncedAt: Date?

    internal init(
        repository: SpecialPaymentRepository,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.repository = repository
        self.currentDateProvider = currentDateProvider
    }

    // MARK: - Public API

    internal func synchronizeOccurrences(
        definitionId: UUID,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
        referenceDate: Date? = nil,
    ) async throws {
        let summary = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate,
        )

        lastSyncedAt = summary.syncedAt
    }

    internal func markOccurrenceCompleted(
        occurrenceId: UUID,
        input: OccurrenceCompletionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
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
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
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

extension SpecialPaymentStore {
    /// 特別支払い定義を作成
    internal func createDefinition(
        _ input: SpecialPaymentDefinitionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) async throws {
        let definitionId = try await repository.createDefinition(input)
        let summary = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider(),
        )
        lastSyncedAt = summary.syncedAt
    }

    /// 特別支払い定義を更新
    internal func updateDefinition(
        definitionId: UUID,
        input: SpecialPaymentDefinitionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) async throws {
        try await repository.updateDefinition(definitionId: definitionId, input: input)
        let summary = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider(),
        )
        lastSyncedAt = summary.syncedAt
    }

    /// 特別支払い定義を削除
    internal func deleteDefinition(definitionId: UUID) async throws {
        try await repository.deleteDefinition(definitionId: definitionId)
    }
}

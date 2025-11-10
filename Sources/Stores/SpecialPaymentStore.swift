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
    internal let transaction: Transaction?

    internal init(
        actualDate: Date,
        actualAmount: Decimal,
        transaction: Transaction? = nil,
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
    internal let transaction: Transaction?

    internal init(
        status: SpecialPaymentStatus,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transaction: Transaction? = nil,
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
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.currentDateProvider = currentDateProvider
    }

    internal convenience init(
        modelContext: ModelContext,
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil,
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        let repository = SpecialPaymentRepositoryFactory.make(
            modelContext: modelContext,
            calendar: calendar,
            businessDayService: businessDayService,
            holidayProvider: holidayProvider,
            currentDateProvider: currentDateProvider
        )
        self.init(
            repository: repository,
            currentDateProvider: currentDateProvider
        )
    }

    // MARK: - Public API

    internal func synchronizeOccurrences(
        for definition: SpecialPaymentDefinition,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
        referenceDate: Date? = nil,
    ) throws {
        guard definition.recurrenceIntervalMonths > 0 else {
            throw SpecialPaymentDomainError.invalidRecurrence
        }

        guard horizonMonths >= 0 else {
            throw SpecialPaymentDomainError.invalidHorizon
        }

        let summary = try repository.synchronize(
            definition: definition,
            horizonMonths: horizonMonths,
            referenceDate: referenceDate
        )

        lastSyncedAt = summary.syncedAt
    }

    internal func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        let summary = try repository.markOccurrenceCompleted(
            occurrence,
            input: input,
            horizonMonths: horizonMonths
        )
        lastSyncedAt = summary.syncedAt
    }

    /// Occurrenceの実績データとステータスを更新
    /// - Parameters:
    ///   - occurrence: 更新対象のOccurrence
    ///   - input: 更新内容
    ///   - horizonMonths: スケジュール生成期間
    internal func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceUpdateInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        let summary = try repository.updateOccurrence(
            occurrence,
            input: input,
            horizonMonths: horizonMonths
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
    ) throws {
        let definition = try repository.createDefinition(input)
        let summary = try repository.synchronize(
            definition: definition,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider()
        )
        lastSyncedAt = summary.syncedAt
    }

    /// 特別支払い定義を更新
    internal func updateDefinition(
        _ definition: SpecialPaymentDefinition,
        input: SpecialPaymentDefinitionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        try repository.updateDefinition(definition, input: input)
        let summary = try repository.synchronize(
            definition: definition,
            horizonMonths: horizonMonths,
            referenceDate: currentDateProvider()
        )
        lastSyncedAt = summary.syncedAt
    }

    /// 特別支払い定義を削除
    internal func deleteDefinition(_ definition: SpecialPaymentDefinition) throws {
        try repository.deleteDefinition(definition)
    }
}

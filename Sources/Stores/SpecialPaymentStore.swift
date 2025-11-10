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
    private let modelContext: ModelContext
    private let scheduleService: SpecialPaymentScheduleService
    private let currentDateProvider: () -> Date

    internal private(set) var lastSyncedAt: Date?

    internal init(
        modelContext: ModelContext,
        scheduleService: SpecialPaymentScheduleService = SpecialPaymentScheduleService(),
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.modelContext = modelContext
        self.scheduleService = scheduleService
        self.currentDateProvider = currentDateProvider
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

        let now = referenceDate ?? currentDateProvider()
        let plan = scheduleService.synchronizationPlan(
            for: definition,
            referenceDate: now,
            horizonMonths: horizonMonths
        )

        guard !plan.occurrences.isEmpty else {
            return
        }

        plan.created.forEach { modelContext.insert($0) }
        plan.removed.forEach { modelContext.delete($0) }

        definition.occurrences = plan.occurrences

        definition.updatedAt = now
        lastSyncedAt = now

        try modelContext.save()
    }

    internal func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        input: OccurrenceCompletionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        occurrence.actualDate = input.actualDate
        occurrence.actualAmount = input.actualAmount
        occurrence.transaction = input.transaction
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentDomainError.validationFailed(errors)
        }

        try synchronizeOccurrences(
            for: occurrence.definition,
            horizonMonths: horizonMonths,
        )
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

        try modelContext.save()

        let shouldResync = wasCompleted != willBeCompleted
        if shouldResync {
            try synchronizeOccurrences(
                for: occurrence.definition,
                horizonMonths: horizonMonths,
                referenceDate: now,
            )
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
        let category = try resolvedCategory(categoryId: input.categoryId)

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

        modelContext.insert(definition)
        try modelContext.save()

        try synchronizeOccurrences(for: definition, horizonMonths: horizonMonths)
    }

    /// 特別支払い定義を更新
    internal func updateDefinition(
        _ definition: SpecialPaymentDefinition,
        input: SpecialPaymentDefinitionInput,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        let category = try resolvedCategory(categoryId: input.categoryId)

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

        try modelContext.save()

        try synchronizeOccurrences(for: definition, horizonMonths: horizonMonths)
    }

    /// 特別支払い定義を削除
    internal func deleteDefinition(_ definition: SpecialPaymentDefinition) throws {
        modelContext.delete(definition)
        try modelContext.save()
    }
}

// MARK: - Helpers

private extension SpecialPaymentStore {
    func resolvedCategory(categoryId: UUID?) throws -> Category? {
        guard let id = categoryId else { return nil }
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id },
        )
        descriptor.fetchLimit = 1
        guard let category = try? modelContext.fetch(descriptor).first else {
            throw SpecialPaymentDomainError.categoryNotFound
        }
        return category
    }

    // Helpers moved to SpecialPaymentScheduleService
}

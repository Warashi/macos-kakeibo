import Foundation
import Observation
import SwiftData

internal enum SpecialPaymentStoreError: Error, Equatable {
    case invalidRecurrence
    case invalidHorizon
    case validationFailed([String])
    case categoryNotFound
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
            throw SpecialPaymentStoreError.invalidRecurrence
        }

        guard horizonMonths >= 0 else {
            throw SpecialPaymentStoreError.invalidHorizon
        }

        let now = referenceDate ?? currentDateProvider()
        let seedDate = nextSeedDate(for: definition)

        let targets = scheduleService.scheduleTargets(
            for: definition,
            seedDate: seedDate,
            referenceDate: now,
            horizonMonths: horizonMonths,
        )

        guard !targets.isEmpty else {
            return
        }

        let lockedOccurrences = definition.occurrences.filter(\.isSchedulingLocked)
        var editableOccurrences = definition.occurrences.filter { !$0.isSchedulingLocked }

        var matchedOccurrences: [SpecialPaymentOccurrence] = []

        for target in targets {
            if let existingIndex = editableOccurrences.firstIndex(
                where: { calendar.isDate($0.scheduledDate, inSameDayAs: target.scheduledDate) },
            ) {
                let occurrence = editableOccurrences.remove(at: existingIndex)
                apply(
                    target: target,
                    to: occurrence,
                    referenceDate: now,
                    leadTimeMonths: definition.leadTimeMonths,
                )
                matchedOccurrences.append(occurrence)
            } else {
                let occurrence = SpecialPaymentOccurrence(
                    definition: definition,
                    scheduledDate: target.scheduledDate,
                    expectedAmount: target.expectedAmount,
                    status: scheduleService.defaultStatus(
                        for: target.scheduledDate,
                        referenceDate: now,
                        leadTimeMonths: definition.leadTimeMonths,
                    ),
                )
                occurrence.updatedAt = now
                modelContext.insert(occurrence)
                matchedOccurrences.append(occurrence)
            }
        }

        if !editableOccurrences.isEmpty {
            for occurrence in editableOccurrences {
                if let index = definition.occurrences.firstIndex(where: { $0.id == occurrence.id }) {
                    definition.occurrences.remove(at: index)
                }
                modelContext.delete(occurrence)
            }
        }

        definition.occurrences = (matchedOccurrences + lockedOccurrences)
            .sorted(by: { $0.scheduledDate < $1.scheduledDate })

        definition.updatedAt = now
        lastSyncedAt = now

        try modelContext.save()
    }

    internal func markOccurrenceCompleted(
        _ occurrence: SpecialPaymentOccurrence,
        actualDate: Date,
        actualAmount: Decimal,
        transaction: Transaction? = nil,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        occurrence.actualDate = actualDate
        occurrence.actualAmount = actualAmount
        occurrence.transaction = transaction
        occurrence.status = .completed
        occurrence.updatedAt = currentDateProvider()

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentStoreError.validationFailed(errors)
        }

        try synchronizeOccurrences(
            for: occurrence.definition,
            horizonMonths: horizonMonths,
        )
    }

    /// Occurrenceの実績データとステータスを更新
    /// - Parameters:
    ///   - occurrence: 更新対象のOccurrence
    ///   - status: 新しいステータス
    ///   - actualDate: 実績日（nilの場合はクリア）
    ///   - actualAmount: 実績金額（nilの場合はクリア）
    ///   - transaction: 紐付けるTransaction（nilの場合はクリア）
    ///   - horizonMonths: スケジュール生成期間
    internal func updateOccurrence(
        _ occurrence: SpecialPaymentOccurrence,
        status: SpecialPaymentStatus,
        actualDate: Date?,
        actualAmount: Decimal?,
        transaction: Transaction?,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        let now = currentDateProvider()
        let wasCompleted = occurrence.status == .completed
        let willBeCompleted = status == .completed

        occurrence.status = status
        occurrence.actualDate = actualDate
        occurrence.actualAmount = actualAmount
        occurrence.transaction = transaction
        occurrence.updatedAt = now

        let errors = occurrence.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentStoreError.validationFailed(errors)
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
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        let category = try resolvedCategory(categoryId: categoryId)

        let definition = SpecialPaymentDefinition(
            name: name,
            notes: notes,
            amount: amount,
            recurrenceIntervalMonths: recurrenceIntervalMonths,
            firstOccurrenceDate: firstOccurrenceDate,
            leadTimeMonths: leadTimeMonths,
            category: category,
            savingStrategy: savingStrategy,
            customMonthlySavingAmount: customMonthlySavingAmount,
            dateAdjustmentPolicy: dateAdjustmentPolicy,
            recurrenceDayPattern: recurrenceDayPattern,
        )

        let errors = definition.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentStoreError.validationFailed(errors)
        }

        modelContext.insert(definition)
        try modelContext.save()

        try synchronizeOccurrences(for: definition, horizonMonths: horizonMonths)
    }

    /// 特別支払い定義を更新
    internal func updateDefinition(
        _ definition: SpecialPaymentDefinition,
        name: String,
        notes: String,
        amount: Decimal,
        recurrenceIntervalMonths: Int,
        firstOccurrenceDate: Date,
        leadTimeMonths: Int,
        categoryId: UUID?,
        savingStrategy: SpecialPaymentSavingStrategy,
        customMonthlySavingAmount: Decimal?,
        dateAdjustmentPolicy: DateAdjustmentPolicy,
        recurrenceDayPattern: DayOfMonthPattern?,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
    ) throws {
        let category = try resolvedCategory(categoryId: categoryId)

        definition.name = name
        definition.notes = notes
        definition.amount = amount
        definition.recurrenceIntervalMonths = recurrenceIntervalMonths
        definition.firstOccurrenceDate = firstOccurrenceDate
        definition.leadTimeMonths = leadTimeMonths
        definition.category = category
        definition.savingStrategy = savingStrategy
        definition.customMonthlySavingAmount = customMonthlySavingAmount
        definition.dateAdjustmentPolicy = dateAdjustmentPolicy
        definition.recurrenceDayPattern = recurrenceDayPattern
        definition.updatedAt = currentDateProvider()

        let errors = definition.validate()
        guard errors.isEmpty else {
            throw SpecialPaymentStoreError.validationFailed(errors)
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
    var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    func resolvedCategory(categoryId: UUID?) throws -> Category? {
        guard let id = categoryId else { return nil }
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id },
        )
        descriptor.fetchLimit = 1
        guard let category = try? modelContext.fetch(descriptor).first else {
            throw SpecialPaymentStoreError.categoryNotFound
        }
        return category
    }

    func nextSeedDate(for definition: SpecialPaymentDefinition) -> Date {
        let latestCompleted = definition.occurrences
            .filter { $0.status == .completed }
            .map(\.scheduledDate)
            .max()

        guard let latestCompleted else {
            return definition.firstOccurrenceDate
        }

        return calendar.date(
            byAdding: .month,
            value: definition.recurrenceIntervalMonths,
            to: latestCompleted,
        ) ?? definition.firstOccurrenceDate
    }

    func apply(
        target: SpecialPaymentScheduleService.ScheduleTarget,
        to occurrence: SpecialPaymentOccurrence,
        referenceDate: Date,
        leadTimeMonths: Int,
    ) {
        if occurrence.expectedAmount != target.expectedAmount {
            occurrence.expectedAmount = target.expectedAmount
        }

        if !calendar.isDate(occurrence.scheduledDate, inSameDayAs: target.scheduledDate) {
            occurrence.scheduledDate = target.scheduledDate
        }

        updateStatusIfNeeded(
            for: occurrence,
            referenceDate: referenceDate,
            leadTimeMonths: leadTimeMonths,
        )
        occurrence.updatedAt = referenceDate
    }

    func updateStatusIfNeeded(
        for occurrence: SpecialPaymentOccurrence,
        referenceDate: Date,
        leadTimeMonths: Int,
    ) {
        guard !occurrence.isSchedulingLocked else {
            return
        }

        let status = scheduleService.defaultStatus(
            for: occurrence.scheduledDate,
            referenceDate: referenceDate,
            leadTimeMonths: leadTimeMonths,
        )

        if occurrence.status != status {
            occurrence.status = status
        }
    }
}

private extension SpecialPaymentOccurrence {
    var isSchedulingLocked: Bool {
        status == .completed || status == .cancelled
    }
}

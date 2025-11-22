import Foundation
import SwiftData

@Model
internal final class SwiftDataRecurringPaymentDefinition {
    internal var id: UUID
    internal var name: String
    internal var notes: String
    internal var amount: Decimal
    internal var recurrenceIntervalMonths: Int
    internal var firstOccurrenceDate: Date
    internal var endDate: Date?
    internal var category: SwiftDataCategory?
    internal var savingStrategy: RecurringPaymentSavingStrategy
    internal var customMonthlySavingAmount: Decimal?
    internal var dateAdjustmentPolicy: DateAdjustmentPolicy
    internal var recurrenceDayPattern: DayOfMonthPattern?

    @Relationship(deleteRule: .cascade, inverse: \SwiftDataRecurringPaymentOccurrence.definition)
    private var occurrencesStorage: [SwiftDataRecurringPaymentOccurrence]

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        amount: Decimal,
        recurrenceIntervalMonths: Int,
        firstOccurrenceDate: Date,
        endDate: Date? = nil,
        category: SwiftDataCategory? = nil,
        savingStrategy: RecurringPaymentSavingStrategy = .evenlyDistributed,
        customMonthlySavingAmount: Decimal? = nil,
        dateAdjustmentPolicy: DateAdjustmentPolicy = .none,
        recurrenceDayPattern: DayOfMonthPattern? = nil,
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.amount = amount
        self.recurrenceIntervalMonths = recurrenceIntervalMonths
        self.firstOccurrenceDate = firstOccurrenceDate
        self.endDate = endDate
        self.category = category
        self.savingStrategy = savingStrategy
        self.customMonthlySavingAmount = customMonthlySavingAmount
        self.dateAdjustmentPolicy = dateAdjustmentPolicy
        self.recurrenceDayPattern = recurrenceDayPattern
        self.occurrencesStorage = []

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension SwiftDataRecurringPaymentDefinition {
    /// スケジュール日付で常に昇順ソートされたOccurrence一覧
    var occurrences: [SwiftDataRecurringPaymentOccurrence] {
        get {
            occurrencesStorage.sorted { $0.scheduledDate < $1.scheduledDate }
        }
        set {
            occurrencesStorage = newValue.sorted { $0.scheduledDate < $1.scheduledDate }
        }
    }

    /// 周期を人が読める形式で返す（例: "1年6か月"）
    var recurrenceDescription: String {
        guard recurrenceIntervalMonths > 0 else { return "未設定" }
        let years = recurrenceIntervalMonths / 12
        let months = recurrenceIntervalMonths % 12

        switch (years, months) {
        case let (0, monthsOnly):
            return "\(monthsOnly)か月"
        case let (yearsOnly, 0):
            return "\(yearsOnly)年"
        default:
            return "\(years)年\(months)か月"
        }
    }

    /// 月次の積立金額（カスタムの場合は指定値、均等配分なら周期で割った値）
    var monthlySavingAmount: Decimal {
        switch savingStrategy {
        case .disabled:
            return 0
        case .evenlyDistributed:
            guard recurrenceIntervalMonths > 0 else { return 0 }
            return amount.safeDivide(Decimal(recurrenceIntervalMonths))
        case .customMonthly:
            return customMonthlySavingAmount ?? 0
        }
    }

    /// 今後の発生予定日のうち、最も近い日付
    var nextOccurrenceDate: Date {
        let now = Date()
        let upcoming = occurrences
            .map(\.scheduledDate)
            .filter { $0 >= now }
            .min()

        if let upcoming {
            return upcoming
        }

        if let earliest = occurrences.map(\.scheduledDate).min() {
            return earliest
        }

        return firstOccurrenceDate
    }
}

// MARK: - Validation

internal extension SwiftDataRecurringPaymentDefinition {
    func validate() -> [String] {
        var errors: [String] = []
        errors.append(contentsOf: validateName())
        errors.append(contentsOf: validateAmount())
        errors.append(contentsOf: validateRecurrenceInterval())
        errors.append(contentsOf: validateSavingStrategyConfiguration())
        errors.append(contentsOf: validateEndDate())
        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }

    private func validateName() -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty else { return [] }
        return ["名称を入力してください"]
    }

    private func validateAmount() -> [String] {
        guard amount > 0 else {
            return ["金額は1円以上を設定してください"]
        }
        return []
    }

    private func validateRecurrenceInterval() -> [String] {
        guard recurrenceIntervalMonths > 0 else {
            return ["周期（月数）は1以上を指定してください"]
        }
        return []
    }

    private func validateSavingStrategyConfiguration() -> [String] {
        switch savingStrategy {
        case .customMonthly:
            guard let customAmount = customMonthlySavingAmount else {
                return ["カスタム積立金額を入力してください"]
            }
            guard customAmount > 0 else {
                return ["カスタム積立金額は1以上を指定してください"]
            }
            return []
        case .disabled, .evenlyDistributed:
            guard customMonthlySavingAmount != nil else { return [] }
            return ["カスタム積立金額はカスタム積立モードでのみ使用できます"]
        }
    }

    private func validateEndDate() -> [String] {
        guard let endDate else { return [] }
        guard endDate >= firstOccurrenceDate else {
            return ["終了日は開始日以降を指定してください"]
        }
        return []
    }
}

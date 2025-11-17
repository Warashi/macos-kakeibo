import Foundation
import SwiftData

@Model
internal final class RecurringPaymentDefinitionEntity {
    internal var id: UUID
    internal var name: String
    internal var notes: String
    internal var amount: Decimal
    internal var recurrenceIntervalMonths: Int
    internal var firstOccurrenceDate: Date
    internal var endDate: Date?
    internal var leadTimeMonths: Int
    internal var category: CategoryEntity?
    internal var savingStrategy: RecurringPaymentSavingStrategy
    internal var customMonthlySavingAmount: Decimal?
    internal var dateAdjustmentPolicy: DateAdjustmentPolicy
    internal var recurrenceDayPattern: DayOfMonthPattern?

    @Relationship(deleteRule: .cascade, inverse: \RecurringPaymentOccurrenceEntity.definition)
    private var occurrencesStorage: [RecurringPaymentOccurrenceEntity]

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
        leadTimeMonths: Int = 0,
        category: CategoryEntity? = nil,
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
        self.leadTimeMonths = leadTimeMonths
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

internal extension RecurringPaymentDefinitionEntity {
    /// スケジュール日付で常に昇順ソートされたOccurrence一覧
    var occurrences: [RecurringPaymentOccurrenceEntity] {
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

internal extension RecurringPaymentDefinitionEntity {
    func validate() -> [String] {
        var errors: [String] = []
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            errors.append("名称を入力してください")
        }

        if amount <= 0 {
            errors.append("金額は1円以上を設定してください")
        }

        if recurrenceIntervalMonths <= 0 {
            errors.append("周期（月数）は1以上を指定してください")
        }

        if leadTimeMonths < 0 {
            errors.append("リードタイム（月数）は0以上を指定してください")
        }

        if savingStrategy == .customMonthly {
            if let customAmount = customMonthlySavingAmount {
                if customAmount <= 0 {
                    errors.append("カスタム積立金額は1以上を指定してください")
                }
            } else {
                errors.append("カスタム積立金額を入力してください")
            }
        }

        if savingStrategy != .customMonthly, customMonthlySavingAmount != nil {
            errors.append("カスタム積立金額はカスタム積立モードでのみ使用できます")
        }

        if let endDate {
            if endDate < firstOccurrenceDate {
                errors.append("終了日は開始日以降を指定してください")
            }
        }

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }
}

@Model
internal final class RecurringPaymentOccurrenceEntity {
    internal var id: UUID

    internal var definition: RecurringPaymentDefinitionEntity

    internal var scheduledDate: Date
    internal var expectedAmount: Decimal
    internal var status: RecurringPaymentStatus

    internal var actualDate: Date?
    internal var actualAmount: Decimal?

    @Relationship(deleteRule: .nullify)
    internal var transaction: TransactionEntity?

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        definition: RecurringPaymentDefinitionEntity,
        scheduledDate: Date,
        expectedAmount: Decimal,
        status: RecurringPaymentStatus = .planned,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transaction: TransactionEntity? = nil,
    ) {
        self.id = id
        self.definition = definition
        self.scheduledDate = scheduledDate
        self.expectedAmount = expectedAmount
        self.status = status
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transaction = transaction

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension RecurringPaymentOccurrenceEntity {
    var isCompleted: Bool {
        status == .completed
    }

    var isSchedulingLocked: Bool {
        status == .completed || status == .cancelled
    }

    var isOverdue: Bool {
        !isCompleted && scheduledDate < Date()
    }

    var remainingAmount: Decimal {
        guard let actualAmount else { return expectedAmount }
        let difference = expectedAmount.safeSubtract(actualAmount)
        return max(Decimal(0), difference)
    }
}

// MARK: - Validation

internal extension RecurringPaymentOccurrenceEntity {
    func validate() -> [String] {
        var errors: [String] = []

        if expectedAmount <= 0 {
            errors.append("予定金額は1円以上を設定してください")
        }

        if status == .completed {
            if actualAmount == nil {
                errors.append("完了状態の場合、実績金額を入力してください")
            }

            if actualDate == nil {
                errors.append("完了状態の場合、実績日を入力してください")
            }
        }

        if let actualAmount, actualAmount <= 0 {
            errors.append("実績金額は1円以上を設定してください")
        }

        if let actualDate {
            let calendar = Calendar(identifier: .gregorian)
            let daysDifference = calendar.dateComponents(
                [.day],
                from: scheduledDate,
                to: actualDate,
            ).day ?? 0

            if abs(daysDifference) > 90 {
                errors.append("実績日が予定日から90日以上ずれています（\(daysDifference)日）")
            }
        }

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }
}

import Foundation
import SwiftData

internal enum SpecialPaymentSavingStrategy: String, Codable {
    case disabled // 積立なし
    case evenlyDistributed // 周期で均等積立
    case customMonthly // 手動で月次金額を指定
}

internal enum SpecialPaymentStatus: String, Codable {
    case planned // 予定のみ
    case saving // 積立中
    case completed // 実績反映済み
    case cancelled // 中止
}

internal enum DateAdjustmentPolicy: String, Codable {
    case none // 調整なし
    case moveToPreviousBusinessDay // 前営業日に移動
    case moveToNextBusinessDay // 次営業日に移動
}

@Model
internal final class SpecialPaymentDefinition {
    internal var id: UUID
    internal var name: String
    internal var notes: String
    internal var amount: Decimal
    internal var recurrenceIntervalMonths: Int
    internal var firstOccurrenceDate: Date
    internal var leadTimeMonths: Int
    internal var category: Category?
    internal var savingStrategy: SpecialPaymentSavingStrategy
    internal var customMonthlySavingAmount: Decimal?
    internal var dateAdjustmentPolicy: DateAdjustmentPolicy

    @Relationship(deleteRule: .cascade, inverse: \SpecialPaymentOccurrence.definition)
    private var occurrencesStorage: [SpecialPaymentOccurrence]

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        amount: Decimal,
        recurrenceIntervalMonths: Int,
        firstOccurrenceDate: Date,
        leadTimeMonths: Int = 0,
        category: Category? = nil,
        savingStrategy: SpecialPaymentSavingStrategy = .evenlyDistributed,
        customMonthlySavingAmount: Decimal? = nil,
        dateAdjustmentPolicy: DateAdjustmentPolicy = .none,
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.amount = amount
        self.recurrenceIntervalMonths = recurrenceIntervalMonths
        self.firstOccurrenceDate = firstOccurrenceDate
        self.leadTimeMonths = leadTimeMonths
        self.category = category
        self.savingStrategy = savingStrategy
        self.customMonthlySavingAmount = customMonthlySavingAmount
        self.dateAdjustmentPolicy = dateAdjustmentPolicy
        self.occurrencesStorage = []

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension SpecialPaymentDefinition {
    /// スケジュール日付で常に昇順ソートされたOccurrence一覧
    var occurrences: [SpecialPaymentOccurrence] {
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
        case let (0, m):
            return "\(m)か月"
        case let (y, 0):
            return "\(y)年"
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

internal extension SpecialPaymentDefinition {
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

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }
}

@Model
internal final class SpecialPaymentOccurrence {
    internal var id: UUID

    internal var definition: SpecialPaymentDefinition

    internal var scheduledDate: Date
    internal var expectedAmount: Decimal
    internal var status: SpecialPaymentStatus

    internal var actualDate: Date?
    internal var actualAmount: Decimal?

    @Relationship(deleteRule: .nullify)
    internal var transaction: Transaction?

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        definition: SpecialPaymentDefinition,
        scheduledDate: Date,
        expectedAmount: Decimal,
        status: SpecialPaymentStatus = .planned,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transaction: Transaction? = nil,
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

internal extension SpecialPaymentOccurrence {
    var isCompleted: Bool {
        status == .completed
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

internal extension SpecialPaymentOccurrence {
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

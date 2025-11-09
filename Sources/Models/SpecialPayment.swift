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

internal enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

internal enum DayOfMonthPattern: Codable, Equatable, Hashable {
    // カレンダー日ベース
    case fixed(Int) // 固定日（例：15日）
    case endOfMonth // 月末
    case endOfMonthMinus(days: Int) // 月末前N日（例：月末3日前）
    case nthWeekday(week: Int, weekday: Weekday) // 第N週のM曜日（例：第2水曜日）
    case lastWeekday(Weekday) // 最終M曜日（例：最終金曜日）

    // 営業日ベース
    case firstBusinessDay // 最初の営業日
    case lastBusinessDay // 最終営業日
    case nthBusinessDay(Int) // N番目の営業日（例：5営業日目）
    case lastBusinessDayMinus(days: Int) // 最終営業日前N営業日
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
    internal var recurrenceDayPattern: DayOfMonthPattern?

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
        recurrenceDayPattern: DayOfMonthPattern? = nil,
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
        self.recurrenceDayPattern = recurrenceDayPattern
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

// MARK: - DayOfMonthPattern Extension

extension DayOfMonthPattern {
    /// 指定された年月でこのパターンに該当する日付を計算
    internal func date(
        in year: Int,
        month: Int,
        calendar: Calendar,
        businessDayService: BusinessDayService,
    ) -> Date? {
        switch self {
        case let .fixed(day):
            return calendar.date(from: DateComponents(year: year, month: month, day: day))

        case .endOfMonth:
            guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
                return nil
            }
            return lastDay

        case let .endOfMonthMinus(days):
            guard let endDate = DayOfMonthPattern.endOfMonth.date(
                in: year,
                month: month,
                calendar: calendar,
                businessDayService: businessDayService,
            ) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: -days, to: endDate)

        case let .nthWeekday(week, weekday):
            var components = DateComponents()
            components.year = year
            components.month = month
            components.weekday = weekday.rawValue
            components.weekdayOrdinal = week

            return calendar.date(from: components)

        case let .lastWeekday(weekday):
            guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) else {
                return nil
            }

            var current = nextMonth
            for _ in 0 ..< 7 {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else {
                    return nil
                }
                current = previous

                if calendar.component(.weekday, from: current) == weekday.rawValue {
                    return current
                }
            }
            return nil

        // 営業日ベース
        case .firstBusinessDay:
            return businessDayService.firstBusinessDay(of: year, month: month)

        case .lastBusinessDay:
            return businessDayService.lastBusinessDay(of: year, month: month)

        case let .nthBusinessDay(nth):
            return businessDayService.nthBusinessDay(nth, of: year, month: month)

        case let .lastBusinessDayMinus(days):
            return businessDayService.lastBusinessDayMinus(days: days, of: year, month: month)
        }
    }
}

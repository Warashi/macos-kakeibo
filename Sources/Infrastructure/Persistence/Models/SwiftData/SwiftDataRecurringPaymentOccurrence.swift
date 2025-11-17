import Foundation
import SwiftData

@Model
internal final class SwiftDataRecurringPaymentOccurrence {
    internal var id: UUID

    internal var definition: SwiftDataRecurringPaymentDefinition

    internal var scheduledDate: Date
    internal var expectedAmount: Decimal
    internal var status: RecurringPaymentStatus

    internal var actualDate: Date?
    internal var actualAmount: Decimal?

    @Relationship(deleteRule: .nullify)
    internal var transaction: SwiftDataTransaction?

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        definition: SwiftDataRecurringPaymentDefinition,
        scheduledDate: Date,
        expectedAmount: Decimal,
        status: RecurringPaymentStatus = .planned,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transaction: SwiftDataTransaction? = nil,
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

internal extension SwiftDataRecurringPaymentOccurrence {
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

internal extension SwiftDataRecurringPaymentOccurrence {
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

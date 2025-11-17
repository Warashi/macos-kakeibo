import Foundation

/// ドメイン層で扱う定期支払い発生レコード
internal struct RecurringPaymentOccurrence: Sendable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let scheduledDate: Date
    internal let expectedAmount: Decimal
    internal let status: RecurringPaymentStatus
    internal let actualDate: Date?
    internal let actualAmount: Decimal?
    internal let transactionId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        definitionId: UUID,
        scheduledDate: Date,
        expectedAmount: Decimal,
        status: RecurringPaymentStatus,
        actualDate: Date?,
        actualAmount: Decimal?,
        transactionId: UUID?,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.definitionId = definitionId
        self.scheduledDate = scheduledDate
        self.expectedAmount = expectedAmount
        self.status = status
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transactionId = transactionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal var isCompleted: Bool {
        status == .completed
    }

    internal var isSchedulingLocked: Bool {
        status == .completed || status == .cancelled
    }

    internal var isOverdue: Bool {
        !isCompleted && scheduledDate < Date()
    }

    internal var remainingAmount: Decimal {
        guard let actualAmount else { return expectedAmount }
        let difference = expectedAmount.safeSubtract(actualAmount)
        return max(Decimal(0), difference)
    }
}

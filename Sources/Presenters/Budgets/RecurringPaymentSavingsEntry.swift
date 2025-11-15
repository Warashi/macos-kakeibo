import Foundation

/// 定期支払い積立の表示用エントリ
internal struct RecurringPaymentSavingsEntry: Identifiable {
    internal let calculation: RecurringPaymentSavingsCalculation
    internal let progress: Double
    internal let hasAlert: Bool

    internal var id: UUID {
        calculation.definitionId
    }

    internal var name: String {
        calculation.name
    }

    internal var monthlySaving: Decimal {
        calculation.monthlySaving
    }

    internal var balance: Decimal {
        calculation.balance
    }

    internal var nextOccurrence: Date? {
        calculation.nextOccurrence
    }

    internal var progressPercentage: Double {
        progress * 100
    }
}

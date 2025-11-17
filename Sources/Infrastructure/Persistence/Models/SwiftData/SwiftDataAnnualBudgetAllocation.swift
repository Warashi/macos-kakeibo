import Foundation
import SwiftData

@Model
internal final class SwiftDataAnnualBudgetAllocation {
    internal var id: UUID
    internal var amount: Decimal
    internal var category: SwiftDataCategory
    internal var policyOverrideRawValue: String?

    internal var config: SwiftDataAnnualBudgetConfig?

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        amount: Decimal,
        category: SwiftDataCategory,
        policyOverride: AnnualBudgetPolicy? = nil,
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.policyOverrideRawValue = policyOverride?.rawValue

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    internal var policyOverride: AnnualBudgetPolicy? {
        get {
            guard let policyOverrideRawValue else { return nil }
            return AnnualBudgetPolicy(rawValue: policyOverrideRawValue)
        }
        set {
            policyOverrideRawValue = newValue?.rawValue
        }
    }
}

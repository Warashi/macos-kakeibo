import Foundation

internal struct TransactionReferenceData {
    internal let institutions: [FinancialInstitution]
    internal let categories: [Category]

    internal func institution(id: UUID?) -> FinancialInstitution? {
        guard let id else { return nil }
        return institutions.first { $0.id == id }
    }

    internal func category(id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }
}

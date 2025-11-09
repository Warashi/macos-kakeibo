import Foundation

internal extension TransactionStore {
    func matchesCategory(_ transaction: Transaction) -> Bool {
        if let minorId = selectedMinorCategoryId {
            return transaction.minorCategory?.id == minorId
        }

        guard let majorId = selectedMajorCategoryId else { return true }

        if transaction.majorCategory?.id == majorId {
            return true
        }

        return transaction.minorCategory?.parent?.id == majorId
    }
}

import Foundation

internal protocol TransactionFormUseCaseProtocol: AnyObject {
    func save(
        state: TransactionFormState,
        editingTransaction: Transaction?,
        referenceData: TransactionReferenceData,
    ) throws

    func delete(transaction: Transaction) throws
}

internal enum TransactionFormError: Error, Equatable {
    case validationFailed([String])
    case persistenceFailed(String)

    internal var messages: [String] {
        switch self {
        case let .validationFailed(errors):
            errors
        case let .persistenceFailed(message):
            ["データの更新に失敗しました: \(message)"]
        }
    }
}

internal final class DefaultTransactionFormUseCase: TransactionFormUseCaseProtocol {
    private let repository: TransactionRepository

    internal init(repository: TransactionRepository) {
        self.repository = repository
    }

    internal func save(
        state: TransactionFormState,
        editingTransaction: Transaction?,
        referenceData: TransactionReferenceData,
    ) throws {
        var errors = validate(state: state, referenceData: referenceData)

        let sanitizedAmountText = sanitize(amountText: state.amountText)
        let amountMagnitude = Decimal(string: sanitizedAmountText)?.magnitude

        if sanitizedAmountText.isEmpty {
            errors.append("金額を入力してください")
        } else if amountMagnitude == nil {
            errors.append("金額を正しく入力してください")
        }

        guard errors.isEmpty, let amountMagnitude else {
            throw TransactionFormError.validationFailed(errors)
        }

        let signedAmount = state.transactionKind == .expense ? -amountMagnitude : amountMagnitude
        let institution = referenceData.institution(id: state.financialInstitutionId)
        let majorCategory = referenceData.category(id: state.majorCategoryId)
        let minorCategory = referenceData.category(id: state.minorCategoryId)

        if let transaction = editingTransaction {
            transaction.title = state.title
            transaction.memo = state.memo
            transaction.date = state.date
            transaction.amount = signedAmount
            transaction.isIncludedInCalculation = state.isIncludedInCalculation
            transaction.isTransfer = state.isTransfer
            transaction.financialInstitution = institution
            transaction.majorCategory = majorCategory
            transaction.minorCategory = minorCategory
            transaction.updatedAt = Date()
        } else {
            let transaction = Transaction(
                date: state.date,
                title: state.title,
                amount: signedAmount,
                memo: state.memo,
                isIncludedInCalculation: state.isIncludedInCalculation,
                isTransfer: state.isTransfer,
                financialInstitution: institution,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            )
            repository.insert(transaction)
        }

        do {
            try repository.saveChanges()
        } catch {
            throw TransactionFormError.persistenceFailed(error.localizedDescription)
        }
    }

    internal func delete(transaction: Transaction) throws {
        repository.delete(transaction)
        do {
            try repository.saveChanges()
        } catch {
            throw TransactionFormError.persistenceFailed(error.localizedDescription)
        }
    }
}

private extension DefaultTransactionFormUseCase {
    func validate(state: TransactionFormState, referenceData: TransactionReferenceData) -> [String] {
        var errors: [String] = []

        if state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("内容を入力してください")
        }

        if let minorId = state.minorCategoryId {
            guard let majorId = state.majorCategoryId else {
                errors.append("中項目を選択した場合は大項目も選択してください")
                return errors
            }

            if referenceData.category(id: minorId)?.parent?.id != majorId {
                errors.append("中項目の親カテゴリが一致していません")
            }
        }

        return errors
    }

    func sanitize(amountText: String) -> String {
        let sanitized = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }
}

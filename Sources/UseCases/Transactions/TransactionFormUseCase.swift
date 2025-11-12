import Foundation

@DatabaseActor
internal protocol TransactionFormUseCaseProtocol: AnyObject, Sendable {
    func save(
        state: TransactionFormState,
        editingTransactionId: UUID?,
        referenceData: TransactionReferenceData,
    ) async throws

    func delete(transactionId: UUID) async throws
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

@DatabaseActor
internal final class DefaultTransactionFormUseCase: TransactionFormUseCaseProtocol {
    private let repository: TransactionRepository

    internal init(repository: TransactionRepository) {
        self.repository = repository
    }

    internal func save(
        state: TransactionFormState,
        editingTransactionId: UUID?,
        referenceData: TransactionReferenceData,
    ) async throws {
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

        if let transactionId = editingTransactionId {
            try await updateExistingTransaction(
                transactionId: transactionId,
                state: state,
                amount: signedAmount,
                referenceData: referenceData,
            )
        } else {
            try await createNewTransaction(
                state: state,
                amount: signedAmount,
                referenceData: referenceData,
            )
        }

        do {
            try repository.saveChanges()
        } catch {
            throw TransactionFormError.persistenceFailed(error.localizedDescription)
        }
    }

    internal func delete(transactionId: UUID) async throws {
        guard let transaction = try repository.findTransaction(id: transactionId) else {
            throw TransactionFormError.persistenceFailed("取引が見つかりません")
        }
        repository.delete(transaction)
        do {
            try repository.saveChanges()
        } catch {
            throw TransactionFormError.persistenceFailed(error.localizedDescription)
        }
    }
}

private extension DefaultTransactionFormUseCase {
    func updateExistingTransaction(
        transactionId: UUID,
        state: TransactionFormState,
        amount: Decimal,
        referenceData: TransactionReferenceData,
    ) async throws {
        guard let transaction = try repository.findTransaction(id: transactionId) else {
            throw TransactionFormError.persistenceFailed("更新対象の取引が見つかりません")
        }

        let institution: FinancialInstitution? = if let institutionId = state.financialInstitutionId {
            try repository.findInstitution(id: institutionId)
        } else {
            nil
        }

        let majorCategory: Category? = if let majorId = state.majorCategoryId {
            try repository.findCategory(id: majorId)
        } else {
            nil
        }

        let minorCategory: Category? = if let minorId = state.minorCategoryId {
            try repository.findCategory(id: minorId)
        } else {
            nil
        }

        transaction.title = state.title
        transaction.memo = state.memo
        transaction.date = state.date
        transaction.amount = amount
        transaction.isIncludedInCalculation = state.isIncludedInCalculation
        transaction.isTransfer = state.isTransfer
        transaction.financialInstitution = institution
        transaction.majorCategory = majorCategory
        transaction.minorCategory = minorCategory
        transaction.updatedAt = Date()
    }

    func createNewTransaction(
        state: TransactionFormState,
        amount: Decimal,
        referenceData: TransactionReferenceData,
    ) async throws {
        let institution: FinancialInstitution? = if let institutionId = state.financialInstitutionId {
            try repository.findInstitution(id: institutionId)
        } else {
            nil
        }

        let majorCategory: Category? = if let majorId = state.majorCategoryId {
            try repository.findCategory(id: majorId)
        } else {
            nil
        }

        let minorCategory: Category? = if let minorId = state.minorCategoryId {
            try repository.findCategory(id: minorId)
        } else {
            nil
        }

        let transaction = Transaction(
            date: state.date,
            title: state.title,
            amount: amount,
            memo: state.memo,
            isIncludedInCalculation: state.isIncludedInCalculation,
            isTransfer: state.isTransfer,
            financialInstitution: institution,
            majorCategory: majorCategory,
            minorCategory: minorCategory,
        )
        repository.insert(transaction)
    }

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

            if referenceData.category(id: minorId)?.parentId != majorId {
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

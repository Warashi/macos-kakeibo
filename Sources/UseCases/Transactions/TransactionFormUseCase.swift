import Foundation

internal protocol TransactionFormUseCaseProtocol: Sendable {
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

internal struct DefaultTransactionFormUseCase: TransactionFormUseCaseProtocol {
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
            try await repository.saveChanges()
        } catch {
            throw TransactionFormError.persistenceFailed(error.localizedDescription)
        }
    }

    internal func delete(transactionId: UUID) async throws {
        guard try await repository.findTransaction(id: transactionId) != nil else {
            throw TransactionFormError.persistenceFailed("取引が見つかりません")
        }
        try await repository.delete(id: transactionId)
        do {
            try await repository.saveChanges()
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
        guard try await repository.findTransaction(id: transactionId) != nil else {
            throw TransactionFormError.persistenceFailed("更新対象の取引が見つかりません")
        }

        let input = makeInput(
            state: state,
            amount: amount,
        )
        try await repository.update(TransactionUpdateInput(id: transactionId, input: input))
    }

    func createNewTransaction(
        state: TransactionFormState,
        amount: Decimal,
        referenceData: TransactionReferenceData,
    ) async throws {
        let input = makeInput(
            state: state,
            amount: amount,
        )
        _ = try await repository.insert(input)
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

    func makeInput(
        state: TransactionFormState,
        amount: Decimal,
    ) -> TransactionInput {
        TransactionInput(
            date: state.date,
            title: state.title,
            memo: state.memo,
            amount: amount,
            isIncludedInCalculation: state.isIncludedInCalculation,
            isTransfer: state.isTransfer,
            financialInstitutionId: state.financialInstitutionId,
            majorCategoryId: state.majorCategoryId,
            minorCategoryId: state.minorCategoryId,
            importIdentifier: nil,
        )
    }
}

import Foundation
@testable import Kakeibo
import Testing

@Suite(.serialized)
@DatabaseActor
internal struct TransactionFormUseCaseTests {
    @Test("新規取引を保存できる")
    internal func savesNewTransaction() async throws {
        let repository = await InMemoryTransactionRepository()
        let useCase = DefaultTransactionFormUseCase(repository: repository)
        var state = TransactionFormState.empty(defaultDate: sampleDate())
        state.title = "書籍"
        state.amountText = "2800"
        state.memo = "Swift本"
        state.transactionKind = .expense

        try await useCase.save(
            state: state,
            editingTransactionId: nil,
            referenceData: referenceData(),
        )

        #expect(repository.transactions.count == 1)
        #expect(repository.transactions.first?.title == "書籍")
        #expect(repository.transactions.first?.amount == -2800)
    }

    @Test("既存取引の編集内容が反映される")
    internal func updatesExistingTransaction() async throws {
        let repository = await InMemoryTransactionRepository()
        let transaction = DomainFixtures.transaction(date: sampleDate(), title: "昼食", amount: -800, memo: "Before")
        repository.transactions = [transaction]
        let useCase = DefaultTransactionFormUseCase(repository: repository)
        var state = TransactionFormState.from(transaction: transaction)
        state.title = "会食"
        state.amountText = "12,000"
        state.transactionKind = .income
        state.isIncludedInCalculation = false
        state.isTransfer = true

        try await useCase.save(
            state: state,
            editingTransactionId: transaction.id,
            referenceData: referenceData(),
        )

        let updated = try #require(repository.transactions.first)
        #expect(updated.title == "会食")
        #expect(updated.amount == 12000)
        #expect(updated.isIncludedInCalculation == false)
        #expect(updated.isTransfer == true)
    }

    @Test("バリデーション違反でエラーが返る")
    internal func throwsValidationError() async throws {
        let repository = await InMemoryTransactionRepository()
        let useCase = DefaultTransactionFormUseCase(repository: repository)
        var state = TransactionFormState.empty(defaultDate: sampleDate())
        state.amountText = ""

        await #expect(throws: TransactionFormError.validationFailed(["内容を入力してください", "金額を入力してください"])) {
            try await useCase.save(
                state: state,
                editingTransactionId: nil,
                referenceData: referenceData(),
            )
        }
    }

    @Test("削除処理でリポジトリから取引が除外される")
    internal func deletesTransaction() async throws {
        let transaction = DomainFixtures.transaction(date: sampleDate(), title: "外食", amount: -5000)
        let repository = await InMemoryTransactionRepository(transactions: [transaction])
        let useCase = DefaultTransactionFormUseCase(repository: repository)

        try await useCase.delete(transactionId: transaction.id)

        #expect(repository.transactions.isEmpty)
    }
}

private extension TransactionFormUseCaseTests {
    func sampleDate() -> Date {
        Date.from(year: 2025, month: 11) ?? Date()
    }

    func referenceData() -> TransactionReferenceData {
        let institution = DomainFixtures.financialInstitution(name: "メイン銀行")
        let major = DomainFixtures.category(name: "食費", displayOrder: 1)
        let minor = DomainFixtures.category(name: "外食", displayOrder: 1, parent: major)
        return TransactionReferenceData(
            institutions: [institution],
            categories: [major, minor],
        )
    }
}

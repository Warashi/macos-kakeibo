import SwiftData
import SwiftUI
import Testing

@testable import Kakeibo

@Suite("Transaction View Tests")
@MainActor
internal struct TransactionListViewTests {
    @Test("TransactionListView本体を初期化できる")
    internal func transactionListViewInitialization() {
        let view = TransactionListView()
        let _: any View = view
    }

    @Test("TransactionListContentViewにストアを渡して初期化できる")
    internal func transactionListContentInitialization() async throws {
        let container = try ModelContainer(
            for: Transaction.self, CategoryEntity.self, FinancialInstitutionEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let repository = await SwiftDataTransactionRepository(modelContainer: container)
        let listUseCase = await DefaultTransactionListUseCase(repository: repository)
        let formUseCase = await DefaultTransactionFormUseCase(repository: repository)
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase)

        let view = TransactionListContentView(store: store)
        let _: any View = view
    }

    @Test("TransactionFilterBarはストアを受け取って初期化できる")
    internal func transactionFilterBarInitialization() async throws {
        let container = try ModelContainer(
            for: Transaction.self, CategoryEntity.self, FinancialInstitutionEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let repository = await SwiftDataTransactionRepository(modelContainer: container)
        let listUseCase = await DefaultTransactionListUseCase(repository: repository)
        let formUseCase = await DefaultTransactionFormUseCase(repository: repository)
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase)

        let filterBar = TransactionFilterBar(store: store)
        let _: any View = filterBar
    }
}

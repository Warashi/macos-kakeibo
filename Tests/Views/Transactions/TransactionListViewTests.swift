import SwiftData
import SwiftUI
import Testing

@testable import Kakeibo

@Suite("SwiftDataTransaction View Tests")
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
            for: SwiftDataTransaction.self, SwiftDataCategory.self, SwiftDataFinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let repository = SwiftDataTransactionRepository(modelContainer: container)
        let listUseCase = DefaultTransactionListUseCase(repository: repository)
        let formUseCase = DefaultTransactionFormUseCase(repository: repository)
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, appState: AppState())

        let view = TransactionListContentView(store: store)
        let _: any View = view
    }

    @Test("TransactionFilterBarはストアを受け取って初期化できる")
    internal func transactionFilterBarInitialization() async throws {
        let container = try ModelContainer(
            for: SwiftDataTransaction.self, SwiftDataCategory.self, SwiftDataFinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let repository = SwiftDataTransactionRepository(modelContainer: container)
        let listUseCase = DefaultTransactionListUseCase(repository: repository)
        let formUseCase = DefaultTransactionFormUseCase(repository: repository)
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, appState: AppState())

        let filterBar = TransactionFilterBar(store: store)
        let _: any View = filterBar
    }
}

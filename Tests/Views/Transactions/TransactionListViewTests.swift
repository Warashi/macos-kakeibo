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
    internal func transactionListContentInitialization() throws {
        let container = try ModelContainer(
            for: Transaction.self, Category.self, FinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let context = ModelContext(container)
        let store = TransactionStore(modelContext: context)

        let view = TransactionListContentView(store: store)
        let _: any View = view
    }

    @Test("TransactionFilterBarはストアを受け取って初期化できる")
    internal func transactionFilterBarInitialization() throws {
        let container = try ModelContainer(
            for: Transaction.self, Category.self, FinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let context = ModelContext(container)
        let store = TransactionStore(modelContext: context)

        let filterBar = TransactionFilterBar(store: store)
        let _: any View = filterBar
    }
}

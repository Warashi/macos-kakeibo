@testable import Kakeibo
import SwiftData
import SwiftUI
import Testing

@Suite("RecurringPaymentReconciliationView Tests")
@MainActor
internal struct RecurringPaymentReconciliationViewTests {
    @Test("Reconciliation view can be initialized")
    internal func reconciliationViewInitialization() {
        let view = RecurringPaymentReconciliationView()
        let _: any View = view
    }

    @Test("Content view can be initialized with store")
    internal func contentViewInitialization() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        _ = ModelContext(container)
        let recurringPaymentRepository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let occurrencesService = RecurringPaymentOccurrencesServiceImpl(repository: recurringPaymentRepository)
        let store = RecurringPaymentReconciliationStore(
            repository: recurringPaymentRepository,
            transactionRepository: transactionRepository,
            occurrencesService: occurrencesService,
        )
        let view = RecurringPaymentReconciliationContent(store: store)
        let _: any View = view
    }
}

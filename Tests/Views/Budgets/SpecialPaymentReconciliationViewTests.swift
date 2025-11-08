@testable import Kakeibo
import SwiftData
import SwiftUI
import Testing

@Suite("SpecialPaymentReconciliationView Tests")
@MainActor
internal struct SpecialPaymentReconciliationViewTests {
    @Test("Reconciliation view can be initialized")
    internal func reconciliationViewInitialization() {
        let view = SpecialPaymentReconciliationView()
        let _: any View = view
    }

    @Test("Content view can be initialized with store")
    internal func contentViewInitialization() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentReconciliationStore(modelContext: context)
        let view = SpecialPaymentReconciliationContentView(store: store)
        let _: any View = view
    }
}

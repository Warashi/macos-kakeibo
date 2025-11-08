@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
@MainActor
internal struct ImportStoreTests {
    @Test("CSVドキュメントを適用すると初期状態がセットされる")
    internal func applyDocument_setsInitialState() throws {
        let context = try makeInMemoryContext()
        let store = ImportStore(modelContext: context)

        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        #expect(store.document != nil)
        #expect(store.selectedFileName == "sample.csv")
        #expect(store.columnOptions.count == 9)
        #expect(store.mapping.hasRequiredAssignments)
        #expect(store.step == .fileSelection)
    }

    @Test("ファイル選択から列マッピングへ進める")
    internal func proceedToColumnMapping() async throws {
        let context = try makeInMemoryContext()
        let store = ImportStore(modelContext: context)
        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        #expect(store.step == .fileSelection)
        await store.handleNextAction()
        #expect(store.step == .columnMapping)
    }

    @Test("列マッピングから検証ステップに進める")
    internal func generatePreviewMovesToValidation() async throws {
        let context = try makeInMemoryContext()
        let store = ImportStore(modelContext: context)
        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        await store.handleNextAction() // -> column mapping
        await store.handleNextAction() // -> validation (generate preview)

        #expect(store.step == .validation)
        #expect(store.preview != nil)
    }

    @Test("検証ステップで取り込みを実行できる")
    internal func performImportCreatesTransactions() async throws {
        let context = try makeInMemoryContext()
        let store = ImportStore(modelContext: context)
        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        await store.handleNextAction() // column mapping
        await store.handleNextAction() // validation
        await store.handleNextAction() // import

        let summary = try #require(store.summary)
        #expect(summary.importedCount == 1)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
    }

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Transaction.self, Category.self, Budget.self, AnnualBudgetConfig.self,
            FinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func sampleDocument() -> CSVDocument {
        CSVDocument(rows: [
            CSVRow(index: 0, values: [
                "日付", "内容", "金額", "メモ", "大項目", "中項目", "金融機関", "計算対象", "振替",
            ]),
            CSVRow(index: 1, values: [
                "2024/01/01", "ランチ", "-1200", "同僚と",
                "食費", "外食", "メイン口座", "1", "0",
            ]),
        ])
    }
}

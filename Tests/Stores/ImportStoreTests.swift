@testable import Kakeibo
import Testing

@Suite(.serialized)
internal struct ImportStoreTests {
    @Test("CSVドキュメントを適用すると初期状態がセットされる")
    internal func applyDocument_setsInitialState() async throws {
        let (store, _, _) = await makeStore()

        await MainActor.run {
            store.applyDocument(sampleDocument(), fileName: "sample.csv")
        }

        let hasDocument = await MainActor.run { store.document != nil }
        let selectedFileName = await MainActor.run { store.selectedFileName }
        let columnCount = await MainActor.run { store.columnOptions.count }
        let hasMapping = await MainActor.run { store.mapping.hasRequiredAssignments }
        let step = await MainActor.run { store.step }

        #expect(hasDocument)
        #expect(selectedFileName == "sample.csv")
        #expect(columnCount == 9)
        #expect(hasMapping)
        #expect(step == .fileSelection)
    }

    @Test("ファイル選択から列マッピングへ進める")
    internal func proceedToColumnMapping() async throws {
        let (store, _, _) = await makeStore()
        await MainActor.run {
            store.applyDocument(sampleDocument(), fileName: "sample.csv")
        }

        let initialStep = await MainActor.run { store.step }
        #expect(initialStep == .fileSelection)
        await store.handleNextAction()
        let nextStep = await MainActor.run { store.step }
        #expect(nextStep == .columnMapping)
    }

    @Test("列マッピングから検証ステップに進める")
    internal func generatePreviewMovesToValidation() async throws {
        let (store, _, _) = await makeStore()
        await MainActor.run {
            store.applyDocument(sampleDocument(), fileName: "sample.csv")
        }

        await store.handleNextAction() // -> column mapping
        await store.handleNextAction() // -> validation (generate preview)

        let step = await MainActor.run { store.step }
        let hasPreview = await MainActor.run { store.preview != nil }
        #expect(step == .validation)
        #expect(hasPreview)
    }

    @Test("検証ステップで取り込みを実行できる")
    internal func performImportCreatesTransactions() async throws {
        let (store, transactionRepository, _) = await makeStore()
        await MainActor.run {
            store.applyDocument(sampleDocument(), fileName: "sample.csv")
        }

        await store.handleNextAction() // column mapping
        await store.handleNextAction() // validation
        await store.handleNextAction() // import

        let summary = try #require(await MainActor.run { store.summary })
        #expect(summary.importedCount == 1)
        #expect(summary.updatedCount == 0)

        let transactions = await Task { @DatabaseActor in
            transactionRepository.transactions
        }.value
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "ランチ")
    }

    // MARK: - Helpers

    private func makeStore() async -> (
        ImportStore,
        InMemoryTransactionRepository,
        InMemoryBudgetRepository,
    ) {
        await Task { @DatabaseActor in
            let transactionRepository = InMemoryTransactionRepository()
            let budgetRepository = InMemoryBudgetRepository()
            let store = ImportStore(
                transactionRepository: transactionRepository,
                budgetRepository: budgetRepository,
            )
            return (store, transactionRepository, budgetRepository)
        }.value
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

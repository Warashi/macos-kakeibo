@testable import Kakeibo
import Testing

@Suite(.serialized)
@MainActor
internal struct ImportStoreTests {
    @Test("CSVドキュメントを適用すると初期状態がセットされる")
    internal func applyDocument_setsInitialState() async throws {
        let fixture = await makeStore()
        let store = fixture.store

        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        let hasDocument = store.document != nil
        let selectedFileName = store.selectedFileName
        let columnCount = store.columnOptions.count
        let hasMapping = store.mapping.hasRequiredAssignments
        let step = store.step

        #expect(hasDocument)
        #expect(selectedFileName == "sample.csv")
        #expect(columnCount == 9)
        #expect(hasMapping)
        #expect(step == .fileSelection)
    }

    @Test("ファイル選択から列マッピングへ進める")
    internal func proceedToColumnMapping() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        let initialStep = store.step
        #expect(initialStep == .fileSelection)
        await store.handleNextAction()
        let nextStep = store.step
        #expect(nextStep == .columnMapping)
    }

    @Test("列マッピングから検証ステップに進める")
    internal func generatePreviewMovesToValidation() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        await store.handleNextAction() // -> column mapping
        await store.handleNextAction() // -> validation (generate preview)

        let step = store.step
        let hasPreview = store.preview != nil
        #expect(step == .validation)
        #expect(hasPreview)
    }

    @Test("検証ステップで取り込みを実行できる")
    internal func performImportCreatesTransactions() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        let transactionRepository = fixture.transactionRepository
        store.applyDocument(sampleDocument(), fileName: "sample.csv")

        await store.handleNextAction() // column mapping
        await store.handleNextAction() // validation
        await store.handleNextAction() // import

        let summary = try #require(store.summary)
        #expect(summary.importedCount == 1)
        #expect(summary.updatedCount == 0)

        let transactions = try await transactionRepository.fetchAllTransactions()
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "ランチ")
    }

    @Test("取り込み完了後にステータスがリセットされる")
    internal func importProgressIsClearedAfterProcessing() async throws {
        let fixture = await makeStore()
        let store = fixture.store
        store.applyDocument(sampleDocument(rowCount: 2), fileName: "sample.csv")

        await store.handleNextAction() // column mapping
        await store.handleNextAction() // validation
        await store.handleNextAction() // import

        let status = store.statusMessage
        #expect(status == "取り込みが完了しました")

        let finalProgress = store.importProgress
        #expect(finalProgress == nil)

        let isProcessing = store.isProcessing
        #expect(isProcessing == false)
    }

    // MARK: - Helpers

    private func makeStore() async -> ImportStoreFixture {
        let transactionRepository = InMemoryTransactionRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let store = ImportStore(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )
        return ImportStoreFixture(
            store: store,
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
    }

    private func sampleDocument(rowCount: Int = 1) -> CSVDocument {
        var rows: [CSVRow] = [
            CSVRow(index: 0, values: [
                "日付", "内容", "金額", "メモ", "大項目", "中項目", "金融機関", "計算対象", "振替",
            ]),
        ]
        guard rowCount > 0 else {
            return CSVDocument(rows: rows)
        }

        rows.append(
            CSVRow(index: 1, values: [
                "2024/01/01", "ランチ", "-1200", "同僚と",
                "食費", "外食", "メイン口座", "1", "0",
            ]),
        )

        if rowCount > 1 {
            for index in 1 ..< rowCount {
                rows.append(
                    CSVRow(index: index + 1, values: [
                        "2024/01/\(String(format: "%02d", index + 1))",
                        "ランチ\(index + 1)",
                        "-\(1200 + (index * 100))",
                        "同僚と\(index + 1)",
                        "食費",
                        "外食",
                        "メイン口座",
                        "1",
                        "0",
                    ]),
                )
            }
        }

        return CSVDocument(rows: rows)
    }
}

private struct ImportStoreFixture {
    internal let store: ImportStore
    internal let transactionRepository: InMemoryTransactionRepository
    internal let budgetRepository: InMemoryBudgetRepository
}

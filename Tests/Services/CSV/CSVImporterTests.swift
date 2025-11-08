@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
@MainActor
internal struct CSVImporterTests {
    @Test("マッピング済みCSVからプレビューを生成できる")
    internal func makePreview_success() async throws {
        let context = try makeInMemoryContext()
        let importer = CSVImporter(modelContext: context)

        let document = sampleDocument()
        let config = CSVImportConfiguration(hasHeaderRow: true)
        let mapping = sampleMapping()

        let preview = try importer.makePreview(
            document: document,
            mapping: mapping,
            configuration: config
        )

        #expect(preview.totalCount == 1)
        #expect(preview.validRecords.count == 1)
        let draft = try #require(preview.validRecords.first?.draft)
        #expect(draft.title == "ランチ")
        #expect(draft.amount == -1200)
        #expect(draft.majorCategoryName == "食費")
        #expect(draft.minorCategoryName == "外食")
        #expect(draft.financialInstitutionName == "メイン口座")
        #expect(draft.isIncludedInCalculation == true)
        #expect(draft.isTransfer == false)
    }

    @Test("必須カラムの割り当てが無い場合はエラー")
    internal func makePreview_requiresMapping() async throws {
        let context = try makeInMemoryContext()
        let importer = CSVImporter(modelContext: context)

        let document = sampleDocument()
        var mapping = CSVColumnMapping()
        mapping.assign(.title, to: 1)

        await #expect(throws: CSVImporter.ImportError.self) {
            _ = try importer.makePreview(
                document: document,
                mapping: mapping,
                configuration: CSVImportConfiguration()
            )
        }
    }

    @Test("プレビュー済みデータを取り込める")
    internal func performImport_createsTransactions() async throws {
        let context = try makeInMemoryContext()
        let importer = CSVImporter(modelContext: context)

        let preview = try importer.makePreview(
            document: sampleDocument(),
            mapping: sampleMapping(),
            configuration: CSVImportConfiguration(hasHeaderRow: true)
        )

        let summary = try importer.performImport(preview: preview)
        #expect(summary.importedCount == 1)
        #expect(summary.skippedCount == 0)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "ランチ")

        let categories = try context.fetch(FetchDescriptor<Category>())
        #expect(!categories.isEmpty)
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
                "2024/01/01", "ランチ", "-1200", "社食",
                "食費", "外食", "メイン口座", "1", "0",
            ]),
        ])
    }

    private func sampleMapping() -> CSVColumnMapping {
        var mapping = CSVColumnMapping()
        mapping.assign(.date, to: 0)
        mapping.assign(.title, to: 1)
        mapping.assign(.amount, to: 2)
        mapping.assign(.memo, to: 3)
        mapping.assign(.majorCategory, to: 4)
        mapping.assign(.minorCategory, to: 5)
        mapping.assign(.financialInstitution, to: 6)
        mapping.assign(.includeInCalculation, to: 7)
        mapping.assign(.transfer, to: 8)
        return mapping
    }
}

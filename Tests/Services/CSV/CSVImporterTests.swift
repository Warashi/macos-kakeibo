import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
internal struct CSVImporterTests {
    @Test("マッピング済みCSVからプレビューを生成できる")
    internal func makePreview_success() async throws {
        let (importer, _) = try await makeImporter()

        let document = sampleDocument()
        let config = CSVImportConfiguration(hasHeaderRow: true)
        let mapping = sampleMapping()

        let preview = try await importer.makePreview(
            document: document,
            mapping: mapping,
            configuration: config,
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
        #expect(draft.identifier?.rawValue == sampleIdentifier)
    }

    @Test("必須カラムの割り当てが無い場合はエラー")
    internal func makePreview_requiresMapping() async throws {
        let (importer, _) = try await makeImporter()

        let document = sampleDocument()
        var mapping = CSVColumnMapping()
        mapping.assign(.title, to: 1)

        await #expect(throws: CSVImporter.ImportError.self) {
            _ = try await importer.makePreview(
                document: document,
                mapping: mapping,
                configuration: CSVImportConfiguration(),
            )
        }
    }

    @Test("プレビュー済みデータを取り込める")
    internal func performImport_createsTransactions() async throws {
        let (importer, container) = try await makeImporter()

        let preview = try await importer.makePreview(
            document: sampleDocument(),
            mapping: sampleMapping(),
            configuration: CSVImportConfiguration(hasHeaderRow: true),
        )

        let summary = try await importer.performImport(preview: preview)
        #expect(summary.importedCount == 1)
        #expect(summary.updatedCount == 0)
        #expect(summary.skippedCount == 0)

        let context = ModelContext(container)
        let transactions = try context.fetchAll(Transaction.self)
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "ランチ")
        #expect(transactions.first?.importIdentifier == sampleIdentifier)

        let categories = try context.fetchAll(Kakeibo.Category.self)
        #expect(!categories.isEmpty)
    }

    @Test("同じIDの行は更新される")
    internal func performImport_updatesExistingTransactions() async throws {
        let (importer, container) = try await makeImporter()
        let config = CSVImportConfiguration(hasHeaderRow: true)

        let preview = try await importer.makePreview(
            document: sampleDocument(),
            mapping: sampleMapping(),
            configuration: config,
        )
        _ = try await importer.performImport(preview: preview)

        // 2回目: 金額とタイトルを変更したCSVを同じIDで再インポート
        let updatedDocument = CSVDocument(rows: [
            sampleHeaderRow,
            CSVRow(index: 1, values: [
                sampleIdentifier,
                "2024/01/02",
                "ディナー",
                "-2500",
                "家族と",
                "食費",
                "外食",
                "メイン口座",
                "1",
                "0",
            ]),
        ])
        let secondPreview = try await importer.makePreview(
            document: updatedDocument,
            mapping: sampleMapping(),
            configuration: config,
        )
        let summary = try await importer.performImport(preview: secondPreview)

        #expect(summary.importedCount == 0)
        #expect(summary.updatedCount == 1)

        let context = ModelContext(container)
        let descriptor: ModelFetchRequest<Transaction> = ModelFetchFactory.make()
        let transactions = try context.fetch(descriptor)
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "ディナー")
        #expect(transactions.first?.amount == -2500)
        #expect(transactions.first?.importIdentifier == sampleIdentifier)
    }

    // MARK: - Helpers

    private let sampleIdentifier: String = "TX-0001"

    private var sampleHeaderRow: CSVRow {
        CSVRow(index: 0, values: [
            "ID", "日付", "内容", "金額", "メモ", "大項目", "中項目", "金融機関", "計算対象", "振替",
        ])
    }

    private func makeImporter() async throws -> (CSVImporter, ModelContainer) {
        let container = try makeInMemoryContainer()
        let transactionRepository = await SwiftDataTransactionRepository(modelContainer: container)
        let budgetRepository = await SwiftDataBudgetRepository(modelContainer: container)
        let importer = CSVImporter(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        return (importer, container)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Transaction.self, Category.self, Budget.self, AnnualBudgetConfig.self,
            FinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        return container
    }

    private func sampleDocument() -> CSVDocument {
        CSVDocument(rows: [
            sampleHeaderRow,
            CSVRow(index: 1, values: [
                sampleIdentifier,
                "2024/01/01", "ランチ", "-1200", "社食",
                "食費", "外食", "メイン口座", "1", "0",
            ]),
        ])
    }

    private func sampleMapping() -> CSVColumnMapping {
        var mapping = CSVColumnMapping()
        mapping.assign(.identifier, to: 0)
        mapping.assign(.date, to: 1)
        mapping.assign(.title, to: 2)
        mapping.assign(.amount, to: 3)
        mapping.assign(.memo, to: 4)
        mapping.assign(.majorCategory, to: 5)
        mapping.assign(.minorCategory, to: 6)
        mapping.assign(.financialInstitution, to: 7)
        mapping.assign(.includeInCalculation, to: 8)
        mapping.assign(.transfer, to: 9)
        return mapping
    }
}

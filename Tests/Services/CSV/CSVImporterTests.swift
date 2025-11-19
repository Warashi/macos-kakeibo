import Foundation
import os.lock
@testable import Kakeibo
import Testing

@Suite(.serialized)
internal struct CSVImporterTests {
    @Test("マッピング済みCSVからプレビューを生成できる")
    internal func makePreview_success() async throws {
        let fixture = await makeImporter()
        let importer = fixture.importer

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
        let fixture = await makeImporter()
        let importer = fixture.importer

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
        let fixture = await makeImporter()
        let importer = fixture.importer
        let transactionRepository = fixture.transactionRepository

        let preview = try await importer.makePreview(
            document: sampleDocument(),
            mapping: sampleMapping(),
            configuration: CSVImportConfiguration(hasHeaderRow: true),
        )

        let summary = try await importer.performImport(preview: preview)
        #expect(summary.importedCount == 1)
        #expect(summary.updatedCount == 0)
        #expect(summary.skippedCount == 0)

        let transactions = transactionRepository.transactions
        #expect(transactions.count == 1)
        let transaction = try #require(transactions.first)
        #expect(transaction.title == "ランチ")
        #expect(transaction.importIdentifier == sampleIdentifier)
        #expect(transaction.amount == -1200)
    }

    @Test("同じIDの行は更新される")
    internal func performImport_updatesExistingTransactions() async throws {
        let fixture = await makeImporter()
        let importer = fixture.importer
        let transactionRepository = fixture.transactionRepository
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

        let transactions = transactionRepository.transactions
        let stored = try #require(transactions.first)
        #expect(stored.title == "ディナー")
        #expect(stored.amount == -2500)
        #expect(stored.importIdentifier == sampleIdentifier)
    }

    @Test("進捗クロージャはMainActorに縛られない")
    internal func performImport_reportsProgressOffMainActor() async throws {
        let fixture = await makeImporter()
        let importer = fixture.importer

        let preview = try await importer.makePreview(
            document: sampleDocument(recordCount: 3),
            mapping: sampleMapping(),
            configuration: CSVImportConfiguration(hasHeaderRow: true),
        )

        let recorder = ThreadFlagRecorder()
        _ = try await importer.performImport(
            preview: preview,
            batchSize: 1,
        ) { _, _ in
            recorder.record(Thread.isMainThread)
        }

        let flags = recorder.values
        #expect(!flags.isEmpty)
        #expect(flags.allSatisfy { $0 == false })
    }

    // MARK: - Helpers

    private let sampleIdentifier: String = "TX-0001"

    private var sampleHeaderRow: CSVRow {
        CSVRow(index: 0, values: [
            "ID", "日付", "内容", "金額", "メモ", "大項目", "中項目", "金融機関", "計算対象", "振替",
        ])
    }

    private func makeImporter() async -> CSVImporterFixture {
        let transactionRepository = InMemoryTransactionRepository()
        let budgetRepository = InMemoryBudgetRepository()
        let importer = CSVImporter(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )
        return CSVImporterFixture(
            importer: importer,
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )
    }

    private func sampleDocument(recordCount: Int = 1) -> CSVDocument {
        var rows: [CSVRow] = [sampleHeaderRow]
        for index in 0 ..< recordCount {
            let identifier: String = if index == 0 {
                sampleIdentifier
            } else {
                String(format: "TX-%04d", index + 1)
            }
            rows.append(
                CSVRow(index: index + 1, values: [
                    identifier,
                    "2024/01/\(String(format: "%02d", index + 1))",
                    index.isMultiple(of: 2) ? "ランチ" : "ディナー",
                    "-\(1200 + (index * 100))",
                    "サンプル\(index)",
                    "食費",
                    "外食",
                    "メイン口座",
                    "1",
                    "0",
                ]),
            )
        }
        return CSVDocument(rows: rows)
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

    private struct ThreadFlagRecorder: Sendable {
        private let lock: OSAllocatedUnfairLock<[Bool]> = OSAllocatedUnfairLock(initialState: [])

        func record(_ value: Bool) {
            lock.withLock { storage in
                storage.append(value)
            }
        }

        var values: [Bool] {
            lock.withLock { $0 }
        }
    }
}

private struct CSVImporterFixture {
    internal let importer: CSVImporter
    internal let transactionRepository: InMemoryTransactionRepository
    internal let budgetRepository: InMemoryBudgetRepository
}

import Foundation
@testable import Kakeibo
import Testing

@Suite("CSVExporter")
internal struct CSVExporterTests {
    @Test("取引をCSVに変換できる")
    internal func exportTransactions_containsHeaderAndRow() throws {
        // Given
        let major = CategoryEntity(name: "食費")
        let minor = CategoryEntity(name: "外食", parent: major)
        let institution = FinancialInstitution(name: "テスト銀行")
        let transaction = Transaction(
            date: Date(timeIntervalSince1970: 0),
            title: "テスト,取引",
            amount: -1200,
            memo: "\"引用\"付きメモ",
            financialInstitution: institution,
            majorCategory: major,
            minorCategory: minor,
        )
        let snapshot = TransactionCSVExportSnapshot(
            transactions: [TransactionDTO(from: transaction)],
            categories: [Category(from: major), Category(from: minor)],
            institutions: [FinancialInstitution(from: institution)]
        )

        // When
        let exporter = CSVExporter()
        let result = try exporter.exportTransactions(snapshot)
        let csv = result.string

        // Then
        #expect(result.rowCount == 1)
        #expect(result.header.contains("title"))
        #expect(csv.contains("\"テスト,取引\""))
        #expect(csv.contains("\"\"\"引用\"\"付きメモ\""))
        #expect(csv.contains("\"食費\""))
        #expect(csv.contains("\"外食\""))
        #expect(csv.contains("\"食費 / 外食\""))
    }

    @Test("取引が空の場合でもヘッダーを出力する")
    internal func exportTransactions_empty() throws {
        // Given
        let exporter = CSVExporter()
        let snapshot = TransactionCSVExportSnapshot(
            transactions: [],
            categories: [],
            institutions: []
        )

        // When
        let result = try exporter.exportTransactions(snapshot)
        let csv = result.string

        // Then
        #expect(result.rowCount == 0)
        #expect(csv.split(separator: "\n").count == 1)
        #expect(csv.contains("id,date,title"))
    }

    @Test("定期支払い一覧エントリをCSVに変換できる")
    internal func exportRecurringPaymentListEntries_containsHeaderAndRow() throws {
        // Given
        let entry = RecurringPaymentListEntry(
            id: UUID(),
            definitionId: UUID(),
            name: "自動車税",
            categoryId: UUID(),
            categoryName: "税金",
            scheduledDate: Date(timeIntervalSince1970: 0),
            expectedAmount: 45000,
            actualAmount: 45000,
            status: .completed,
            savingsBalance: 45000,
            savingsProgress: 1.0,
            daysUntilDue: 0,
            transactionId: UUID(),
            hasDiscrepancy: false,
        )

        // When
        let exporter = CSVExporter()
        let result = try exporter.exportRecurringPaymentListEntries([entry])
        let csv = result.string

        // Then
        #expect(result.rowCount == 1)
        #expect(result.header.contains("名称"))
        #expect(result.header.contains("カテゴリ"))
        #expect(result.header.contains("予定日"))
        #expect(csv.contains("\"自動車税\""))
        #expect(csv.contains("\"税金\""))
        #expect(csv.contains("45000"))
        #expect(csv.contains("100.00"))
        #expect(csv.contains("\"完了\""))
    }

    @Test("定期支払い一覧エントリが空の場合でもヘッダーを出力する")
    internal func exportRecurringPaymentListEntries_empty() throws {
        // Given
        let exporter = CSVExporter()

        // When
        let result = try exporter.exportRecurringPaymentListEntries([])
        let csv = result.string

        // Then
        #expect(result.rowCount == 0)
        #expect(csv.split(separator: "\n").count == 1)
        #expect(csv.contains("名称"))
        #expect(csv.contains("カテゴリ"))
    }
}

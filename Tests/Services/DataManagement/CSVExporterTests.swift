import Foundation
@testable import Kakeibo
import Testing

@Suite("CSVExporter")
internal struct CSVExporterTests {
    @Test("取引をCSVに変換できる")
    internal func exportTransactions_containsHeaderAndRow() throws {
        // Given
        let major = Category(name: "食費")
        let minor = Category(name: "外食", parent: major)
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

        // When
        let exporter = CSVExporter()
        let result = try exporter.exportTransactions([transaction])
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

        // When
        let result = try exporter.exportTransactions([])
        let csv = result.string

        // Then
        #expect(result.rowCount == 0)
        #expect(csv.split(separator: "\n").count == 1)
        #expect(csv.contains("id,date,title"))
    }
}

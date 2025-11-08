@testable import Kakeibo
import Testing

@Suite("CSVParser Tests")
internal struct CSVParserTests {
    private let parser = CSVParser()

    @Test("基本的なCSVを解析できる")
    internal func parseSimpleCSV() throws {
        let csv = """
        日付,内容,金額
        2024/01/01,ランチ,-1200
        2024/01/02,給与,300000
        """

        let document = try parser.parse(string: csv)
        #expect(document.rows.count == 3)
        #expect(document.rows.first?.values == ["日付", "内容", "金額"])
        #expect(document.rows[1].values == ["2024/01/01", "ランチ", "-1200"])
    }

    @Test("ダブルクオートと改行を含む値を解析できる")
    internal func parseQuotedValues() throws {
        let csv = "日付,内容,メモ\r\n2024/01/03,\"\"\"書籍\"\"購入\",\"複数行\\nメモ\""
        let document = try parser.parse(string: csv)

        #expect(document.rows.count == 2)
        #expect(document.rows[1].values[1] == "\"書籍\"購入")
        #expect(document.rows[1].values[2] == "複数行\nメモ")
    }

    @Test("クオートが閉じられていない場合はエラー")
    internal func detectUnterminatedQuote() {
        let csv = "日付,内容\n2024/01/01,\"ランチ"
        #expect(throws: Error.self) {
            _ = try parser.parse(string: csv)
        }
    }
}

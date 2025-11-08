import Foundation
import TabularData

/// CSV文字列を解析して構造化データに変換するパーサ
internal struct CSVParser {
    internal enum ParseError: Error, LocalizedError {
        case invalidStringEncoding

        internal var errorDescription: String? {
            switch self {
            case .invalidStringEncoding:
                return "CSVファイルを指定の文字コードで読み込めませんでした。"
            }
        }
    }

    /// Dataを受け取ってCSVを解析
    /// - Parameters:
    ///   - data: CSVデータ
    ///   - configuration: 解析設定
    /// - Returns: CSVドキュメント
    internal func parse(
        data: Data,
        configuration: CSVImportConfiguration = .init()
    ) throws -> CSVDocument {
        guard let string = String(data: data, encoding: configuration.encoding) else {
            throw ParseError.invalidStringEncoding
        }
        return try parse(string: string, configuration: configuration)
    }

    /// 文字列を解析してCSVドキュメントを生成
    /// - Parameters:
    ///   - string: CSV文字列
    ///   - configuration: 解析設定
    /// - Returns: CSVドキュメント
    internal func parse(
        string: String,
        configuration: CSVImportConfiguration = .init()
    ) throws -> CSVDocument {
        guard let normalizedData = string.data(using: .utf8) else {
            throw ParseError.invalidStringEncoding
        }
        return try parseNormalizedData(
            normalizedData,
            delimiter: configuration.delimiter
        )
    }

    private func parseNormalizedData(
        _ data: Data,
        delimiter: Character
    ) throws -> CSVDocument {
        let options = CSVReadingOptions(
            hasHeaderRow: false,
            delimiter: delimiter
        )
        let dataFrame = try DataFrame(csvData: data, options: options)
        let rows = buildRows(from: dataFrame)
        return CSVDocument(rows: rows)
    }

    private func buildRows(from dataFrame: DataFrame) -> [CSVRow] {
        let columns = dataFrame.columns
        guard !columns.isEmpty else { return [] }

        var rows: [CSVRow] = []
        rows.reserveCapacity(dataFrame.rows.count)

        for rowIndex in 0 ..< dataFrame.rows.count {
            let row = dataFrame.rows[rowIndex]
            var values: [String] = []
            values.reserveCapacity(columns.count)

            for column in columns {
                values.append(stringValue(from: row[column.name]))
            }

            rows.append(CSVRow(index: rowIndex, values: values))
        }

        return rows
    }

    private func stringValue(from value: Any?) -> String {
        guard let value else { return "" }

        if let string = value as? String {
            return string
        }

        if let convertible = value as? CustomStringConvertible {
            return convertible.description
        }

        return String(describing: value)
    }
}

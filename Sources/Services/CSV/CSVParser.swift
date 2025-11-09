import Foundation
import TabularData

/// CSV文字列を解析して構造化データに変換するパーサ
internal struct CSVParser {
    internal enum ParseError: Error, LocalizedError {
        case invalidStringEncoding

        internal var errorDescription: String? {
            switch self {
            case .invalidStringEncoding:
                "CSVファイルを指定の文字コードで読み込めませんでした。"
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
        configuration: CSVImportConfiguration = .init(),
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
        configuration: CSVImportConfiguration = .init(),
    ) throws -> CSVDocument {
        guard let normalizedData = string.data(using: .utf8) else {
            throw ParseError.invalidStringEncoding
        }
        return try parseNormalizedData(
            normalizedData,
            delimiter: configuration.delimiter,
        )
    }

    private func parseNormalizedData(
        _ data: Data,
        delimiter: Character,
    ) throws -> CSVDocument {
        let options = CSVReadingOptions(
            hasHeaderRow: false,
            delimiter: delimiter,
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
            return unescaped(string)
        }

        if let convertible = value as? CustomStringConvertible {
            return convertible.description
        }

        return unescaped(String(describing: value))
    }

    private func unescaped(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)

        var iterator = string.makeIterator()
        var buffer: Character?

        func appendBufferedBackslashIfNeeded() {
            if let backslash = buffer {
                result.append(backslash)
                buffer = nil
            }
        }

        while let character = iterator.next() {
            if buffer == "\\" {
                appendEscapedCharacter(character, to: &result)
                buffer = nil
            } else if character == "\\" {
                buffer = character
            } else {
                result.append(character)
            }
        }

        appendBufferedBackslashIfNeeded()
        return result
    }

    private func appendEscapedCharacter(_ character: Character, to result: inout String) {
        switch character {
        case "n":
            result.append("\n")
        case "r":
            result.append("\r")
        case "t":
            result.append("\t")
        case "\"":
            result.append("\"")
        case "\\":
            result.append("\\")
        default:
            result.append("\\")
            result.append(character)
        }
    }
}

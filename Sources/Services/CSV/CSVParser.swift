import Foundation

/// CSV文字列を解析して構造化データに変換するパーサ
internal struct CSVParser {
    internal enum ParseError: Error, LocalizedError {
        case invalidData
        case unterminatedQuotedField(line: Int)

        internal var errorDescription: String? {
            switch self {
            case .invalidData:
                return "CSVファイルを指定の文字コードで読み込めませんでした。"
            case .unterminatedQuotedField(let line):
                return "行\(line)のダブルクオートが正しく閉じられていません。"
            }
        }
    }

    /// Dataを受け取ってCSVを解析
    /// - Parameters:
    ///   - data: CSVデータ
    ///   - encoding: 文字コード
    ///   - delimiter: 区切り文字
    /// - Returns: CSVドキュメント
    internal func parse(
        data: Data,
        encoding: String.Encoding = AppConstants.CSV.encoding,
        delimiter: Character = AppConstants.CSV.delimiter.first ?? ","
    ) throws -> CSVDocument {
        guard let string = String(data: data, encoding: encoding) else {
            throw ParseError.invalidData
        }
        return try parse(string: string, delimiter: delimiter)
    }

    /// 文字列を解析してCSVドキュメントを生成
    /// - Parameters:
    ///   - string: CSV文字列
    ///   - delimiter: 区切り文字
    /// - Returns: CSVドキュメント
    internal func parse(
        string: String,
        delimiter: Character = AppConstants.CSV.delimiter.first ?? ","
    ) throws -> CSVDocument {
        var rows: [CSVRow] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var index = string.startIndex

        func appendField() {
            currentRow.append(currentField)
            currentField.removeAll(keepingCapacity: true)
        }

        func appendRowIfNeeded() {
            guard !currentRow.isEmpty else { return }
            rows.append(CSVRow(index: rows.count, values: currentRow))
            currentRow.removeAll(keepingCapacity: true)
        }

        while index < string.endIndex {
            let character = string[index]

            if inQuotes {
                if character == "\"" {
                    let next = string.index(after: index)
                    if next < string.endIndex, string[next] == "\"" {
                        currentField.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else {
                if character == "\"" {
                    inQuotes = true
                } else if character == delimiter {
                    appendField()
                } else if character == "\n" {
                    appendField()
                    appendRowIfNeeded()
                } else if character == "\r" {
                    let next = string.index(after: index)
                    if next < string.endIndex, string[next] == "\n" {
                        index = next
                    }
                    appendField()
                    appendRowIfNeeded()
                } else {
                    currentField.append(character)
                }
            }

            index = string.index(after: index)
        }

        if inQuotes {
            throw ParseError.unterminatedQuotedField(line: rows.count + 1)
        }

        // 最終行を追加（末尾に改行がない場合）
        if !currentField.isEmpty || !currentRow.isEmpty {
            appendField()
            appendRowIfNeeded()
        }

        return CSVDocument(rows: rows)
    }
}

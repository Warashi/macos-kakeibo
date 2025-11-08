import Foundation

/// CSVエクスポート時のエラー
internal enum CSVExporterError: LocalizedError {
    case encodingFailed

    internal var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "CSVの文字列をデータに変換できませんでした。"
        }
    }
}

/// CSVエクスポート結果
internal struct CSVExportResult: Sendable {
    /// 生成されたCSVデータ
    internal let data: Data

    /// エクスポートした行数（ヘッダー除く）
    internal let rowCount: Int

    /// CSVのヘッダー
    internal let header: [String]

    /// CSV文字列
    internal var string: String {
        String(data: data, encoding: AppConstants.CSV.encoding) ?? ""
    }
}

/// 取引データをCSVにエクスポートするユーティリティ
internal struct CSVExporter: Sendable {
    private let delimiter: String = AppConstants.CSV.delimiter
    private let newline: String = AppConstants.CSV.newline

    /// 取引データをCSVに変換する
    /// - Parameter transactions: エクスポート対象の取引
    /// - Returns: CSVデータと行数
    internal func exportTransactions(_ transactions: [Transaction]) throws -> CSVExportResult {
        let header = [
            "id",
            "date",
            "title",
            "amount",
            "memo",
            "isIncludedInCalculation",
            "isTransfer",
            "financialInstitution",
            "majorCategory",
            "minorCategory",
            "categoryPath",
        ]

        var rows: [String] = [header.joined(separator: delimiter)]
        rows.reserveCapacity(transactions.count + 1)

        for transaction in transactions {
            rows.append(row(from: transaction))
        }

        let csvString = rows.joined(separator: newline)

        guard let data = csvString.data(using: AppConstants.CSV.encoding) else {
            throw CSVExporterError.encodingFailed
        }

        return CSVExportResult(
            data: data,
            rowCount: transactions.count,
            header: header,
        )
    }

    // MARK: - Private Helpers

    /// 取引から1行のCSV文字列を生成
    /// - Parameter transaction: 取引
    /// - Returns: CSV文字列
    private func row(from transaction: Transaction) -> String {
        [
            transaction.id.uuidString,
            formattedDate(transaction.date),
            quote(transaction.title),
            string(from: transaction.amount),
            quote(transaction.memo),
            transaction.isIncludedInCalculation.description,
            transaction.isTransfer.description,
            quote(transaction.financialInstitution?.name ?? ""),
            quote(transaction.majorCategory?.name ?? ""),
            quote(transaction.minorCategory?.name ?? ""),
            quote(transaction.categoryFullName),
        ].joined(separator: delimiter)
    }

    /// 日付を文字列に整形
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Foundation.Locale(identifier: "ja_JP_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Decimalを文字列に変換
    private func string(from decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }

    /// CSV用にクオート（常にダブルクオートで囲む）
    private func quote(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

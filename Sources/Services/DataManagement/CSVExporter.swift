import Foundation

/// CSVエクスポート時のエラー
internal enum CSVExporterError: LocalizedError {
    case encodingFailed

    internal var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "CSVの文字列をデータに変換できませんでした。"
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

    /// 定期支払い一覧エントリをCSVに変換する
    /// - Parameter entries: エクスポート対象のエントリ
    /// - Returns: CSVデータと行数
    internal func exportRecurringPaymentListEntries(_ entries: [RecurringPaymentListEntry]) throws
    -> CSVExportResult {
        let header = [
            "id",
            "definitionId",
            "名称",
            "カテゴリ",
            "予定日",
            "予定額",
            "実績額",
            "積立残高",
            "進捗率",
            "残日数",
            "ステータス",
            "紐付けTransaction ID",
            "差異",
        ]

        var rows: [String] = [header.joined(separator: delimiter)]
        rows.reserveCapacity(entries.count + 1)

        for entry in entries {
            rows.append(row(from: entry))
        }

        let csvString = rows.joined(separator: newline)

        guard let data = csvString.data(using: AppConstants.CSV.encoding) else {
            throw CSVExporterError.encodingFailed
        }

        return CSVExportResult(
            data: data,
            rowCount: entries.count,
            header: header,
        )
    }

    /// RecurringPaymentListEntryから1行のCSV文字列を生成
    /// - Parameter entry: 定期支払い一覧エントリ
    /// - Returns: CSV文字列
    private func row(from entry: RecurringPaymentListEntry) -> String {
        [
            entry.id.uuidString,
            entry.definitionId.uuidString,
            quote(entry.name),
            quote(entry.categoryName ?? ""),
            formattedDate(entry.scheduledDate),
            string(from: entry.expectedAmount),
            entry.actualAmount.map { string(from: $0) } ?? "",
            string(from: entry.savingsBalance),
            String(format: "%.2f", entry.savingsProgress * 100),
            String(entry.daysUntilDue),
            quote(statusLabel(entry.status)),
            entry.transactionId?.uuidString ?? "",
            entry.discrepancyAmount.map { string(from: $0) } ?? "",
        ].joined(separator: delimiter)
    }

    /// ステータスのラベルを取得
    private func statusLabel(_ status: RecurringPaymentStatus) -> String {
        switch status {
        case .planned:
            "予定のみ"
        case .saving:
            "積立中"
        case .completed:
            "完了"
        case .cancelled:
            "中止"
        }
    }
}

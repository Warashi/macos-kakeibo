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
    internal func exportTransactions(_ snapshot: TransactionCSVExportSnapshot) throws -> CSVExportResult {
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
        rows.reserveCapacity(snapshot.transactions.count + 1)

        let referenceData = snapshot.referenceData
        for transaction in snapshot.transactions {
            rows.append(row(from: transaction, referenceData: referenceData))
        }

        let csvString = rows.joined(separator: newline)

        guard let data = csvString.data(using: AppConstants.CSV.encoding) else {
            throw CSVExporterError.encodingFailed
        }

        return CSVExportResult(
            data: data,
            rowCount: snapshot.transactions.count,
            header: header,
        )
    }

    // MARK: - Private Helpers

    /// 取引から1行のCSV文字列を生成
    /// - Parameter transaction: 取引
    /// - Returns: CSV文字列
    private func row(
        from transaction: Transaction,
        referenceData: TransactionReferenceData,
    ) -> String {
        let institutionName = referenceData.institution(id: transaction.financialInstitutionId)?.name ?? ""
        let majorName = referenceData.category(id: transaction.majorCategoryId)?.name ?? ""
        let minor = referenceData.category(id: transaction.minorCategoryId)
        let minorName = minor?.name ?? ""
        return [
            transaction.id.uuidString,
            formattedDate(transaction.date),
            quote(transaction.title),
            string(from: transaction.amount),
            quote(transaction.memo),
            transaction.isIncludedInCalculation.description,
            transaction.isTransfer.description,
            quote(institutionName),
            quote(majorName),
            quote(minorName),
            quote(categoryPath(for: transaction, minor: minor, referenceData: referenceData)),
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

    private func categoryPath(
        for transaction: Transaction,
        minor: Category?,
        referenceData: TransactionReferenceData,
    ) -> String {
        if let minor {
            if let parentId = minor.parentId,
               let parent = referenceData.category(id: parentId) {
                return "\(parent.name) / \(minor.name)"
            }
            if let major = referenceData.category(id: transaction.majorCategoryId) {
                return "\(major.name) / \(minor.name)"
            }
            return minor.name
        }

        if let major = referenceData.category(id: transaction.majorCategoryId) {
            return major.name
        }

        return ""
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
        case .skipped:
            "スキップ"
        }
    }
}

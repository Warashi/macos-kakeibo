import Foundation

// MARK: - 基本モデル

/// CSVの1行を表現するモデル
internal struct CSVRow: Identifiable, Sendable {
    internal let index: Int
    internal let values: [String]

    internal var id: Int { index }

    /// 表示用の行番号（1始まり）
    internal var lineNumber: Int { index + 1 }

    internal init(index: Int, values: [String]) {
        self.index = index
        self.values = values
    }

    /// 指定したカラムの値を取得（範囲外の場合は空文字列）
    internal func value(at columnIndex: Int) -> String {
        guard columnIndex >= 0, columnIndex < values.count else {
            return ""
        }
        return values[columnIndex]
    }
}

/// CSV全体を表現するモデル
internal struct CSVDocument: Sendable {
    internal let rows: [CSVRow]

    internal var isEmpty: Bool { rows.isEmpty }

    /// 最大カラム数
    internal var maxColumnCount: Int {
        rows.map(\.values.count).max() ?? 0
    }

    /// データ行（ヘッダー行を含めるかどうかを指定）
    /// - Parameter skipHeader: trueの場合、1行目をヘッダーとして除外
    /// - Returns: データ行
    internal func dataRows(skipHeader: Bool) -> [CSVRow] {
        guard skipHeader else { return rows }
        return Array(rows.dropFirst())
    }
}

/// ピッカー表示用のカラム候補
internal struct CSVColumnOption: Identifiable, Hashable, Sendable {
    internal let id: Int
    internal let title: String
}

// MARK: - 設定

/// CSVインポート設定
internal struct CSVImportConfiguration: Sendable, Equatable {
    internal var hasHeaderRow: Bool
    internal var delimiter: Character
    internal var encoding: String.Encoding

    internal init(
        hasHeaderRow: Bool = true,
        delimiter: Character = AppConstants.CSV.delimiter.first ?? ",",
        encoding: String.Encoding = AppConstants.CSV.encoding
    ) {
        self.hasHeaderRow = hasHeaderRow
        self.delimiter = delimiter
        self.encoding = encoding
    }
}

// MARK: - カラム定義

/// CSVカラムとアプリ項目の対応
internal enum CSVColumn: String, CaseIterable, Identifiable {
    case date
    case title
    case amount
    case memo
    case financialInstitution
    case majorCategory
    case minorCategory
    case includeInCalculation
    case transfer

    internal var id: Self { self }

    /// 表示名
    internal var displayName: String {
        switch self {
        case .date:
            "日付"
        case .title:
            "内容"
        case .amount:
            "金額"
        case .memo:
            "メモ"
        case .financialInstitution:
            "金融機関"
        case .majorCategory:
            "大項目"
        case .minorCategory:
            "中項目"
        case .includeInCalculation:
            "計算対象"
        case .transfer:
            "振替"
        }
    }

    /// 説明
    internal var helpText: String {
        switch self {
        case .date:
            "取引の日付（yyyy/MM/dd など）"
        case .title:
            "取引内容やメモのタイトル"
        case .amount:
            "支出はマイナス、収入はプラスで入力します"
        case .memo:
            "補足情報（任意）"
        case .financialInstitution:
            "口座・カードなどの金融機関名（任意）"
        case .majorCategory:
            "分類の大項目（任意）"
        case .minorCategory:
            "分類の中項目（任意）"
        case .includeInCalculation:
            "集計対象フラグ（1/0, true/false など）"
        case .transfer:
            "振替フラグ（1/0, true/false など）"
        }
    }

    /// 必須カラムかどうか
    internal var isRequired: Bool {
        switch self {
        case .date, .title, .amount:
            true
        default:
            false
        }
    }
}

/// カラムマッピング
internal struct CSVColumnMapping: Sendable, Equatable {
    private var assignments: [CSVColumn: Int]

    internal init(assignments: [CSVColumn: Int] = [:]) {
        self.assignments = assignments
    }

    /// カラムに列番号を割り当てる
    internal mutating func assign(_ column: CSVColumn, to columnIndex: Int?) {
        if let columnIndex {
            assignments[column] = columnIndex
        } else {
            assignments.removeValue(forKey: column)
        }
    }

    /// カラムに割り当てられた列番号を取得
    internal func index(for column: CSVColumn) -> Int? {
        assignments[column]
    }

    /// 指定した行から値を取得
    internal func value(for column: CSVColumn, in row: CSVRow) -> String? {
        guard let columnIndex = index(for: column) else { return nil }
        return row.value(at: columnIndex)
    }

    /// 必須カラムがすべて割り当て済みかどうか
    internal var hasRequiredAssignments: Bool {
        CSVColumn.allCases
            .filter(\.isRequired)
            .allSatisfy { assignments[$0] != nil }
    }

    /// 自動マッピング
    /// - Parameter options: CSV側のカラム候補
    /// - Returns: 推測されたマッピング
    internal static func automatic(for options: [CSVColumnOption]) -> CSVColumnMapping {
        var mapping = CSVColumnMapping()
        var usedColumns: Set<Int> = []

        for column in CSVColumn.allCases {
            guard let option = options.first(where: { option in
                !usedColumns.contains(option.id) && column.matches(option.title)
            }) else {
                continue
            }

            mapping.assign(column, to: option.id)
            usedColumns.insert(option.id)
        }

        return mapping
    }
}

private extension CSVColumn {
    /// カラムとヘッダー文字列のマッチングロジック
    func matches(_ header: String) -> Bool {
        let lowercased = header.lowercased()

        switch self {
        case .date:
            return lowercased.contains("date") || header.contains("日付")
        case .title:
            return lowercased.contains("title") || header.contains("内容") || header.contains("摘要")
        case .amount:
            return lowercased.contains("amount") || header.contains("金額") || header.contains("支払")
        case .memo:
            return lowercased.contains("memo") || lowercased.contains("note") || header.contains("メモ")
        case .financialInstitution:
            return lowercased.contains("account") || header.contains("金融") || header.contains("口座")
        case .majorCategory:
            return header.contains("大項目") || header.contains("カテゴリ") && !header.contains("中")
        case .minorCategory:
            return header.contains("中項目") || header.contains("サブカテゴリ") || header.contains("小項目")
        case .includeInCalculation:
            return lowercased.contains("include") || header.contains("計算") || header.contains("集計")
        case .transfer:
            return lowercased.contains("transfer") || header.contains("振替")
        }
    }
}

// MARK: - プレビュー・取り込みモデル

/// インポート時の警告・エラー
internal struct CSVImportIssue: Identifiable, Sendable {
    internal enum Severity: String, Sendable {
        case error
        case warning
    }

    internal let id: UUID
    internal let severity: Severity
    internal let message: String

    internal init(
        id: UUID = UUID(),
        severity: Severity,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.message = message
    }
}

/// インポート前の取引ドラフト
internal struct TransactionDraft: Sendable {
    internal let date: Date
    internal let title: String
    internal let amount: Decimal
    internal let memo: String
    internal let financialInstitutionName: String?
    internal let majorCategoryName: String?
    internal let minorCategoryName: String?
    internal let isIncludedInCalculation: Bool
    internal let isTransfer: Bool
}

/// 1行分の検証結果
internal struct CSVImportRecord: Identifiable, Sendable {
    internal let id: UUID
    internal let rowNumber: Int
    internal let rawValues: [String]
    internal let draft: TransactionDraft?
    internal let issues: [CSVImportIssue]

    internal init(
        id: UUID = UUID(),
        rowNumber: Int,
        rawValues: [String],
        draft: TransactionDraft?,
        issues: [CSVImportIssue]
    ) {
        self.id = id
        self.rowNumber = rowNumber
        self.rawValues = rawValues
        self.draft = draft
        self.issues = issues
    }

    /// エラーがなければ有効
    internal var isValid: Bool {
        draft != nil && issues.allSatisfy { $0.severity != .error }
    }
}

/// プレビュー結果
internal struct CSVImportPreview: Sendable {
    internal let createdAt: Date
    internal let records: [CSVImportRecord]

    internal init(
        createdAt: Date = Date(),
        records: [CSVImportRecord]
    ) {
        self.createdAt = createdAt
        self.records = records
    }

    internal var totalCount: Int { records.count }
    internal var validRecords: [CSVImportRecord] { records.filter(\.isValid) }
    internal var skippedCount: Int { totalCount - validRecords.count }
    internal var hasErrors: Bool { skippedCount > 0 }
    internal var issueCount: Int { records.reduce(0) { $0 + $1.issues.count } }
}

/// 取り込み結果のサマリ
internal struct CSVImportSummary: Sendable {
    internal let importedCount: Int
    internal let skippedCount: Int
    internal let createdFinancialInstitutions: Int
    internal let createdCategories: Int
    internal let duration: TimeInterval
}

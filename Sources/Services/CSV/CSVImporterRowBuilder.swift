import Foundation
import SwiftData

// MARK: - Row Building Extensions

extension CSVImporter {
    /// CSVRowからCSVImportRecordを構築
    internal func buildRecord(
        for row: CSVRow,
        mapping: CSVColumnMapping,
    ) -> CSVImportRecord {
        var issues: [CSVImportIssue] = []

        let identifier = extractIdentifier(from: row, mapping: mapping)

        guard let validationResult = validateRequiredFields(row: row, mapping: mapping) else {
            return createErrorRecord(row: row, mapping: mapping, issues: &issues)
        }

        let optionalFields = extractOptionalFields(from: row, mapping: mapping, issues: &issues)

        if optionalFields.minorCategory != nil, optionalFields.majorCategory == nil {
            issues.append(.init(severity: .error, message: "中項目を指定する場合は大項目も指定してください"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

        let flags = extractFlags(from: row, mapping: mapping, issues: &issues)

        let draft = TransactionDraft(
            identifier: identifier,
            date: validationResult.date,
            title: validationResult.title,
            amount: validationResult.amount,
            memo: optionalFields.memo,
            financialInstitutionName: optionalFields.financialInstitution,
            majorCategoryName: optionalFields.majorCategory,
            minorCategoryName: optionalFields.minorCategory,
            isIncludedInCalculation: flags.isIncludedInCalculation,
            isTransfer: flags.isTransfer,
        )

        return CSVImportRecord(
            rowNumber: row.lineNumber,
            rawValues: row.values,
            draft: draft,
            issues: issues,
        )
    }

    /// 識別子を抽出
    internal func extractIdentifier(from row: CSVRow, mapping: CSVColumnMapping) -> CSVTransactionIdentifier? {
        guard let rawId = normalizedOptional(mapping.value(for: .identifier, in: row)) else {
            return nil
        }
        return CSVTransactionIdentifier(rawValue: rawId)
    }

    /// 必須フィールドをバリデーション
    internal func validateRequiredFields(
        row: CSVRow,
        mapping: CSVColumnMapping,
    ) -> RequiredFieldsResult? {
        guard let rawDate = mapping.value(for: .date, in: row)?.trimmed, !rawDate.isEmpty,
              let date = parseDate(rawDate) else {
            return nil
        }

        guard let rawTitle = mapping.value(for: .title, in: row)?.trimmed, !rawTitle.isEmpty else {
            return nil
        }

        guard let rawAmount = mapping.value(for: .amount, in: row)?.trimmed, !rawAmount.isEmpty,
              let amount = parseDecimal(rawAmount) else {
            return nil
        }

        return RequiredFieldsResult(date: date, title: rawTitle, amount: amount)
    }

    /// エラーレコードを作成（必須フィールドのバリデーションに失敗した場合）
    internal func createErrorRecord(
        row: CSVRow,
        mapping: CSVColumnMapping,
        issues: inout [CSVImportIssue],
    ) -> CSVImportRecord {
        if let rawDate = mapping.value(for: .date, in: row)?.trimmed, !rawDate.isEmpty {
            if parseDate(rawDate) == nil {
                issues.append(.init(severity: .error, message: "日付の形式が不正です: \(rawDate)"))
            }
        } else {
            issues.append(.init(severity: .error, message: "日付が設定されていません"))
        }

        if mapping.value(for: .title, in: row)?.trimmed?.isEmpty ?? true {
            issues.append(.init(severity: .error, message: "内容が設定されていません"))
        }

        if let rawAmount = mapping.value(for: .amount, in: row)?.trimmed, !rawAmount.isEmpty {
            if parseDecimal(rawAmount) == nil {
                issues.append(.init(severity: .error, message: "金額を数値として認識できません: \(rawAmount)"))
            }
        } else {
            issues.append(.init(severity: .error, message: "金額が設定されていません"))
        }

        return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
    }

    /// オプションフィールドを抽出
    internal func extractOptionalFields(
        from row: CSVRow,
        mapping: CSVColumnMapping,
        issues: inout [CSVImportIssue],
    ) -> OptionalFieldsResult {
        let memo = mapping.value(for: .memo, in: row)?.trimmed ?? ""
        let financialInstitution = normalizedOptional(mapping.value(for: .financialInstitution, in: row))
        let majorCategory = normalizedOptional(mapping.value(for: .majorCategory, in: row))
        let minorCategory = normalizedOptional(mapping.value(for: .minorCategory, in: row))

        return OptionalFieldsResult(
            memo: memo,
            financialInstitution: financialInstitution,
            majorCategory: majorCategory,
            minorCategory: minorCategory,
        )
    }

    /// フラグ（ブール値）フィールドを抽出
    internal func extractFlags(
        from row: CSVRow,
        mapping: CSVColumnMapping,
        issues: inout [CSVImportIssue],
    ) -> (isIncludedInCalculation: Bool, isTransfer: Bool) {
        var isIncludedInCalculation = true
        if let includeValue = normalizedOptional(mapping.value(for: .includeInCalculation, in: row)) {
            if let parsed = parseBoolean(includeValue) {
                isIncludedInCalculation = parsed
            } else {
                issues.append(.init(
                    severity: .warning,
                    message: "計算対象フラグを解釈できなかったため「計算対象」として扱います",
                ))
            }
        }

        var isTransfer = false
        if let transferValue = normalizedOptional(mapping.value(for: .transfer, in: row)) {
            if let parsed = parseBoolean(transferValue) {
                isTransfer = parsed
            } else {
                issues.append(.init(
                    severity: .warning,
                    message: "振替フラグを解釈できなかったため「振替なし」として扱います",
                ))
            }
        }

        return (isIncludedInCalculation, isTransfer)
    }
}

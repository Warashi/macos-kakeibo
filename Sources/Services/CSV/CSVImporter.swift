import Foundation
import SwiftData

/// CSVインポート処理を担当するヘルパー
@MainActor
internal final class CSVImporter {
    internal enum ImportError: Error, LocalizedError {
        case incompleteMapping
        case emptyDocument
        case nothingToImport

        internal var errorDescription: String? {
            switch self {
            case .incompleteMapping:
                "必須カラム（日付・内容・金額）の割り当てを完了してください。"
            case .emptyDocument:
                "インポート可能な行がありません。"
            case .nothingToImport:
                "取り込めるデータがありません。"
            }
        }
    }

    private let modelContext: ModelContext
    private let dateFormatters: [DateFormatter]
    private let locale: Foundation.Locale

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.dateFormatters = CSVImporter.makeDateFormatters()
        self.locale = AppConstants.Locale.default
    }

    // MARK: - Preview

    /// CSVのプレビューを生成
    internal func makePreview(
        document: CSVDocument,
        mapping: CSVColumnMapping,
        configuration: CSVImportConfiguration,
    ) throws -> CSVImportPreview {
        guard mapping.hasRequiredAssignments else {
            throw ImportError.incompleteMapping
        }

        let rows = document.dataRows(skipHeader: configuration.hasHeaderRow)
        guard !rows.isEmpty else {
            throw ImportError.emptyDocument
        }

        let records = rows.map { row in
            buildRecord(for: row, mapping: mapping)
        }

        return CSVImportPreview(records: records)
    }

    // MARK: - Import

    /// プレビュー済みデータをSwiftDataに取り込む
    internal func performImport(preview: CSVImportPreview) throws -> CSVImportSummary {
        guard !preview.validRecords.isEmpty else {
            throw ImportError.nothingToImport
        }

        let startDate = Date()
        var importedCount = 0
        var updatedCount = 0
        var createdInstitutions = 0
        var createdCategories = 0

        var institutionCache: [String: FinancialInstitution] = [:]
        var majorCategoryCache: [String: Category] = [:]
        var minorCategoryCache: [String: Category] = [:]

        for record in preview.validRecords {
            guard let draft = record.draft else { continue }

            let (institution, institutionCreated) = try resolveFinancialInstitution(
                named: draft.financialInstitutionName,
                cache: &institutionCache,
            )
            if institutionCreated {
                createdInstitutions += 1
            }

            let (majorCategory, minorCategory, categoryCreatedCount) = try resolveCategories(
                majorName: draft.majorCategoryName,
                minorName: draft.minorCategoryName,
                majorCache: &majorCategoryCache,
                minorCache: &minorCategoryCache,
            )
            createdCategories += categoryCreatedCount

            let transaction: Transaction
            var isNew = false

            if let identifier = draft.identifier {
                if let uuid = identifier.uuid, let existing = try fetchTransaction(id: uuid) {
                    transaction = existing
                } else if let existing = try fetchTransaction(importIdentifier: identifier.rawValue) {
                    transaction = existing
                } else {
                    transaction = Transaction(
                        id: identifier.uuid ?? UUID(),
                        date: draft.date,
                        title: draft.title,
                        amount: draft.amount,
                        memo: draft.memo,
                        isIncludedInCalculation: draft.isIncludedInCalculation,
                        isTransfer: draft.isTransfer,
                        importIdentifier: identifier.rawValue,
                        financialInstitution: institution,
                        majorCategory: majorCategory,
                        minorCategory: minorCategory,
                    )
                    modelContext.insert(transaction)
                    isNew = true
                }
            } else {
                transaction = Transaction(
                    date: draft.date,
                    title: draft.title,
                    amount: draft.amount,
                    memo: draft.memo,
                    isIncludedInCalculation: draft.isIncludedInCalculation,
                    isTransfer: draft.isTransfer,
                    financialInstitution: institution,
                    majorCategory: majorCategory,
                    minorCategory: minorCategory,
                )
                modelContext.insert(transaction)
                isNew = true
            }

            applyDraft(
                draft,
                to: transaction,
                identifier: draft.identifier,
                institution: institution,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            )

            if isNew {
                importedCount += 1
            } else {
                updatedCount += 1
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return CSVImportSummary(
            importedCount: importedCount,
            updatedCount: updatedCount,
            skippedCount: preview.skippedCount,
            createdFinancialInstitutions: createdInstitutions,
            createdCategories: createdCategories,
            duration: Date().timeIntervalSince(startDate),
        )
    }

    // MARK: - Row Building

    private func buildRecord(
        for row: CSVRow,
        mapping: CSVColumnMapping,
    ) -> CSVImportRecord {
        var issues: [CSVImportIssue] = []

        var identifier: CSVTransactionIdentifier?
        if let rawId = normalizedOptional(mapping.value(for: .identifier, in: row)) {
            identifier = CSVTransactionIdentifier(rawValue: rawId)
        }

        guard let rawDate = mapping.value(for: .date, in: row)?.trimmed, !rawDate.isEmpty else {
            issues.append(.init(severity: .error, message: "日付が設定されていません"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

        guard let date = parseDate(rawDate) else {
            issues.append(.init(severity: .error, message: "日付の形式が不正です: \(rawDate)"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

        guard let rawTitle = mapping.value(for: .title, in: row)?.trimmed, !rawTitle.isEmpty else {
            issues.append(.init(severity: .error, message: "内容が設定されていません"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

        guard let rawAmount = mapping.value(for: .amount, in: row)?.trimmed, !rawAmount.isEmpty else {
            issues.append(.init(severity: .error, message: "金額が設定されていません"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

        guard let amount = parseDecimal(rawAmount) else {
            issues.append(.init(severity: .error, message: "金額を数値として認識できません: \(rawAmount)"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

        let memo = mapping.value(for: .memo, in: row)?.trimmed ?? ""
        let financialInstitution = normalizedOptional(mapping.value(for: .financialInstitution, in: row))
        let majorCategory = normalizedOptional(mapping.value(for: .majorCategory, in: row))
        let minorCategory = normalizedOptional(mapping.value(for: .minorCategory, in: row))

        if minorCategory != nil, majorCategory == nil {
            issues.append(.init(severity: .error, message: "中項目を指定する場合は大項目も指定してください"))
            return CSVImportRecord(rowNumber: row.lineNumber, rawValues: row.values, draft: nil, issues: issues)
        }

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

        let draft = TransactionDraft(
            identifier: identifier,
            date: date,
            title: rawTitle,
            amount: amount,
            memo: memo,
            financialInstitutionName: financialInstitution,
            majorCategoryName: majorCategory,
            minorCategoryName: minorCategory,
            isIncludedInCalculation: isIncludedInCalculation,
            isTransfer: isTransfer,
        )

        return CSVImportRecord(
            rowNumber: row.lineNumber,
            rawValues: row.values,
            draft: draft,
            issues: issues,
        )
    }

    // MARK: - Helpers

    private func normalizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func parseDate(_ value: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private func parseDecimal(_ value: String) -> Decimal? {
        var sanitized = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "円", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.hasPrefix("("), sanitized.hasSuffix(")") {
            sanitized.removeFirst()
            sanitized.removeLast()
            sanitized = "-" + sanitized
        }

        return Decimal(string: sanitized, locale: locale)
    }

    private func parseBoolean(_ value: String) -> Bool? {
        let lowered = value.lowercased()
        switch lowered {
        case "1", "true", "yes", "y", "on", "はい", "有", "true.":
            return true
        case "0", "false", "no", "n", "off", "いいえ", "無":
            return false
        default:
            return nil
        }
    }

    private static func makeDateFormatters() -> [DateFormatter] {
        [
            "yyyy/MM/dd",
            "yyyy/M/d",
            "yyyy-MM-dd",
            "yyyy-M-d",
            "yyyy.MM.dd",
            "yyyyMMdd",
            "MM/dd/yyyy",
            "M/d/yyyy",
        ].map { format in
            let formatter = DateFormatter()
            formatter.locale = AppConstants.Locale.default
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            return formatter
        }
    }
}

// MARK: - SwiftData helpers

private extension CSVImporter {
    func resolveFinancialInstitution(
        named name: String?,
        cache: inout [String: FinancialInstitution],
    ) throws -> (FinancialInstitution?, Bool) {
        guard let name else {
            return (nil, false)
        }

        let key = name.lowercased()
        if let cached = cache[key] {
            return (cached, false)
        }

        var descriptor = FetchDescriptor<FinancialInstitution>(
            predicate: #Predicate { institution in
                institution.name == name
            },
        )
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            cache[key] = existing
            return (existing, false)
        }

        let institution = FinancialInstitution(name: name)
        modelContext.insert(institution)
        cache[key] = institution
        return (institution, true)
    }

    func resolveCategories(
        majorName: String?,
        minorName: String?,
        majorCache: inout [String: Category],
        minorCache: inout [String: Category],
    ) throws -> (Category?, Category?, Int) {
        var createdCount = 0
        var majorCategory: Category?
        var minorCategory: Category?

        if let majorName {
            let majorKey = majorName.lowercased()
            if let cached = majorCache[majorKey] {
                majorCategory = cached
            } else {
                var descriptor = FetchDescriptor<Category>(
                    predicate: #Predicate { category in
                        category.name == majorName && category.parent == nil
                    },
                )
                descriptor.fetchLimit = 1

                if let existing = try modelContext.fetch(descriptor).first {
                    majorCategory = existing
                } else {
                    let newCategory = Category(name: majorName)
                    modelContext.insert(newCategory)
                    majorCategory = newCategory
                    createdCount += 1
                }

                if let majorCategory {
                    majorCache[majorKey] = majorCategory
                }
            }
        }

        if let minorName {
            guard let majorCategory else {
                return (majorCategory, nil, createdCount)
            }

            let key = "\(majorCategory.id.uuidString.lowercased())::\(minorName.lowercased())"
            if let cached = minorCache[key] {
                minorCategory = cached
            } else {
                let descriptor = FetchDescriptor<Category>(
                    predicate: #Predicate { category in
                        category.name == minorName
                    },
                )

                let existing = try modelContext
                    .fetch(descriptor)
                    .first { $0.parent?.id == majorCategory.id }

                if let existing {
                    minorCategory = existing
                } else {
                    let newCategory = Category(name: minorName, parent: majorCategory)
                    modelContext.insert(newCategory)
                    minorCategory = newCategory
                    createdCount += 1
                }

                if let minorCategory {
                    minorCache[key] = minorCategory
                }
            }
        }

        return (majorCategory, minorCategory, createdCount)
    }

    private func fetchTransaction(id: UUID) throws -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.id == id
            },
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchTransaction(importIdentifier: String) throws -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.importIdentifier == importIdentifier
            },
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func applyDraft(
        _ draft: TransactionDraft,
        to transaction: Transaction,
        identifier: CSVTransactionIdentifier?,
        institution: FinancialInstitution?,
        majorCategory: Category?,
        minorCategory: Category?,
    ) {
        transaction.date = draft.date
        transaction.title = draft.title
        transaction.amount = draft.amount
        transaction.memo = draft.memo
        transaction.isIncludedInCalculation = draft.isIncludedInCalculation
        transaction.isTransfer = draft.isTransfer
        transaction.financialInstitution = institution
        transaction.majorCategory = majorCategory
        transaction.minorCategory = minorCategory
        transaction.importIdentifier = identifier?.rawValue ?? transaction.importIdentifier
        transaction.updatedAt = Date()
    }
}

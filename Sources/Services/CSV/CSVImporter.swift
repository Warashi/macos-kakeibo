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

    internal let modelContext: ModelContext
    internal let dateFormatters: [DateFormatter]
    internal let locale: Foundation.Locale

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
        var state = ImportState()
        var cache = EntityCache()

        for record in preview.validRecords {
            guard let draft = record.draft else { continue }

            let isNew = try importRecord(draft: draft, state: &state, cache: &cache)

            if isNew {
                state.importedCount += 1
            } else {
                state.updatedCount += 1
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return CSVImportSummary(
            importedCount: state.importedCount,
            updatedCount: state.updatedCount,
            skippedCount: preview.skippedCount,
            createdFinancialInstitutions: state.createdInstitutions,
            createdCategories: state.createdCategories,
            duration: Date().timeIntervalSince(startDate),
        )
    }

    private func importRecord(
        draft: TransactionDraft,
        state: inout ImportState,
        cache: inout EntityCache,
    ) throws -> Bool {
        let (institution, institutionCreated) = try resolveFinancialInstitution(
            named: draft.financialInstitutionName,
            cache: &cache.institutions,
        )
        if institutionCreated {
            state.createdInstitutions += 1
        }

        let categoryResult = try resolveCategories(
            majorName: draft.majorCategoryName,
            minorName: draft.minorCategoryName,
            majorCache: &cache.majorCategories,
            minorCache: &cache.minorCategories,
        )
        state.createdCategories += categoryResult.createdCount

        let (transaction, isNew) = try getOrCreateTransaction(
            draft: draft,
            institution: institution,
            majorCategory: categoryResult.majorCategory,
            minorCategory: categoryResult.minorCategory,
        )

        let parameters = TransactionUpdateParameters(
            draft: draft,
            identifier: draft.identifier,
            institution: institution,
            majorCategory: categoryResult.majorCategory,
            minorCategory: categoryResult.minorCategory,
        )
        applyDraft(parameters, to: transaction)

        return isNew
    }

    private func getOrCreateTransaction(
        draft: TransactionDraft,
        institution: FinancialInstitution?,
        majorCategory: Category?,
        minorCategory: Category?,
    ) throws -> (Transaction, Bool) {
        if let identifier = draft.identifier {
            if let uuid = identifier.uuid, let existing = try fetchTransaction(id: uuid) {
                return (existing, false)
            } else if let existing = try fetchTransaction(importIdentifier: identifier.rawValue) {
                return (existing, false)
            } else {
                let parameters = TransactionCreationParameters(
                    draft: draft,
                    identifier: identifier,
                    institution: institution,
                    majorCategory: majorCategory,
                    minorCategory: minorCategory,
                )
                let transaction = createTransaction(parameters)
                modelContext.insert(transaction)
                return (transaction, true)
            }
        } else {
            let parameters = TransactionCreationParameters(
                draft: draft,
                identifier: nil,
                institution: institution,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            )
            let transaction = createTransaction(parameters)
            modelContext.insert(transaction)
            return (transaction, true)
        }
    }

    private func createTransaction(_ parameters: TransactionCreationParameters) -> Transaction {
        if let identifier = parameters.identifier {
            Transaction(
                id: identifier.uuid ?? UUID(),
                date: parameters.draft.date,
                title: parameters.draft.title,
                amount: parameters.draft.amount,
                memo: parameters.draft.memo,
                isIncludedInCalculation: parameters.draft.isIncludedInCalculation,
                isTransfer: parameters.draft.isTransfer,
                importIdentifier: identifier.rawValue,
                financialInstitution: parameters.institution,
                majorCategory: parameters.majorCategory,
                minorCategory: parameters.minorCategory,
            )
        } else {
            Transaction(
                date: parameters.draft.date,
                title: parameters.draft.title,
                amount: parameters.draft.amount,
                memo: parameters.draft.memo,
                isIncludedInCalculation: parameters.draft.isIncludedInCalculation,
                isTransfer: parameters.draft.isTransfer,
                financialInstitution: parameters.institution,
                majorCategory: parameters.majorCategory,
                minorCategory: parameters.minorCategory,
            )
        }
    }

    // MARK: - Date Formatter Factory

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

// MARK: - Transaction Update

private extension CSVImporter {
    func applyDraft(
        _ parameters: TransactionUpdateParameters,
        to transaction: Transaction,
    ) {
        transaction.date = parameters.draft.date
        transaction.title = parameters.draft.title
        transaction.amount = parameters.draft.amount
        transaction.memo = parameters.draft.memo
        transaction.isIncludedInCalculation = parameters.draft.isIncludedInCalculation
        transaction.isTransfer = parameters.draft.isTransfer
        transaction.financialInstitution = parameters.institution
        transaction.majorCategory = parameters.majorCategory
        transaction.minorCategory = parameters.minorCategory
        transaction.importIdentifier = parameters.identifier?.rawValue ?? transaction.importIdentifier
        transaction.updatedAt = Date()
    }
}

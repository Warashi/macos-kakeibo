import Foundation
import SwiftData

/// CSVインポート処理を担当するヘルパー
internal actor CSVImporter {
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

    internal let dateFormatters: [DateFormatter]
    internal let locale: Foundation.Locale

    internal init() {
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
    /// - Note: @MainActor is required because ModelContext is Non-Sendable
    @MainActor
    internal func performImport(preview: CSVImportPreview, modelContext: ModelContext) throws -> CSVImportSummary {
        guard !preview.validRecords.isEmpty else {
            throw ImportError.nothingToImport
        }

        let startDate = Date()
        var state = ImportState()
        var cache = EntityCache()

        for record in preview.validRecords {
            guard let draft = record.draft else { continue }

            let isNew = try importRecord(draft: draft, state: &state, cache: &cache, modelContext: modelContext)

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

    @MainActor
    private func importRecord(
        draft: TransactionDraft,
        state: inout ImportState,
        cache: inout EntityCache,
        modelContext: ModelContext,
    ) throws -> Bool {
        let (institution, institutionCreated) = try resolveFinancialInstitution(
            named: draft.financialInstitutionName,
            cache: &cache.institutions,
            modelContext: modelContext,
        )
        if institutionCreated {
            state.createdInstitutions += 1
        }

        var categoryContext = CategoryResolutionContext(
            majorName: draft.majorCategoryName,
            minorName: draft.minorCategoryName,
            majorCache: cache.majorCategories,
            minorCache: cache.minorCategories,
            modelContext: modelContext,
        )
        let categoryResult = try resolveCategories(context: &categoryContext)
        cache.majorCategories = categoryContext.majorCache
        cache.minorCategories = categoryContext.minorCache
        state.createdCategories += categoryResult.createdCount

        let creationParams = TransactionCreationParameters(
            draft: draft,
            identifier: draft.identifier,
            institution: institution,
            majorCategory: categoryResult.majorCategory,
            minorCategory: categoryResult.minorCategory,
        )

        let (transaction, isNew) = try getOrCreateTransaction(
            parameters: creationParams,
            modelContext: modelContext,
        )

        let updateParams = TransactionUpdateParameters(
            draft: draft,
            identifier: draft.identifier,
            institution: institution,
            majorCategory: categoryResult.majorCategory,
            minorCategory: categoryResult.minorCategory,
        )
        applyDraft(updateParams, to: transaction)

        return isNew
    }

    @MainActor
    private func getOrCreateTransaction(
        parameters: TransactionCreationParameters,
        modelContext: ModelContext,
    ) throws -> (Transaction, Bool) {
        if let identifier = parameters.identifier {
            if let uuid = identifier.uuid, let existing = try fetchTransaction(id: uuid, modelContext: modelContext) {
                return (existing, false)
            } else if let existing = try fetchTransaction(
                importIdentifier: identifier.rawValue,
                modelContext: modelContext,
            ) {
                return (existing, false)
            } else {
                let transaction = createTransaction(parameters)
                modelContext.insert(transaction)
                return (transaction, true)
            }
        } else {
            let transaction = createTransaction(parameters)
            modelContext.insert(transaction)
            return (transaction, true)
        }
    }

    private nonisolated func createTransaction(_ parameters: TransactionCreationParameters) -> Transaction {
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
    nonisolated func applyDraft(
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

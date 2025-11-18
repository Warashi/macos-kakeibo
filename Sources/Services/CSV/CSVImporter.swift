import Foundation

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

    let transactionRepository: TransactionRepository
    let budgetRepository: BudgetRepository
    internal let dateFormatters: [DateFormatter]
    internal let locale: Foundation.Locale

    internal init(
        transactionRepository: TransactionRepository,
        budgetRepository: BudgetRepository,
    ) {
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
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
    internal func performImport(
        preview: CSVImportPreview,
        batchSize: Int = 50,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil,
    ) async throws -> CSVImportSummary {
        guard !preview.validRecords.isEmpty else {
            throw ImportError.nothingToImport
        }

        let startDate = Date()
        var state = ImportState()
        var cache = EntityCache()

        let totalCount = preview.validRecords.count
        var processedCount = 0

        for record in preview.validRecords {
            guard let draft = record.draft else { continue }

            let isNew = try await importRecord(
                draft: draft,
                state: &state,
                cache: &cache,
            )

            if isNew {
                state.importedCount += 1
            } else {
                state.updatedCount += 1
            }

            processedCount += 1

            // バッチごとに保存して他のタスクへ実行権を譲渡
            if processedCount % batchSize == 0 {
                try await transactionRepository.saveChanges()
                if let onProgress {
                    onProgress(processedCount, totalCount)
                }
                await Task.yield() // 他のタスクへ実行権を譲渡
            }
        }

        // 最後の残りを保存
        try await transactionRepository.saveChanges()
        try await budgetRepository.saveChanges()
        if let onProgress {
            onProgress(totalCount, totalCount)
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
    ) async throws -> Bool {
        let (institution, institutionCreated) = try await resolveFinancialInstitution(
            named: draft.financialInstitutionName,
            cache: &cache.institutions,
        )
        if institutionCreated {
            state.createdInstitutions += 1
        }

        var categoryContext = CategoryResolutionContext(
            majorName: draft.majorCategoryName,
            minorName: draft.minorCategoryName,
            majorCache: cache.majorCategories,
            minorCache: cache.minorCategories,
        )
        let categoryResult = try await resolveCategories(context: &categoryContext)
        cache.majorCategories = categoryContext.majorCache
        cache.minorCategories = categoryContext.minorCache
        state.createdCategories += categoryResult.createdCount

        if institutionCreated || categoryResult.createdCount > 0 {
            try await budgetRepository.saveChanges()
        }

        let creationParams = TransactionCreationParameters(
            draft: draft,
            identifier: draft.identifier,
            institution: institution,
            majorCategory: categoryResult.majorCategory,
            minorCategory: categoryResult.minorCategory,
        )

        if let existing = try await findExistingTransaction(identifier: draft.identifier) {
            let updateParams = TransactionUpdateParameters(
                draft: draft,
                identifier: draft.identifier,
                institution: institution,
                majorCategory: categoryResult.majorCategory,
                minorCategory: categoryResult.minorCategory,
                existingImportIdentifier: existing.importIdentifier,
            )
            let input = makeTransactionInput(parameters: updateParams)
            try await transactionRepository.update(TransactionUpdateInput(id: existing.id, input: input))
            return false
        } else {
            let input = makeTransactionInput(parameters: creationParams)
            _ = try await transactionRepository.insert(input)
            return true
        }
    }

    private func findExistingTransaction(
        identifier: CSVTransactionIdentifier?,
    ) async throws -> Transaction? {
        guard let identifier else {
            return nil
        }

        if let uuid = identifier.uuid, let transaction = try await transactionRepository.findTransaction(id: uuid) {
            return transaction
        }

        return try await transactionRepository.findByIdentifier(identifier.rawValue)
    }

    private nonisolated func makeTransactionInput(parameters: TransactionCreationParameters) -> TransactionInput {
        TransactionInput(
            date: parameters.draft.date,
            title: parameters.draft.title,
            memo: parameters.draft.memo,
            amount: parameters.draft.amount,
            isIncludedInCalculation: parameters.draft.isIncludedInCalculation,
            isTransfer: parameters.draft.isTransfer,
            financialInstitutionId: parameters.institution?.id,
            majorCategoryId: parameters.majorCategory?.id,
            minorCategoryId: parameters.minorCategory?.id,
            importIdentifier: parameters.identifier?.rawValue,
        )
    }

    private nonisolated func makeTransactionInput(parameters: TransactionUpdateParameters) -> TransactionInput {
        TransactionInput(
            date: parameters.draft.date,
            title: parameters.draft.title,
            memo: parameters.draft.memo,
            amount: parameters.draft.amount,
            isIncludedInCalculation: parameters.draft.isIncludedInCalculation,
            isTransfer: parameters.draft.isTransfer,
            financialInstitutionId: parameters.institution?.id,
            majorCategoryId: parameters.majorCategory?.id,
            minorCategoryId: parameters.minorCategory?.id,
            importIdentifier: parameters.identifier?.rawValue ?? parameters.existingImportIdentifier,
        )
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

import Foundation
import SwiftData

/// バックアップ生成結果
internal struct BackupArchive: Sendable {
    internal let data: Data
    internal let metadata: BackupMetadata
    internal let suggestedFileName: String
}

/// リストア結果
internal struct BackupRestoreSummary: Sendable {
    internal let metadata: BackupMetadata
    internal let restoredCounts: BackupRecordCounts
}

/// バックアップメタデータ
internal struct BackupMetadata: Codable, Sendable {
    internal let generatedAt: Date
    internal let appVersion: String
    internal let build: String
    internal let recordCounts: BackupRecordCounts
}

/// バックアップ対象件数
internal struct BackupRecordCounts: Codable, Sendable {
    internal let transactions: Int
    internal let categories: Int
    internal let budgets: Int
    internal let annualBudgetConfigs: Int
    internal let annualBudgetAllocations: Int
    internal let financialInstitutions: Int
    internal let recurringPaymentDefinitions: Int
    internal let recurringPaymentOccurrences: Int
    internal let recurringPaymentSavingBalances: Int
    internal let customHolidays: Int
}

/// バックアップ関連エラー
internal enum BackupManagerError: LocalizedError {
    case decodingFailed

    internal var errorDescription: String? {
        switch self {
        case .decodingFailed:
            "バックアップデータの読み込みに失敗しました。"
        }
    }
}

/// バックアップとリストアを担当するコンポーネント
internal actor BackupManager {
    private let modelContainer: ModelContainer

    internal init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// バックアップを生成
    /// - Parameter payload: バックアップペイロード (MainActor で事前に生成)
    /// - Returns: バックアップデータとメタデータ
    internal func createBackup(payload: BackupPayload) throws -> BackupArchive {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let fileName = makeFileName(for: payload.metadata.generatedAt)
        return BackupArchive(data: data, metadata: payload.metadata, suggestedFileName: fileName)
    }

    /// バックアップペイロードを構築
    internal func buildPayload() throws -> BackupPayload {
        let modelContext = ModelContext(modelContainer)
        let transactions = try modelContext.fetchAll(SwiftDataTransaction.self)
        let categories = try modelContext.fetchAll(SwiftDataCategory.self)
        let budgets = try modelContext.fetchAll(SwiftDataBudget.self)
        let configs = try modelContext.fetchAll(SwiftDataAnnualBudgetConfig.self)
        let allocations = try modelContext.fetchAll(SwiftDataAnnualBudgetAllocation.self)
        let institutions = try modelContext.fetchAll(SwiftDataFinancialInstitution.self)
        let definitions = try modelContext.fetchAll(SwiftDataRecurringPaymentDefinition.self)
        let occurrences = try modelContext.fetchAll(SwiftDataRecurringPaymentOccurrence.self)
        let balances = try modelContext.fetchAll(SwiftDataRecurringPaymentSavingBalance.self)
        let holidays = try modelContext.fetchAll(SwiftDataCustomHoliday.self)

        let metadata = BackupMetadata(
            generatedAt: Date(),
            appVersion: AppConstants.App.version,
            build: AppConstants.App.build,
            recordCounts: BackupRecordCounts(
                transactions: transactions.count,
                categories: categories.count,
                budgets: budgets.count,
                annualBudgetConfigs: configs.count,
                annualBudgetAllocations: allocations.count,
                financialInstitutions: institutions.count,
                recurringPaymentDefinitions: definitions.count,
                recurringPaymentOccurrences: occurrences.count,
                recurringPaymentSavingBalances: balances.count,
                customHolidays: holidays.count,
            ),
        )

        return BackupPayload(
            metadata: metadata,
            transactions: transactions.map(BackupTransactionDTO.init),
            categories: categories.map(BackupCategory.init),
            budgets: budgets.map(BackupBudgetDTO.init),
            annualBudgetConfigs: configs.map(BackupAnnualBudgetConfig.init),
            annualBudgetAllocations: allocations.map(BackupAnnualBudgetAllocationDTO.init),
            financialInstitutions: institutions.map(BackupFinancialInstitutionDTO.init),
            recurringPaymentDefinitions: definitions.map(BackupRecurringPaymentDefinitionDTO.init),
            recurringPaymentOccurrences: occurrences.map(BackupRecurringPaymentOccurrenceDTO.init),
            recurringPaymentSavingBalances: balances.map(BackupRecurringPaymentSavingBalanceDTO.init),
            customHolidays: holidays.map(BackupCustomHolidayDTO.init),
        )
    }

    /// バックアップからデータを復元（デコードのみ）
    /// - Parameter data: バックアップデータ
    /// - Returns: デコードされたペイロード
    internal func decodeBackup(from data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else {
            throw BackupManagerError.decodingFailed
        }

        return payload
    }

    /// ペイロードからデータを復元
    internal func restorePayload(_ payload: BackupPayload) throws -> BackupRestoreSummary {
        let modelContext = ModelContext(modelContainer)
        try clearAllData(in: modelContext)

        // 依存関係の順序に従って復元
        let institutions = try insertFinancialInstitutions(payload.financialInstitutions, context: modelContext)
        let categories = try insertCategories(payload.categories, context: modelContext)
        try insertCustomHolidays(payload.customHolidays, context: modelContext)
        let configs = try insertAnnualBudgetConfigs(payload.annualBudgetConfigs, context: modelContext)
        try insertAnnualBudgetAllocations(
            payload.annualBudgetAllocations,
            categories: categories,
            configs: configs,
            context: modelContext,
        )
        try insertBudgets(payload.budgets, categories: categories, context: modelContext)
        let definitions = try insertRecurringPaymentDefinitions(
            payload.recurringPaymentDefinitions,
            categories: categories,
            context: modelContext,
        )
        let transactions = try insertTransactions(
            payload.transactions,
            categories: categories,
            institutions: institutions,
            context: modelContext,
        )
        try insertRecurringPaymentOccurrences(
            payload.recurringPaymentOccurrences,
            definitions: definitions,
            transactions: transactions,
            context: modelContext,
        )
        try insertRecurringPaymentSavingBalances(
            payload.recurringPaymentSavingBalances,
            definitions: definitions,
            context: modelContext,
        )

        try modelContext.save()

        return BackupRestoreSummary(
            metadata: payload.metadata,
            restoredCounts: payload.metadata.recordCounts,
        )
    }

    // MARK: - Clear

    private func clearAllData(in context: ModelContext) throws {
        // 依存関係の順序に注意して削除
        try deleteAll(SwiftDataRecurringPaymentOccurrence.self, in: context)
        try deleteAll(SwiftDataRecurringPaymentSavingBalance.self, in: context)
        try deleteAll(SwiftDataRecurringPaymentDefinition.self, in: context)
        try deleteAll(SwiftDataAnnualBudgetAllocation.self, in: context)
        try deleteAll(SwiftDataTransaction.self, in: context)
        try deleteAll(SwiftDataBudget.self, in: context)
        try deleteAll(SwiftDataAnnualBudgetConfig.self, in: context)
        try deleteCategoriesSafely(in: context)
        try deleteAll(SwiftDataFinancialInstitution.self, in: context)
        try deleteAll(SwiftDataCustomHoliday.self, in: context)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }

    /// 親子関係を維持しながらカテゴリを削除
    private func deleteCategoriesSafely(in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<SwiftDataCategory> = ModelFetchFactory.make()
        let categories = try context.fetch(descriptor)
        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)

        for category in minors + majors {
            context.delete(category)
        }
    }

    // MARK: - Insert

    @discardableResult
    private func insertFinancialInstitutions(
        _ dtos: [BackupFinancialInstitutionDTO],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataFinancialInstitution] {
        var result: [UUID: SwiftDataFinancialInstitution] = [:]
        for dto in dtos {
            let institution = SwiftDataFinancialInstitution(
                id: dto.id,
                name: dto.name,
                displayOrder: dto.displayOrder,
            )
            institution.createdAt = dto.createdAt
            institution.updatedAt = dto.updatedAt
            context.insert(institution)
            result[dto.id] = institution
        }
        return result
    }

    @discardableResult
    private func insertCategories(
        _ dtos: [BackupCategory],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataCategory] {
        var result: [UUID: SwiftDataCategory] = [:]

        // まず全カテゴリを作成
        for dto in dtos {
            let category = SwiftDataCategory(
                id: dto.id,
                name: dto.name,
                allowsAnnualBudget: dto.allowsAnnualBudget,
                displayOrder: dto.displayOrder,
            )
            category.createdAt = dto.createdAt
            category.updatedAt = dto.updatedAt
            context.insert(category)
            result[dto.id] = category
        }

        // 親子関係を設定
        for dto in dtos {
            guard let parentId = dto.parentId,
                  let parent = result[parentId],
                  let category = result[dto.id] else {
                continue
            }
            category.parent = parent
        }

        return result
    }

    private func insertBudgets(
        _ dtos: [BackupBudgetDTO],
        categories: [UUID: SwiftDataCategory],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let budget = SwiftDataBudget(
                id: dto.id,
                amount: dto.amount,
                category: dto.categoryId.flatMap { categories[$0] },
                startYear: dto.startYear,
                startMonth: dto.startMonth,
                endYear: dto.endYear,
                endMonth: dto.endMonth,
            )
            budget.createdAt = dto.createdAt
            budget.updatedAt = dto.updatedAt
            context.insert(budget)
        }
    }

    @discardableResult
    private func insertAnnualBudgetConfigs(
        _ dtos: [BackupAnnualBudgetConfig],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataAnnualBudgetConfig] {
        var result: [UUID: SwiftDataAnnualBudgetConfig] = [:]
        for dto in dtos {
            let config = SwiftDataAnnualBudgetConfig(
                id: dto.id,
                year: dto.year,
                totalAmount: dto.totalAmount,
                policy: dto.policy,
            )
            config.createdAt = dto.createdAt
            config.updatedAt = dto.updatedAt
            context.insert(config)
            result[dto.id] = config
        }
        return result
    }

    @discardableResult
    private func insertTransactions(
        _ dtos: [BackupTransactionDTO],
        categories: [UUID: SwiftDataCategory],
        institutions: [UUID: SwiftDataFinancialInstitution],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataTransaction] {
        var result: [UUID: SwiftDataTransaction] = [:]
        for dto in dtos {
            let transaction = SwiftDataTransaction(
                id: dto.id,
                date: dto.date,
                title: dto.title,
                amount: dto.amount,
                memo: dto.memo,
                isIncludedInCalculation: dto.isIncludedInCalculation,
                isTransfer: dto.isTransfer,
                financialInstitution: dto.financialInstitutionId.flatMap { institutions[$0] },
                majorCategory: dto.majorCategoryId.flatMap { categories[$0] },
                minorCategory: dto.minorCategoryId.flatMap { categories[$0] },
            )
            transaction.createdAt = dto.createdAt
            transaction.updatedAt = dto.updatedAt
            context.insert(transaction)
            result[dto.id] = transaction
        }
        return result
    }

    private func insertCustomHolidays(
        _ dtos: [BackupCustomHolidayDTO],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let holiday = SwiftDataCustomHoliday(
                id: dto.id,
                date: dto.date,
                name: dto.name,
                isRecurring: dto.isRecurring,
            )
            holiday.createdAt = dto.createdAt
            holiday.updatedAt = dto.updatedAt
            context.insert(holiday)
        }
    }

    private func insertAnnualBudgetAllocations(
        _ dtos: [BackupAnnualBudgetAllocationDTO],
        categories: [UUID: SwiftDataCategory],
        configs: [UUID: SwiftDataAnnualBudgetConfig],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            guard let category = categories[dto.categoryId] else { continue }
            let allocation = SwiftDataAnnualBudgetAllocation(
                id: dto.id,
                amount: dto.amount,
                category: category,
            )
            if let policyOverrideRawValue = dto.policyOverrideRawValue {
                allocation.policyOverrideRawValue = policyOverrideRawValue
            }
            if let configId = dto.configId {
                allocation.config = configs[configId]
            }
            allocation.createdAt = dto.createdAt
            allocation.updatedAt = dto.updatedAt
            context.insert(allocation)
        }
    }

    @discardableResult
    private func insertRecurringPaymentDefinitions(
        _ dtos: [BackupRecurringPaymentDefinitionDTO],
        categories: [UUID: SwiftDataCategory],
        context: ModelContext,
    ) throws -> [UUID: SwiftDataRecurringPaymentDefinition] {
        var result: [UUID: SwiftDataRecurringPaymentDefinition] = [:]
        for dto in dtos {
            let definition = SwiftDataRecurringPaymentDefinition(
                id: dto.id,
                name: dto.name,
                notes: dto.notes,
                amount: dto.amount,
                recurrenceIntervalMonths: dto.recurrenceIntervalMonths,
                firstOccurrenceDate: dto.firstOccurrenceDate,
                endDate: dto.endDate,
                leadTimeMonths: dto.leadTimeMonths,
                category: dto.categoryId.flatMap { categories[$0] },
                savingStrategy: dto.savingStrategy,
                customMonthlySavingAmount: dto.customMonthlySavingAmount,
                dateAdjustmentPolicy: dto.dateAdjustmentPolicy,
                recurrenceDayPattern: dto.recurrenceDayPattern,
            )
            definition.createdAt = dto.createdAt
            definition.updatedAt = dto.updatedAt
            context.insert(definition)
            result[dto.id] = definition
        }
        return result
    }

    private func insertRecurringPaymentOccurrences(
        _ dtos: [BackupRecurringPaymentOccurrenceDTO],
        definitions: [UUID: SwiftDataRecurringPaymentDefinition],
        transactions: [UUID: SwiftDataTransaction],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            guard let definition = definitions[dto.definitionId] else { continue }
            let occurrence = SwiftDataRecurringPaymentOccurrence(
                id: dto.id,
                definition: definition,
                scheduledDate: dto.scheduledDate,
                expectedAmount: dto.expectedAmount,
                status: dto.status,
                actualDate: dto.actualDate,
                actualAmount: dto.actualAmount,
                transaction: dto.transactionId.flatMap { transactions[$0] },
            )
            occurrence.createdAt = dto.createdAt
            occurrence.updatedAt = dto.updatedAt
            context.insert(occurrence)
        }
    }

    private func insertRecurringPaymentSavingBalances(
        _ dtos: [BackupRecurringPaymentSavingBalanceDTO],
        definitions: [UUID: SwiftDataRecurringPaymentDefinition],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            guard let definition = definitions[dto.definitionId] else { continue }
            let balance = SwiftDataRecurringPaymentSavingBalance(
                id: dto.id,
                definition: definition,
                totalSavedAmount: dto.totalSavedAmount,
                totalPaidAmount: dto.totalPaidAmount,
                lastUpdatedYear: dto.lastUpdatedYear,
                lastUpdatedMonth: dto.lastUpdatedMonth,
            )
            balance.createdAt = dto.createdAt
            balance.updatedAt = dto.updatedAt
            context.insert(balance)
        }
    }

    // MARK: - Helpers

    private nonisolated func makeFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Backup.fileDateFormat
        formatter.locale = Foundation.Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "\(AppConstants.Backup.filePrefix)\(timestamp).\(AppConstants.Backup.fileExtension)"
    }
}

// MARK: - Payload DTOs

internal struct BackupPayload: Codable, Sendable {
    internal let metadata: BackupMetadata
    internal let transactions: [BackupTransactionDTO]
    internal let categories: [BackupCategory]
    internal let budgets: [BackupBudgetDTO]
    internal let annualBudgetConfigs: [BackupAnnualBudgetConfig]
    internal let annualBudgetAllocations: [BackupAnnualBudgetAllocationDTO]
    internal let financialInstitutions: [BackupFinancialInstitutionDTO]
    internal let recurringPaymentDefinitions: [BackupRecurringPaymentDefinitionDTO]
    internal let recurringPaymentOccurrences: [BackupRecurringPaymentOccurrenceDTO]
    internal let recurringPaymentSavingBalances: [BackupRecurringPaymentSavingBalanceDTO]
    internal let customHolidays: [BackupCustomHolidayDTO]
}

internal struct BackupTransactionDTO: Codable {
    internal let id: UUID
    internal let date: Date
    internal let title: String
    internal let amount: Decimal
    internal let memo: String
    internal let isIncludedInCalculation: Bool
    internal let isTransfer: Bool
    internal let financialInstitutionId: UUID?
    internal let majorCategoryId: UUID?
    internal let minorCategoryId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(transaction: SwiftDataTransaction) {
        self.id = transaction.id
        self.date = transaction.date
        self.title = transaction.title
        self.amount = transaction.amount
        self.memo = transaction.memo
        self.isIncludedInCalculation = transaction.isIncludedInCalculation
        self.isTransfer = transaction.isTransfer
        self.financialInstitutionId = transaction.financialInstitution?.id
        self.majorCategoryId = transaction.majorCategory?.id
        self.minorCategoryId = transaction.minorCategory?.id
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
    }
}

internal struct BackupCategory: Codable {
    internal let id: UUID
    internal let name: String
    internal let parentId: UUID?
    internal let allowsAnnualBudget: Bool
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(category: SwiftDataCategory) {
        self.id = category.id
        self.name = category.name
        self.parentId = category.parent?.id
        self.allowsAnnualBudget = category.allowsAnnualBudget
        self.displayOrder = category.displayOrder
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
    }
}

internal struct BackupBudgetDTO: Codable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(budget: SwiftDataBudget) {
        self.id = budget.id
        self.amount = budget.amount
        self.categoryId = budget.category?.id
        self.startYear = budget.startYear
        self.startMonth = budget.startMonth
        self.endYear = budget.endYear
        self.endMonth = budget.endMonth
        self.createdAt = budget.createdAt
        self.updatedAt = budget.updatedAt
    }
}

internal struct BackupAnnualBudgetConfig: Codable {
    internal let id: UUID
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policyRawValue: String
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(config: SwiftDataAnnualBudgetConfig) {
        self.id = config.id
        self.year = config.year
        self.totalAmount = config.totalAmount
        self.policyRawValue = config.policy.rawValue
        self.createdAt = config.createdAt
        self.updatedAt = config.updatedAt
    }

    internal var policy: AnnualBudgetPolicy {
        AnnualBudgetPolicy(rawValue: policyRawValue) ?? .automatic
    }
}

internal struct BackupFinancialInstitutionDTO: Codable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(institution: SwiftDataFinancialInstitution) {
        self.id = institution.id
        self.name = institution.name
        self.displayOrder = institution.displayOrder
        self.createdAt = institution.createdAt
        self.updatedAt = institution.updatedAt
    }
}

internal struct BackupAnnualBudgetAllocationDTO: Codable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID
    internal let policyOverrideRawValue: String?
    internal let configId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(allocation: SwiftDataAnnualBudgetAllocation) {
        self.id = allocation.id
        self.amount = allocation.amount
        self.categoryId = allocation.category.id
        self.policyOverrideRawValue = allocation.policyOverrideRawValue
        self.configId = allocation.config?.id
        self.createdAt = allocation.createdAt
        self.updatedAt = allocation.updatedAt
    }
}

internal struct BackupRecurringPaymentDefinitionDTO: Codable {
    internal let id: UUID
    internal let name: String
    internal let notes: String
    internal let amount: Decimal
    internal let recurrenceIntervalMonths: Int
    internal let firstOccurrenceDate: Date
    internal let endDate: Date?
    internal let leadTimeMonths: Int
    internal let categoryId: UUID?
    internal let savingStrategy: RecurringPaymentSavingStrategy
    internal let customMonthlySavingAmount: Decimal?
    internal let dateAdjustmentPolicy: DateAdjustmentPolicy
    internal let recurrenceDayPattern: DayOfMonthPattern?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(definition: SwiftDataRecurringPaymentDefinition) {
        self.id = definition.id
        self.name = definition.name
        self.notes = definition.notes
        self.amount = definition.amount
        self.recurrenceIntervalMonths = definition.recurrenceIntervalMonths
        self.firstOccurrenceDate = definition.firstOccurrenceDate
        self.endDate = definition.endDate
        self.leadTimeMonths = definition.leadTimeMonths
        self.categoryId = definition.category?.id
        self.savingStrategy = definition.savingStrategy
        self.customMonthlySavingAmount = definition.customMonthlySavingAmount
        self.dateAdjustmentPolicy = definition.dateAdjustmentPolicy
        self.recurrenceDayPattern = definition.recurrenceDayPattern
        self.createdAt = definition.createdAt
        self.updatedAt = definition.updatedAt
    }
}

internal struct BackupRecurringPaymentOccurrenceDTO: Codable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let scheduledDate: Date
    internal let expectedAmount: Decimal
    internal let status: RecurringPaymentStatus
    internal let actualDate: Date?
    internal let actualAmount: Decimal?
    internal let transactionId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(occurrence: SwiftDataRecurringPaymentOccurrence) {
        self.id = occurrence.id
        self.definitionId = occurrence.definitionId
        self.scheduledDate = occurrence.scheduledDate
        self.expectedAmount = occurrence.expectedAmount
        self.status = occurrence.status
        self.actualDate = occurrence.actualDate
        self.actualAmount = occurrence.actualAmount
        self.transactionId = occurrence.transaction?.id
        self.createdAt = occurrence.createdAt
        self.updatedAt = occurrence.updatedAt
    }
}

internal struct BackupRecurringPaymentSavingBalanceDTO: Codable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let totalSavedAmount: Decimal
    internal let totalPaidAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(balance: SwiftDataRecurringPaymentSavingBalance) {
        self.id = balance.id
        self.definitionId = balance.definition.id
        self.totalSavedAmount = balance.totalSavedAmount
        self.totalPaidAmount = balance.totalPaidAmount
        self.lastUpdatedYear = balance.lastUpdatedYear
        self.lastUpdatedMonth = balance.lastUpdatedMonth
        self.createdAt = balance.createdAt
        self.updatedAt = balance.updatedAt
    }
}

internal struct BackupCustomHolidayDTO: Codable {
    internal let id: UUID
    internal let date: Date
    internal let name: String
    internal let isRecurring: Bool
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(holiday: SwiftDataCustomHoliday) {
        self.id = holiday.id
        self.date = holiday.date
        self.name = holiday.name
        self.isRecurring = holiday.isRecurring
        self.createdAt = holiday.createdAt
        self.updatedAt = holiday.updatedAt
    }
}

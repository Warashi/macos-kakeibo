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
    internal let financialInstitutions: Int
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
        let transactions = try modelContext.fetchAll(TransactionEntity.self)
        let categories = try modelContext.fetchAll(CategoryEntity.self)
        let budgets = try modelContext.fetchAll(BudgetEntity.self)
        let configs = try modelContext.fetchAll(AnnualBudgetConfigEntity.self)
        let institutions = try modelContext.fetchAll(FinancialInstitutionEntity.self)

        let metadata = BackupMetadata(
            generatedAt: Date(),
            appVersion: AppConstants.App.version,
            build: AppConstants.App.build,
            recordCounts: BackupRecordCounts(
                transactions: transactions.count,
                categories: categories.count,
                budgets: budgets.count,
                annualBudgetConfigs: configs.count,
                financialInstitutions: institutions.count,
            ),
        )

        return BackupPayload(
            metadata: metadata,
            transactions: transactions.map(BackupTransactionDTO.init),
            categories: categories.map(BackupCategory.init),
            budgets: budgets.map(BackupBudgetDTO.init),
            annualBudgetConfigs: configs.map(BackupAnnualBudgetConfig.init),
            financialInstitutions: institutions.map(BackupFinancialInstitutionDTO.init),
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

        let institutions = try insertFinancialInstitutions(payload.financialInstitutions, context: modelContext)
        let categories = try insertCategories(payload.categories, context: modelContext)
        try insertAnnualBudgetConfigs(payload.annualBudgetConfigs, context: modelContext)
        try insertBudgets(payload.budgets, categories: categories, context: modelContext)
        try insertTransactions(
            payload.transactions,
            categories: categories,
            institutions: institutions,
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
        try deleteAll(TransactionEntity.self, in: context)
        try deleteAll(BudgetEntity.self, in: context)
        try deleteAll(AnnualBudgetConfigEntity.self, in: context)
        try deleteCategoriesSafely(in: context)
        try deleteAll(FinancialInstitutionEntity.self, in: context)
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
        let descriptor: ModelFetchRequest<CategoryEntity> = ModelFetchFactory.make()
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
    ) throws -> [UUID: FinancialInstitutionEntity] {
        var result: [UUID: FinancialInstitutionEntity] = [:]
        for dto in dtos {
            let institution = FinancialInstitutionEntity(
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
    ) throws -> [UUID: CategoryEntity] {
        var result: [UUID: CategoryEntity] = [:]

        // まず全カテゴリを作成
        for dto in dtos {
            let category = CategoryEntity(
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
        categories: [UUID: CategoryEntity],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let budget = BudgetEntity(
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

    private func insertAnnualBudgetConfigs(
        _ dtos: [BackupAnnualBudgetConfig],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let config = AnnualBudgetConfigEntity(
                id: dto.id,
                year: dto.year,
                totalAmount: dto.totalAmount,
                policy: dto.policy,
            )
            config.createdAt = dto.createdAt
            config.updatedAt = dto.updatedAt
            context.insert(config)
        }
    }

    private func insertTransactions(
        _ dtos: [BackupTransactionDTO],
        categories: [UUID: CategoryEntity],
        institutions: [UUID: FinancialInstitutionEntity],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let transaction = TransactionEntity(
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
    internal let financialInstitutions: [BackupFinancialInstitutionDTO]
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

    internal init(transaction: TransactionEntity) {
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

    internal init(category: CategoryEntity) {
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

    internal init(budget: BudgetEntity) {
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

    internal init(config: AnnualBudgetConfigEntity) {
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

    internal init(institution: FinancialInstitutionEntity) {
        self.id = institution.id
        self.name = institution.name
        self.displayOrder = institution.displayOrder
        self.createdAt = institution.createdAt
        self.updatedAt = institution.updatedAt
    }
}

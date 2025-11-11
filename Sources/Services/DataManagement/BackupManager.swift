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

    /// バックアップペイロードを構築 (MainActor で呼び出す)
    @MainActor
    internal static func buildPayload(modelContext: ModelContext) throws -> BackupPayload {
        let transactions = try modelContext.fetchAll(Transaction.self)
        let categories = try modelContext.fetchAll(Category.self)
        let budgets = try modelContext.fetchAll(Budget.self)
        let configs = try modelContext.fetchAll(AnnualBudgetConfig.self)
        let institutions = try modelContext.fetchAll(FinancialInstitution.self)

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
            transactions: transactions.map(TransactionDTO.init),
            categories: categories.map(CategoryDTO.init),
            budgets: budgets.map(BudgetDTO.init),
            annualBudgetConfigs: configs.map(AnnualBudgetConfigDTO.init),
            financialInstitutions: institutions.map(FinancialInstitutionDTO.init),
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

    /// ペイロードからデータを復元 (MainActor で呼び出す)
    @MainActor
    internal static func restorePayload(_ payload: BackupPayload, to modelContext: ModelContext) throws
    -> BackupRestoreSummary {
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

    @MainActor
    private static func clearAllData(in context: ModelContext) throws {
        try deleteAll(Transaction.self, in: context)
        try deleteAll(Budget.self, in: context)
        try deleteAll(AnnualBudgetConfig.self, in: context)
        try deleteCategoriesSafely(in: context)
        try deleteAll(FinancialInstitution.self, in: context)
    }

    @MainActor
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }

    /// 親子関係を維持しながらカテゴリを削除
    @MainActor
    private static func deleteCategoriesSafely(in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<Category> = ModelFetchFactory.make()
        let categories = try context.fetch(descriptor)
        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)

        for category in minors + majors {
            context.delete(category)
        }
    }

    // MARK: - Insert

    @discardableResult
    @MainActor
    private static func insertFinancialInstitutions(
        _ dtos: [FinancialInstitutionDTO],
        context: ModelContext,
    ) throws -> [UUID: FinancialInstitution] {
        var result: [UUID: FinancialInstitution] = [:]
        for dto in dtos {
            let institution = FinancialInstitution(
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
    @MainActor
    private static func insertCategories(
        _ dtos: [CategoryDTO],
        context: ModelContext,
    ) throws -> [UUID: Category] {
        var result: [UUID: Category] = [:]

        // まず全カテゴリを作成
        for dto in dtos {
            let category = Category(
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

    @MainActor
    private static func insertBudgets(
        _ dtos: [BudgetDTO],
        categories: [UUID: Category],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let budget = Budget(
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

    @MainActor
    private static func insertAnnualBudgetConfigs(
        _ dtos: [AnnualBudgetConfigDTO],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let config = AnnualBudgetConfig(
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

    @MainActor
    private static func insertTransactions(
        _ dtos: [TransactionDTO],
        categories: [UUID: Category],
        institutions: [UUID: FinancialInstitution],
        context: ModelContext,
    ) throws {
        for dto in dtos {
            let transaction = Transaction(
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
    internal let transactions: [TransactionDTO]
    internal let categories: [CategoryDTO]
    internal let budgets: [BudgetDTO]
    internal let annualBudgetConfigs: [AnnualBudgetConfigDTO]
    internal let financialInstitutions: [FinancialInstitutionDTO]
}

internal struct TransactionDTO: Codable {
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

    internal init(transaction: Transaction) {
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

internal struct CategoryDTO: Codable {
    internal let id: UUID
    internal let name: String
    internal let parentId: UUID?
    internal let allowsAnnualBudget: Bool
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(category: Category) {
        self.id = category.id
        self.name = category.name
        self.parentId = category.parent?.id
        self.allowsAnnualBudget = category.allowsAnnualBudget
        self.displayOrder = category.displayOrder
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
    }
}

internal struct BudgetDTO: Codable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(budget: Budget) {
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

internal struct AnnualBudgetConfigDTO: Codable {
    internal let id: UUID
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policyRawValue: String
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(config: AnnualBudgetConfig) {
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

internal struct FinancialInstitutionDTO: Codable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(institution: FinancialInstitution) {
        self.id = institution.id
        self.name = institution.name
        self.displayOrder = institution.displayOrder
        self.createdAt = institution.createdAt
        self.updatedAt = institution.updatedAt
    }
}

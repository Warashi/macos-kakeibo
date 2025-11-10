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
@MainActor
internal final class BackupManager {
    /// バックアップを生成
    /// - Parameter modelContext: SwiftDataのModelContext
    /// - Returns: バックアップデータとメタデータ
    internal func createBackup(modelContext: ModelContext) throws -> BackupArchive {
        let payload = try buildPayload(modelContext: modelContext)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let fileName = makeFileName(for: payload.metadata.generatedAt)
        return BackupArchive(data: data, metadata: payload.metadata, suggestedFileName: fileName)
    }

    /// バックアップからデータを復元
    /// - Parameters:
    ///   - data: バックアップデータ
    ///   - modelContext: SwiftDataのModelContext
    /// - Returns: リストア結果
    internal func restoreBackup(from data: Data, modelContext: ModelContext) throws -> BackupRestoreSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else {
            throw BackupManagerError.decodingFailed
        }

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

    // MARK: - Payload

    private func buildPayload(modelContext: ModelContext) throws -> BackupPayload {
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

    // MARK: - Clear

    private func clearAllData(in context: ModelContext) throws {
        try deleteAll(Transaction.self, in: context)
        try deleteAll(Budget.self, in: context)
        try deleteAll(AnnualBudgetConfig.self, in: context)
        try deleteCategoriesSafely(in: context)
        try deleteAll(FinancialInstitution.self, in: context)
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
    private func insertFinancialInstitutions(
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
    private func insertCategories(
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

    private func insertBudgets(
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

    private func insertAnnualBudgetConfigs(
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

    private func insertTransactions(
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

    private func makeFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Backup.fileDateFormat
        formatter.locale = Foundation.Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "\(AppConstants.Backup.filePrefix)\(timestamp).\(AppConstants.Backup.fileExtension)"
    }
}

// MARK: - Payload DTOs

private struct BackupPayload: Codable {
    let metadata: BackupMetadata
    let transactions: [TransactionDTO]
    let categories: [CategoryDTO]
    let budgets: [BudgetDTO]
    let annualBudgetConfigs: [AnnualBudgetConfigDTO]
    let financialInstitutions: [FinancialInstitutionDTO]
}

private struct TransactionDTO: Codable {
    let id: UUID
    let date: Date
    let title: String
    let amount: Decimal
    let memo: String
    let isIncludedInCalculation: Bool
    let isTransfer: Bool
    let financialInstitutionId: UUID?
    let majorCategoryId: UUID?
    let minorCategoryId: UUID?
    let createdAt: Date
    let updatedAt: Date

    init(transaction: Transaction) {
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

private struct CategoryDTO: Codable {
    let id: UUID
    let name: String
    let parentId: UUID?
    let allowsAnnualBudget: Bool
    let displayOrder: Int
    let createdAt: Date
    let updatedAt: Date

    init(category: Category) {
        self.id = category.id
        self.name = category.name
        self.parentId = category.parent?.id
        self.allowsAnnualBudget = category.allowsAnnualBudget
        self.displayOrder = category.displayOrder
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
    }
}

private struct BudgetDTO: Codable {
    let id: UUID
    let amount: Decimal
    let categoryId: UUID?
    let startYear: Int
    let startMonth: Int
    let endYear: Int
    let endMonth: Int
    let createdAt: Date
    let updatedAt: Date

    init(budget: Budget) {
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

private struct AnnualBudgetConfigDTO: Codable {
    let id: UUID
    let year: Int
    let totalAmount: Decimal
    let policyRawValue: String
    let createdAt: Date
    let updatedAt: Date

    init(config: AnnualBudgetConfig) {
        self.id = config.id
        self.year = config.year
        self.totalAmount = config.totalAmount
        self.policyRawValue = config.policy.rawValue
        self.createdAt = config.createdAt
        self.updatedAt = config.updatedAt
    }

    var policy: AnnualBudgetPolicy {
        AnnualBudgetPolicy(rawValue: policyRawValue) ?? .automatic
    }
}

private struct FinancialInstitutionDTO: Codable {
    let id: UUID
    let name: String
    let displayOrder: Int
    let createdAt: Date
    let updatedAt: Date

    init(institution: FinancialInstitution) {
        self.id = institution.id
        self.name = institution.name
        self.displayOrder = institution.displayOrder
        self.createdAt = institution.createdAt
        self.updatedAt = institution.updatedAt
    }
}

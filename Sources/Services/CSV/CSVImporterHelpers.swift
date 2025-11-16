import Foundation

// MARK: - Result Types

/// カテゴリ解決結果
internal struct CategoryResolutionResult {
    internal let majorCategory: CategoryDTO?
    internal let minorCategory: CategoryDTO?
    internal let createdCount: Int
}

/// トランザクション更新パラメータ
internal struct TransactionUpdateParameters {
    internal let draft: TransactionDraft
    internal let identifier: CSVTransactionIdentifier?
    internal let institution: FinancialInstitutionDTO?
    internal let majorCategory: CategoryDTO?
    internal let minorCategory: CategoryDTO?
    internal let existingImportIdentifier: String?
}

// MARK: - Import State

/// インポート処理の状態
internal struct ImportState {
    internal var importedCount: Int = 0
    internal var updatedCount: Int = 0
    internal var createdInstitutions: Int = 0
    internal var createdCategories: Int = 0
}

// MARK: - Cache

/// エンティティキャッシュ
internal struct EntityCache {
    internal var institutions: [String: FinancialInstitutionDTO] = [:]
    internal var majorCategories: [String: CategoryDTO] = [:]
    internal var minorCategories: [String: CategoryDTO] = [:]
}

// MARK: - Field Extraction Results

/// 必須フィールドの検証結果
internal struct RequiredFieldsResult {
    internal let date: Date
    internal let title: String
    internal let amount: Decimal
}

/// オプションフィールドの抽出結果
internal struct OptionalFieldsResult {
    internal let memo: String
    internal let financialInstitution: String?
    internal let majorCategory: String?
    internal let minorCategory: String?
}

// MARK: - Transaction Creation Parameters

/// トランザクション作成パラメータ
internal struct TransactionCreationParameters {
    internal let draft: TransactionDraft
    internal let identifier: CSVTransactionIdentifier?
    internal let institution: FinancialInstitutionDTO?
    internal let majorCategory: CategoryDTO?
    internal let minorCategory: CategoryDTO?
}

// MARK: - Category Resolution Context

/// カテゴリ解決用コンテキスト
internal struct CategoryResolutionContext {
    internal let majorName: String?
    internal let minorName: String?
    internal var majorCache: [String: CategoryDTO]
    internal var minorCache: [String: CategoryDTO]
}

/// 中項目カテゴリ解決用コンテキスト
internal struct MinorCategoryResolutionContext {
    internal let name: String?
    internal let majorCategory: CategoryDTO?
    internal var cache: [String: CategoryDTO]
    internal var createdCount: Int
}

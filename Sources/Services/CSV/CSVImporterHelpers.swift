import Foundation

// MARK: - Result Types

/// カテゴリ解決結果
internal struct CategoryResolutionResult {
    internal let majorCategory: Category?
    internal let minorCategory: Category?
    internal let createdCount: Int
}

/// トランザクション更新パラメータ
internal struct TransactionUpdateParameters {
    internal let draft: TransactionDraft
    internal let identifier: CSVTransactionIdentifier?
    internal let institution: FinancialInstitution?
    internal let majorCategory: Category?
    internal let minorCategory: Category?
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
    internal var institutions: [String: FinancialInstitution] = [:]
    internal var majorCategories: [String: Category] = [:]
    internal var minorCategories: [String: Category] = [:]
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

// MARK: - TransactionEntity Creation Parameters

/// トランザクション作成パラメータ
internal struct TransactionCreationParameters {
    internal let draft: TransactionDraft
    internal let identifier: CSVTransactionIdentifier?
    internal let institution: FinancialInstitution?
    internal let majorCategory: Category?
    internal let minorCategory: Category?
}

// MARK: - Category Resolution Context

/// カテゴリ解決用コンテキスト
internal struct CategoryResolutionContext {
    internal let majorName: String?
    internal let minorName: String?
    internal var majorCache: [String: Category]
    internal var minorCache: [String: Category]
}

/// 中項目カテゴリ解決用コンテキスト
internal struct MinorCategoryResolutionContext {
    internal let name: String?
    internal let majorCategory: Category?
    internal var cache: [String: Category]
    internal var createdCount: Int
}

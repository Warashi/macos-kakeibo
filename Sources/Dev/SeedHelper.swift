#if DEBUG
import Foundation
import SwiftData

/// 開発・デバッグ用のデータ投入ヘルパー
internal enum SeedHelper {
    /// サンプルデータをModelContainerに投入する
    /// - Parameter container: 対象のModelContainer
    /// - Throws: データ投入時のエラー
    internal static func seedSampleData(to container: ModelContainer) throws {
        let context = ModelContext(container)

        // 既存データをクリア（開発環境でのみ実行）
        try clearAllData(in: context)

        // 金融機関を投入
        let institutions = SampleData.financialInstitutions()
        for institution in institutions {
            context.insert(institution)
        }

        // カテゴリを投入
        let categories = SampleData.createSampleCategories()
        for category in categories {
            context.insert(category)
        }

        // 保存して、カテゴリのIDを確定
        try context.save()

        // 取引を投入
        let transactions = SampleData.createSampleTransactions(
            categories: categories,
            institutions: institutions,
        )
        for transaction in transactions {
            context.insert(transaction)
        }

        // 予算を投入
        let budgets = SampleData.createSampleBudgets(categories: categories)
        for budget in budgets {
            context.insert(budget)
        }

        // 年次特別枠設定を投入
        let annualConfig = SampleData.createSampleAnnualBudgetConfig()
        context.insert(annualConfig)

        // 最終保存
        try context.save()
    }

    /// 金融機関のみをModelContainerに投入する
    /// - Parameter container: 対象のModelContainer
    /// - Throws: データ投入時のエラー
    internal static func seedFinancialInstitutions(to container: ModelContainer) throws {
        let context = ModelContext(container)

        let institutions = SampleData.financialInstitutions()
        for institution in institutions {
            context.insert(institution)
        }

        try context.save()
    }

    /// カテゴリのみをModelContainerに投入する
    /// - Parameter container: 対象のModelContainer
    /// - Throws: データ投入時のエラー
    internal static func seedCategories(to container: ModelContainer) throws {
        let context = ModelContext(container)

        let categories = SampleData.createSampleCategories()
        for category in categories {
            context.insert(category)
        }

        try context.save()
    }

    /// すべてのデータをクリアする
    /// - Parameter context: 対象のModelContext
    /// - Throws: データ削除時のエラー
    internal static func clearAllData(in context: ModelContext) throws {
        // 削除は依存関係の逆順で行う
        try context.delete(model: TransactionEntity.self)
        try context.delete(model: BudgetEntity.self)
        try context.delete(model: AnnualBudgetConfigEntity.self)
        try deleteCategoriesSafely(in: context)
        try context.delete(model: FinancialInstitutionEntity.self)

        try context.save()
    }

    /// 親子関係を考慮しながらカテゴリを削除する
    /// SwiftDataのバッチ削除では親子リンクのnullifyが許容されないため個別に削除する
    /// - Parameter context: 対象のModelContext
    private static func deleteCategoriesSafely(in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<CategoryEntity> = ModelFetchFactory.make()
        let categories = try context.fetch(descriptor)

        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)

        for category in minors + majors {
            context.delete(category)
        }
    }

    /// 指定したモデルのデータをカウントする
    /// - Parameters:
    ///   - modelType: カウント対象のモデル型
    ///   - container: 対象のModelContainer
    /// - Returns: データ件数
    internal static func count<T: PersistentModel>(_ modelType: T.Type, in container: ModelContainer) -> Int {
        let context = ModelContext(container)
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()

        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
#endif

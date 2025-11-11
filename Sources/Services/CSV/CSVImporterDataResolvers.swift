import Foundation
import SwiftData

// MARK: - Data Resolution Extensions

extension CSVImporter {
    /// 金融機関を解決（存在すればキャッシュから、なければデータベースから、最後に新規作成）
    @MainActor
    internal func resolveFinancialInstitution(
        named name: String?,
        cache: inout [String: FinancialInstitution],
        modelContext: ModelContext,
    ) throws -> (FinancialInstitution?, Bool) {
        guard let name else {
            return (nil, false)
        }

        let key = name.lowercased()
        if let cached = cache[key] {
            return (cached, false)
        }

        let descriptor = FinancialInstitutionQueries.byName(name)

        if let existing = try modelContext.fetch(descriptor).first {
            cache[key] = existing
            return (existing, false)
        }

        let institution = FinancialInstitution(name: name)
        modelContext.insert(institution)
        cache[key] = institution
        return (institution, true)
    }

    /// カテゴリを解決（大項目と中項目）
    @MainActor
    internal func resolveCategories(
        context: inout CategoryResolutionContext,
    ) throws -> CategoryResolutionResult {
        var createdCount = 0

        let majorCategory = try resolveMajorCategory(
            name: context.majorName,
            cache: &context.majorCache,
            createdCount: &createdCount,
            modelContext: context.modelContext,
        )

        var minorContext = MinorCategoryResolutionContext(
            name: context.minorName,
            majorCategory: majorCategory,
            cache: context.minorCache,
            createdCount: createdCount,
            modelContext: context.modelContext,
        )
        let minorCategory = try resolveMinorCategory(context: &minorContext)
        context.minorCache = minorContext.cache

        return CategoryResolutionResult(
            majorCategory: majorCategory,
            minorCategory: minorCategory,
            createdCount: minorContext.createdCount,
        )
    }

    /// 大項目カテゴリを解決
    @MainActor
    internal func resolveMajorCategory(
        name: String?,
        cache: inout [String: Category],
        createdCount: inout Int,
        modelContext: ModelContext,
    ) throws -> Category? {
        guard let name else {
            return nil
        }

        let key = name.lowercased()
        if let cached = cache[key] {
            return cached
        }

        let descriptor = CategoryQueries.firstMatching(
            predicate: #Predicate { category in
                category.name == name && category.parent == nil
            },
        )

        if let existing = try modelContext.fetch(descriptor).first {
            cache[key] = existing
            return existing
        }

        let newCategory = Category(name: name)
        modelContext.insert(newCategory)
        cache[key] = newCategory
        createdCount += 1
        return newCategory
    }

    /// 中項目カテゴリを解決
    @MainActor
    internal func resolveMinorCategory(
        context: inout MinorCategoryResolutionContext,
    ) throws -> Category? {
        guard let name = context.name, let majorCategory = context.majorCategory else {
            return nil
        }

        let key = "\(majorCategory.id.uuidString.lowercased())::\(name.lowercased())"
        if let cached = context.cache[key] {
            return cached
        }

        let descriptor = ModelFetchFactory.make(
            predicate: #Predicate { (category: Category) in
                category.name == name
            },
        )

        let existing = try context.modelContext
            .fetch(descriptor)
            .first { (category: Category) in
                category.parent?.id == majorCategory.id
            }

        if let existing {
            context.cache[key] = existing
            return existing
        }

        let newCategory = Category(name: name, parent: majorCategory)
        context.modelContext.insert(newCategory)
        context.cache[key] = newCategory
        context.createdCount += 1
        return newCategory
    }

    /// IDでトランザクションを検索
    @MainActor
    internal func fetchTransaction(id: UUID, modelContext: ModelContext) throws -> Transaction? {
        try modelContext.fetch(TransactionQueries.byId(id)).first
    }

    /// インポート識別子でトランザクションを検索
    @MainActor
    internal func fetchTransaction(importIdentifier: String, modelContext: ModelContext) throws -> Transaction? {
        try modelContext.fetch(
            TransactionQueries.byImportIdentifier(importIdentifier),
        )
        .first
    }
}

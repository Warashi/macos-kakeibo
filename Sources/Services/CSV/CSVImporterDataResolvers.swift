import Foundation
import SwiftData

// MARK: - Data Resolution Extensions

extension CSVImporter {
    /// 金融機関を解決（存在すればキャッシュから、なければデータベースから、最後に新規作成）
    internal func resolveFinancialInstitution(
        named name: String?,
        cache: inout [String: FinancialInstitution],
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
    internal func resolveCategories(
        majorName: String?,
        minorName: String?,
        majorCache: inout [String: Category],
        minorCache: inout [String: Category],
    ) throws -> CategoryResolutionResult {
        var createdCount = 0

        let majorCategory = try resolveMajorCategory(
            name: majorName,
            cache: &majorCache,
            createdCount: &createdCount,
        )

        let minorCategory = try resolveMinorCategory(
            name: minorName,
            majorCategory: majorCategory,
            cache: &minorCache,
            createdCount: &createdCount,
        )

        return CategoryResolutionResult(
            majorCategory: majorCategory,
            minorCategory: minorCategory,
            createdCount: createdCount,
        )
    }

    /// 大項目カテゴリを解決
    internal func resolveMajorCategory(
        name: String?,
        cache: inout [String: Category],
        createdCount: inout Int,
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
    internal func resolveMinorCategory(
        name: String?,
        majorCategory: Category?,
        cache: inout [String: Category],
        createdCount: inout Int,
    ) throws -> Category? {
        guard let name, let majorCategory else {
            return nil
        }

        let key = "\(majorCategory.id.uuidString.lowercased())::\(name.lowercased())"
        if let cached = cache[key] {
            return cached
        }

        let descriptor = ModelFetchFactory.make(
            predicate: #Predicate { (category: Category) in
                category.name == name
            },
        )

        let existing = try modelContext
            .fetch(descriptor)
            .first { (category: Category) in
                category.parent?.id == majorCategory.id
            }

        if let existing {
            cache[key] = existing
            return existing
        }

        let newCategory = Category(name: name, parent: majorCategory)
        modelContext.insert(newCategory)
        cache[key] = newCategory
        createdCount += 1
        return newCategory
    }

    /// IDでトランザクションを検索
    internal func fetchTransaction(id: UUID) throws -> Transaction? {
        try modelContext.fetch(TransactionQueries.byId(id)).first
    }

    /// インポート識別子でトランザクションを検索
    internal func fetchTransaction(importIdentifier: String) throws -> Transaction? {
        try modelContext.fetch(
            TransactionQueries.byImportIdentifier(importIdentifier),
        )
        .first
    }
}

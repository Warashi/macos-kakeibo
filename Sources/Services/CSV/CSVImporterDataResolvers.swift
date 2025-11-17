import Foundation

// MARK: - Data Resolution Extensions

extension CSVImporter {
    /// 金融機関を解決（存在すればキャッシュから、なければデータベースから、最後に新規作成）
    internal func resolveFinancialInstitution(
        named name: String?,
        cache: inout [String: FinancialInstitution],
    ) async throws -> (FinancialInstitution?, Bool) {
        guard let name else {
            return (nil, false)
        }

        let key = name.lowercased()
        if let cached = cache[key] {
            return (cached, false)
        }

        if let existing = try await budgetRepository.findInstitutionByName(name) {
            cache[key] = existing
            return (existing, false)
        }

        _ = try await budgetRepository.createInstitution(name: name)
        guard let institution = try await budgetRepository.findInstitutionByName(name) else {
            throw RepositoryError.notFound
        }
        cache[key] = institution
        return (institution, true)
    }

    /// カテゴリを解決（大項目と中項目）
    internal func resolveCategories(
        context: inout CategoryResolutionContext,
    ) async throws -> CategoryResolutionResult {
        var createdCount = 0

        let majorCategory = try await resolveMajorCategory(
            name: context.majorName,
            cache: &context.majorCache,
            createdCount: &createdCount,
        )

        var minorContext = MinorCategoryResolutionContext(
            name: context.minorName,
            majorCategory: majorCategory,
            cache: context.minorCache,
            createdCount: createdCount,
        )
        let minorCategory = try await resolveMinorCategory(context: &minorContext)
        context.minorCache = minorContext.cache

        return CategoryResolutionResult(
            majorCategory: majorCategory,
            minorCategory: minorCategory,
            createdCount: minorContext.createdCount,
        )
    }

    /// 大項目カテゴリを解決
    internal func resolveMajorCategory(
        name: String?,
        cache: inout [String: Category],
        createdCount: inout Int,
    ) async throws -> Category? {
        guard let name else {
            return nil
        }

        let key = name.lowercased()
        if let cached = cache[key] {
            return cached
        }

        if let existing = try await budgetRepository.findCategoryByName(name, parentId: nil) {
            cache[key] = existing
            return existing
        }

        let categoryId = try await budgetRepository.createCategory(name: name, parentId: nil)
        guard let newCategory = try await budgetRepository.category(id: categoryId) else {
            throw RepositoryError.notFound
        }
        cache[key] = newCategory
        createdCount += 1
        return newCategory
    }

    /// 中項目カテゴリを解決
    internal func resolveMinorCategory(
        context: inout MinorCategoryResolutionContext,
    ) async throws -> Category? {
        guard let name = context.name, let majorCategory = context.majorCategory else {
            return nil
        }

        let key = "\(majorCategory.id.uuidString.lowercased())::\(name.lowercased())"
        if let cached = context.cache[key] {
            return cached
        }

        if let existing = try await budgetRepository.findCategoryByName(name, parentId: majorCategory.id) {
            context.cache[key] = existing
            return existing
        }

        let categoryId = try await budgetRepository.createCategory(name: name, parentId: majorCategory.id)
        guard let newCategory = try await budgetRepository.category(id: categoryId) else {
            throw RepositoryError.notFound
        }
        context.cache[key] = newCategory
        context.createdCount += 1
        return newCategory
    }
}

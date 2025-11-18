import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataBudgetRepositoryCategoryInstitution", .serialized)
internal struct SwiftDataBudgetRepositoryCategoryInstitutionTests {
    @Test("親情報付きでカテゴリを検索できる")
    internal func findsCategoryByNameWithParent() async throws {
        let (repository, context) = try await makeRepository()
        let major = SwiftDataCategory(name: "食費")
        let minor = SwiftDataCategory(name: "外食", parent: major)
        context.insert(major)
        context.insert(minor)
        try context.save()

        let foundMinor = try await repository.findCategoryByName("外食", parentId: major.id)
        #expect(foundMinor?.id == minor.id)

        let foundMajor = try await repository.findCategoryByName("食費", parentId: nil)
        #expect(foundMajor?.id == major.id)
    }

    @Test("親子カテゴリを作成できる")
    internal func createsCategoryHierarchy() async throws {
        let (repository, context) = try await makeRepository()

        let majorId = try await repository.createCategory(name: "食費", parentId: nil)
        let minorId = try await repository.createCategory(name: "外食", parentId: majorId)
        try await repository.saveChanges()

        let major = try context.fetch(CategoryQueries.byId(majorId)).first
        #expect(major?.name == "食費")
        #expect(major?.parent == nil)

        let minor = try context.fetch(CategoryQueries.byId(minorId)).first
        #expect(minor?.name == "外食")
        #expect(minor?.parent?.id == majorId)
    }

    @Test("金融機関を名前で検索できる")
    internal func findsInstitutionByName() async throws {
        let (repository, context) = try await makeRepository()
        let institution = SwiftDataFinancialInstitution(name: "メイン口座")
        context.insert(institution)
        try context.save()

        let found = try await repository.findInstitutionByName("メイン口座")
        #expect(found?.id == institution.id)
    }

    @Test("金融機関を作成できる")
    internal func createsInstitution() async throws {
        let (repository, context) = try await makeRepository()

        let institutionId = try await repository.createInstitution(name: "サブ口座")
        try await repository.saveChanges()

        let stored = try context.fetch(FinancialInstitutionQueries.byId(institutionId)).first
        #expect(stored?.name == "サブ口座")
    }
}

private extension SwiftDataBudgetRepositoryCategoryInstitutionTests {
    func makeRepository() async throws -> (SwiftDataBudgetRepository, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataBudgetRepository(modelContainer: container)
        await repository.useSharedContext(context)
        return (repository, context)
    }
}

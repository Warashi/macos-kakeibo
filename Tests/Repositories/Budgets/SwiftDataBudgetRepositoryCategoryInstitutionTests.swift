import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataBudgetRepositoryCategoryInstitution", .serialized)
@DatabaseActor
internal struct SwiftDataBudgetRepositoryCategoryInstitutionTests {
    @Test("親情報付きでカテゴリを検索できる")
    internal func findsCategoryByNameWithParent() throws {
        let (repository, context) = try makeRepository()
        let major = Category(name: "食費")
        let minor = Category(name: "外食", parent: major)
        context.insert(major)
        context.insert(minor)
        try context.save()

        let foundMinor = try repository.findCategoryByName("外食", parentId: major.id)
        #expect(foundMinor?.id == minor.id)

        let foundMajor = try repository.findCategoryByName("食費", parentId: nil)
        #expect(foundMajor?.id == major.id)
    }

    @Test("親子カテゴリを作成できる")
    internal func createsCategoryHierarchy() throws {
        let (repository, context) = try makeRepository()

        let majorId = try repository.createCategory(name: "食費", parentId: nil)
        let minorId = try repository.createCategory(name: "外食", parentId: majorId)
        try repository.saveChanges()

        let major = try context.fetch(CategoryQueries.byId(majorId)).first
        #expect(major?.name == "食費")
        #expect(major?.parent == nil)

        let minor = try context.fetch(CategoryQueries.byId(minorId)).first
        #expect(minor?.name == "外食")
        #expect(minor?.parent?.id == majorId)
    }

    @Test("金融機関を名前で検索できる")
    internal func findsInstitutionByName() throws {
        let (repository, context) = try makeRepository()
        let institution = FinancialInstitution(name: "メイン口座")
        context.insert(institution)
        try context.save()

        let found = try repository.findInstitutionByName("メイン口座")
        #expect(found?.id == institution.id)
    }

    @Test("金融機関を作成できる")
    internal func createsInstitution() throws {
        let (repository, context) = try makeRepository()

        let institutionId = try repository.createInstitution(name: "サブ口座")
        try repository.saveChanges()

        let stored = try context.fetch(FinancialInstitutionQueries.byId(institutionId)).first
        #expect(stored?.name == "サブ口座")
    }
}

private extension SwiftDataBudgetRepositoryCategoryInstitutionTests {
    func makeRepository() throws -> (SwiftDataBudgetRepository, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataBudgetRepository(modelContext: context, modelContainer: container)
        return (repository, context)
    }
}

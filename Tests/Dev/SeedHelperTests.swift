import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SeedHelper Tests")
internal struct SeedHelperTests {
    // MARK: - データ投入テスト

    @Test("サンプルデータを投入できる")
    internal func seedSampleData() throws {
        let container = try ModelContainer.createInMemoryContainer()

        try SeedHelper.seedSampleData(to: container)

        // データが投入されたことを確認
        #expect(SeedHelper.count(FinancialInstitution.self, in: container) > 0)
        #expect(SeedHelper.count(Kakeibo.CategoryEntity.self, in: container) > 0)
        #expect(SeedHelper.count(Transaction.self, in: container) > 0)
        #expect(SeedHelper.count(Budget.self, in: container) > 0)
        #expect(SeedHelper.count(AnnualBudgetConfig.self, in: container) == 1)
    }

    @Test("金融機関のみを投入できる")
    internal func seedFinancialInstitutionsOnly() throws {
        let container = try ModelContainer.createInMemoryContainer()

        try SeedHelper.seedFinancialInstitutions(to: container)

        #expect(SeedHelper.count(FinancialInstitution.self, in: container) == 7)
        #expect(SeedHelper.count(Kakeibo.CategoryEntity.self, in: container) == 0)
        #expect(SeedHelper.count(Transaction.self, in: container) == 0)
    }

    @Test("カテゴリのみを投入できる")
    internal func seedCategoriesOnly() throws {
        let container = try ModelContainer.createInMemoryContainer()

        try SeedHelper.seedCategories(to: container)

        #expect(SeedHelper.count(Kakeibo.CategoryEntity.self, in: container) > 0)
        #expect(SeedHelper.count(FinancialInstitution.self, in: container) == 0)
        #expect(SeedHelper.count(Transaction.self, in: container) == 0)
    }

    // MARK: - データクリアテスト

    @Test("すべてのデータをクリアできる")
    internal func clearAllData() throws {
        let container = try ModelContainer.createInMemoryContainer()

        // まずデータを投入
        try SeedHelper.seedSampleData(to: container)
        #expect(SeedHelper.count(FinancialInstitution.self, in: container) > 0)

        // データをクリア
        let context = ModelContext(container)
        try SeedHelper.clearAllData(in: context)

        // すべてのデータが削除されたことを確認
        #expect(SeedHelper.count(FinancialInstitution.self, in: container) == 0)
        #expect(SeedHelper.count(Kakeibo.CategoryEntity.self, in: container) == 0)
        #expect(SeedHelper.count(Transaction.self, in: container) == 0)
        #expect(SeedHelper.count(Budget.self, in: container) == 0)
        #expect(SeedHelper.count(AnnualBudgetConfig.self, in: container) == 0)
    }

    // MARK: - カウントテスト

    @Test("データ件数を取得できる")
    internal func countData() throws {
        let container = try ModelContainer.createInMemoryContainer()

        // 初期状態は0件
        #expect(SeedHelper.count(FinancialInstitution.self, in: container) == 0)

        // データ投入後はカウントが増える
        try SeedHelper.seedFinancialInstitutions(to: container)
        let count = SeedHelper.count(FinancialInstitution.self, in: container)
        #expect(count == 7)
    }

    // MARK: - データ整合性テスト

    @Test("投入されたデータは整合性を保っている")
    internal func dataIntegrity() throws {
        let container = try ModelContainer.createInMemoryContainer()
        try SeedHelper.seedSampleData(to: container)

        let context = ModelContext(container)

        // すべての取引を取得
        let transactions = try context.fetchAll(Transaction.self)

        // すべての取引がバリデーションを通過することを確認
        for transaction in transactions {
            #expect(transaction.isValid)

            // カテゴリの整合性確認
            if let minor = transaction.minorCategory {
                #expect(transaction.majorCategory != nil)
                #expect(minor.parent === transaction.majorCategory)
            }
        }
    }

    @Test("投入されたカテゴリは親子関係を保っている")
    internal func categoryParentChildRelationship() throws {
        let container = try ModelContainer.createInMemoryContainer()
        try SeedHelper.seedCategories(to: container)

        let context = ModelContext(container)

        // すべてのカテゴリを取得
        let categories = try context.fetchAll(Kakeibo.CategoryEntity.self)

        // 中項目（子カテゴリ）は親を持つことを確認
        let minorCategories = categories.filter(\Kakeibo.CategoryEntity.isMinor)
        for minor in minorCategories {
            #expect(minor.parent != nil)
            #expect(minor.parent?.children.contains { $0.id == minor.id } == true)
        }

        // 大項目（親カテゴリ）は子を持つことを確認
        let majorCategories = categories.filter(\Kakeibo.CategoryEntity.isMajor)
        for major in majorCategories where !major.children.isEmpty {
            for child in major.children {
                #expect(child.parent?.id == major.id)
            }
        }
    }
}

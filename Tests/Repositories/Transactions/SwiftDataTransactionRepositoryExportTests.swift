import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataTransactionRepositoryExport", .serialized)
@DatabaseActor
internal struct SwiftDataTransactionRepositoryExportTests {
    @Test("CSVエクスポート用スナップショットを取得できる")
    internal func buildsSnapshot() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let institution = FinancialInstitutionEntity(name: "銀行")
        let major = CategoryEntity(name: "食費")
        let minor = CategoryEntity(name: "外食", parent: major)
        context.insert(institution)
        context.insert(major)
        context.insert(minor)
        try context.save()

        let repository = SwiftDataTransactionRepository(modelContainer: container)
        let input = TransactionInput(
            date: Date.from(year: 2025, month: 2, day: 1) ?? Date(),
            title: "ランチ",
            memo: "テスト",
            amount: Decimal(-1_200),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: institution.id,
            majorCategoryId: major.id,
            minorCategoryId: minor.id
        )
        _ = try repository.insert(input)
        try repository.saveChanges()

        let snapshot = try repository.fetchCSVExportSnapshot()

        #expect(snapshot.transactions.count == 1)
        #expect(snapshot.categories.contains(where: { $0.id == major.id }))
        #expect(snapshot.categories.contains(where: { $0.id == minor.id }))
        #expect(snapshot.institutions.contains(where: { $0.id == institution.id }))
        #expect(snapshot.referenceData.category(id: minor.id)?.name == "外食")
        #expect(snapshot.referenceData.institution(id: institution.id)?.name == "銀行")
    }
}

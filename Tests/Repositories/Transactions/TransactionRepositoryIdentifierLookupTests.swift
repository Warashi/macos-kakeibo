import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("TransactionRepositoryIdentifierLookup", .serialized)
internal struct TransactionRepositoryIdentifierLookupTests {
    @Test("SwiftData実装で識別子検索できる")
    @MainActor
    internal func swiftDataRepositoryFindsIdentifier() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = await SwiftDataTransactionRepository(modelContainer: container)

        let identifier = "IMPORT-001"
        let input = TransactionInput(
            date: Date(),
            title: "ランチ",
            memo: "",
            amount: -1200,
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
            importIdentifier: identifier
        )
        let createdId = try await repository.insert(input)
        try await repository.saveChanges()

        let found = try await repository.findByIdentifier(identifier)
        #expect(found?.id == createdId)
    }

    @Test("インメモリ実装で識別子検索できる")
    internal func inMemoryRepositoryFindsIdentifier() throws {
        let repository = InMemoryTransactionRepository()

        let input = TransactionInput(
            date: Date(),
            title: "買い物",
            memo: "",
            amount: -3000,
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
            importIdentifier: "IMPORT-002"
        )
        _ = try repository.insert(input)

        let found = try repository.findByIdentifier("IMPORT-002")
        #expect(found?.title == "買い物")
    }
}

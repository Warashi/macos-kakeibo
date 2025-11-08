@testable import Kakeibo
import Foundation
import SwiftData
import Testing

@Suite(.serialized)
@MainActor
internal struct BackupManagerTests {
    @Test("バックアップ生成で件数とファイル名が得られる")
    internal func createBackup_containsMetadata() async throws {
        // Given
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        try seedSampleData(in: context)
        let manager = BackupManager()

        // When
        let archive = try manager.createBackup(modelContext: context)

        // Then
        #expect(!archive.data.isEmpty)
        #expect(archive.metadata.recordCounts.transactions == 1)
        #expect(archive.metadata.recordCounts.categories == 2)
        #expect(archive.suggestedFileName.hasPrefix(AppConstants.Backup.filePrefix))
    }

    @Test("バックアップからのリストアでデータが再現される")
    internal func restoreBackup_recreatesData() async throws {
        // Given
        let sourceContainer = try ModelContainer.createInMemoryContainer()
        let sourceContext = ModelContext(sourceContainer)
        try seedSampleData(in: sourceContext)
        let manager = BackupManager()
        let archive = try manager.createBackup(modelContext: sourceContext)

        let restoreContainer = try ModelContainer.createInMemoryContainer()
        let restoreContext = ModelContext(restoreContainer)

        // When
        let summary = try manager.restoreBackup(from: archive.data, modelContext: restoreContext)

        // Then
        #expect(summary.restoredCounts.transactions == 1)
        #expect(try restoreContext.count(Transaction.self) == 1)
        #expect(try restoreContext.count(Category.self) == 2)
        #expect(try restoreContext.count(Budget.self) == 1)
        #expect(try restoreContext.count(FinancialInstitution.self) == 1)
    }
}

// MARK: - Helpers

@MainActor
private func seedSampleData(in context: ModelContext) throws {
    let institution = FinancialInstitution(name: "メインバンク", displayOrder: 1)
    let major = Category(name: "食費", allowsAnnualBudget: false, displayOrder: 1)
    let minor = Category(name: "外食", parent: major, allowsAnnualBudget: false, displayOrder: 1)
    let budget = Budget(amount: 50000, category: major, year: 2025, month: 11)
    let config = AnnualBudgetConfig(year: 2025, totalAmount: 100000, policy: .automatic)
    let transaction = Transaction(
        date: Date(),
        title: "テストディナー",
        amount: -8000,
        memo: "メモ",
        financialInstitution: institution,
        majorCategory: major,
        minorCategory: minor
    )

    context.insert(institution)
    context.insert(major)
    context.insert(minor)
    context.insert(budget)
    context.insert(config)
    context.insert(transaction)
    try context.save()
}

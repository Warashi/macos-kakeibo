import Foundation
@testable import Kakeibo
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
        let manager = BackupManager(
            backupRepository: SwiftDataBackupRepository(modelContainer: container),
        )

        // When
        let payload = try await manager.buildPayload()
        let archive = try await manager.createBackup(payload: payload)

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
        let backupManager = BackupManager(
            backupRepository: SwiftDataBackupRepository(modelContainer: sourceContainer),
        )
        let payload = try await backupManager.buildPayload()
        let archive = try await backupManager.createBackup(payload: payload)

        let restoreContainer = try ModelContainer.createInMemoryContainer()
        let restoreContext = ModelContext(restoreContainer)
        let restoreManager = BackupManager(
            backupRepository: SwiftDataBackupRepository(modelContainer: restoreContainer),
        )

        // When
        let decodedPayload = try await backupManager.decodeBackup(from: archive.data)
        let summary = try await restoreManager.restorePayload(decodedPayload)

        // Then
        #expect(summary.restoredCounts.transactions == 1)
        #expect(try restoreContext.count(SwiftDataTransaction.self) == 1)
        #expect(try restoreContext.count(SwiftDataCategory.self) == 2)
        #expect(try restoreContext.count(SwiftDataBudget.self) == 1)
        #expect(try restoreContext.count(SwiftDataFinancialInstitution.self) == 1)
    }
}

// MARK: - Helpers

@MainActor
private func seedSampleData(in context: ModelContext) throws {
    let institution = SwiftDataFinancialInstitution(name: "メインバンク", displayOrder: 1)
    let major = SwiftDataCategory(name: "食費", allowsAnnualBudget: false, displayOrder: 1)
    let minor = SwiftDataCategory(name: "外食", parent: major, allowsAnnualBudget: false, displayOrder: 1)
    let budget = SwiftDataBudget(amount: 50000, category: major, year: 2025, month: 11)
    let config = SwiftDataAnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
    let transaction = SwiftDataTransaction(
        date: Date(),
        title: "テストディナー",
        amount: -8000,
        memo: "メモ",
        financialInstitution: institution,
        majorCategory: major,
        minorCategory: minor,
    )

    context.insert(institution)
    context.insert(major)
    context.insert(minor)
    context.insert(budget)
    context.insert(config)
    context.insert(transaction)
    try context.save()
}

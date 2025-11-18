import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
internal struct RecurringPaymentStackBuilderTests {
    @Test("RecurringPaymentListStore を構築してエントリを読み込める")
    func makeListStoreLoadsEntries() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let now = Date()

        let input = RecurringPaymentDefinitionInput(
            name: "家賃",
            amount: Decimal(100_000),
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: now,
        )
        let definitionId = try await repository.createDefinition(input)
        _ = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: 1,
            referenceDate: now,
        )
        try await repository.saveChanges()

        let store = await RecurringPaymentStackBuilder.makeListStore(modelContainer: container)
        await store.refreshEntries()

        let entries = await MainActor.run { store.cachedEntries }
        #expect(entries.isEmpty == false)
    }

    @Test("RecurringPaymentReconciliationStore を構築して行を読み込める")
    func makeReconciliationStoreLoadsRows() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let now = Date()

        let input = RecurringPaymentDefinitionInput(
            name: "保険料",
            amount: Decimal(12000),
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: now,
        )
        let definitionId = try await repository.createDefinition(input)
        _ = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: 1,
            referenceDate: now,
        )
        try await repository.saveChanges()

        let transactionInput = TransactionInput(
            date: now,
            title: "保険料",
            memo: "",
            amount: Decimal(-12000),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
        _ = try await transactionRepository.insert(transactionInput)
        try await transactionRepository.saveChanges()

        let store = await RecurringPaymentStackBuilder.makeReconciliationStore(modelContainer: container)
        await store.refresh()

        let rows = await MainActor.run { store.rows }
        #expect(rows.isEmpty == false)
    }

    @Test("RecurringPaymentStore を構築して CRUD を実行できる")
    func makeStoreSupportsCRUD() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let store = await RecurringPaymentStackBuilder.makeStore(modelContainer: container)

        let input = RecurringPaymentDefinitionInput(
            name: "サブスクリプション",
            amount: Decimal(1200),
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date(),
        )
        try await store.createDefinition(input)

        let definitionId = try {
            let context = ModelContext(container)
            let existingDefinitions = try context.fetch(RecurringPaymentQueries.definitions())
            let identifier = try #require(existingDefinitions.first?.id)
            #expect(existingDefinitions.isEmpty == false)
            return identifier
        }()

        try await store.deleteDefinition(definitionId: definitionId)

        try {
            let context = ModelContext(container)
            let refreshedDefinitions = try context.fetch(RecurringPaymentQueries.definitions())
            #expect(refreshedDefinitions.isEmpty)
        }()
    }

    @Test("RecurringPaymentModelActor 経由でも ListStore を構築できる")
    func makeListStoreViaModelActor() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let modelActor = RecurringPaymentModelActor(modelContainer: container)
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let now = Date()

        let input = RecurringPaymentDefinitionInput(
            name: "通信費",
            amount: Decimal(5500),
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: now,
        )
        let definitionId = try await repository.createDefinition(input)
        _ = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: 1,
            referenceDate: now,
        )
        try await repository.saveChanges()

        let store = await RecurringPaymentStackBuilder.makeListStore(modelActor: modelActor)
        await store.refreshEntries()

        let entries = await MainActor.run { store.cachedEntries }
        #expect(entries.isEmpty == false)
    }

    @Test("RecurringPaymentModelActor 経由でも ReconciliationStore を構築できる")
    func makeReconciliationStoreViaModelActor() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let modelActor = RecurringPaymentModelActor(modelContainer: container)
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let now = Date()

        let input = RecurringPaymentDefinitionInput(
            name: "公共料金",
            amount: Decimal(7000),
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: now,
        )
        let definitionId = try await repository.createDefinition(input)
        _ = try await repository.synchronize(
            definitionId: definitionId,
            horizonMonths: 1,
            referenceDate: now,
        )
        try await repository.saveChanges()

        let transactionInput = TransactionInput(
            date: now,
            title: "公共料金",
            memo: "",
            amount: Decimal(-7000),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
        _ = try await transactionRepository.insert(transactionInput)
        try await transactionRepository.saveChanges()

        let store = await RecurringPaymentStackBuilder.makeReconciliationStore(modelActor: modelActor)
        await store.refresh()

        let rows = await MainActor.run { store.rows }
        #expect(rows.isEmpty == false)
    }

    @Test("RecurringPaymentModelActor 経由でも CRUD ストアを構築できる")
    func makeStoreViaModelActor() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let modelActor = RecurringPaymentModelActor(modelContainer: container)
        let store = await RecurringPaymentStackBuilder.makeStore(modelActor: modelActor)

        let input = RecurringPaymentDefinitionInput(
            name: "ジム",
            amount: Decimal(9800),
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: Date(),
        )
        try await store.createDefinition(input)

        let definitionId = try {
            let context = ModelContext(container)
            let definitions = try context.fetch(RecurringPaymentQueries.definitions())
            let identifier = try #require(definitions.first?.id)
            return identifier
        }()

        try await store.deleteDefinition(definitionId: definitionId)

        try {
            let context = ModelContext(container)
            let refreshedDefinitions = try context.fetch(RecurringPaymentQueries.definitions())
            #expect(refreshedDefinitions.isEmpty)
        }()
    }
}

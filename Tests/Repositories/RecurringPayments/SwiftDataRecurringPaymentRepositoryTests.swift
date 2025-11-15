import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("SwiftDataSpecialPaymentRepository")
@DatabaseActor
internal struct SwiftDataSpecialPaymentRepositoryTests {
    @Test("definitionsをカテゴリと検索でフィルタできる")
    internal func definitionsFilter() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSpecialPaymentRepository(modelContext: context)

        let housing = Category(name: "住宅")
        let dining = Category(name: "外食", parent: housing)
        context.insert(housing)
        context.insert(dining)

        let definitionWithCategory = try SpecialPaymentDefinition(
            name: "住宅ローン",
            amount: 200_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: #require(Date.from(year: 2025, month: 1, day: 1)),
            category: housing,
        )

        let definitionWithoutCategory = try SpecialPaymentDefinition(
            name: "旅行積立",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: #require(Date.from(year: 2025, month: 2, day: 1)),
        )

        context.insert(definitionWithCategory)
        context.insert(definitionWithoutCategory)
        try context.save()

        let filter = SpecialPaymentDefinitionFilter(
            searchText: "住宅",
            categoryIds: [housing.id],
        )

        let results = try repository.definitions(filter: filter)
        #expect(results.count == 1)
        #expect(results.first?.id == definitionWithCategory.id)
    }

    @Test("occurrencesを日付レンジとステータスでフィルタできる")
    internal func occurrencesFilter() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSpecialPaymentRepository(modelContext: context)

        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )

        let upcoming = try SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: #require(Date.from(year: 2025, month: 5, day: 31)),
            expectedAmount: 45000,
            status: .planned,
        )

        let completed = try SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: #require(Date.from(year: 2024, month: 5, day: 31)),
            expectedAmount: 42000,
            status: .completed,
            actualDate: #require(Date.from(year: 2024, month: 5, day: 30)),
            actualAmount: 42000,
        )

        definition.occurrences = [upcoming, completed]
        context.insert(definition)
        context.insert(upcoming)
        context.insert(completed)
        try context.save()

        let query = try SpecialPaymentOccurrenceQuery(
            range: SpecialPaymentOccurrenceRange(
                startDate: #require(Date.from(year: 2025, month: 1, day: 1)),
                endDate: #require(Date.from(year: 2025, month: 12, day: 31)),
            ),
            statusFilter: [.planned],
        )

        let results = try repository.occurrences(query: query)
        #expect(results.count == 1)
        #expect(results.first?.id == upcoming.id)
    }

    @Test("synchronizeでOccurrenceが生成される")
    internal func synchronizeCreatesOccurrences() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let repository = SwiftDataSpecialPaymentRepository(
            modelContext: context,
            currentDateProvider: { referenceDate },
        )

        let definition = SpecialPaymentDefinition(
            name: "保険料",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: referenceDate,
        )

        context.insert(definition)
        try context.save()

        let summary = try repository.synchronize(
            definitionId: definition.id,
            horizonMonths: 12,
            referenceDate: referenceDate,
        )

        #expect(summary.createdCount >= 2)
        #expect(definition.occurrences.count == summary.createdCount)
    }

    @Test("markOccurrenceCompletedで完了と再同期が行われる")
    internal func markOccurrenceCompletedTriggersResync() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let today = try #require(Date.from(year: 2025, month: 1, day: 1))
        let repository = SwiftDataSpecialPaymentRepository(
            modelContext: context,
            currentDateProvider: { today },
        )

        let definition = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: today,
        )

        context.insert(definition)
        try context.save()

        _ = try repository.synchronize(
            definitionId: definition.id,
            horizonMonths: 12,
            referenceDate: today,
        )

        let occurrence = try #require(definition.occurrences.first)

        let summary = try repository.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: OccurrenceCompletionInput(
                actualDate: today,
                actualAmount: 120_000,
            ),
            horizonMonths: 12,
        )

        #expect(occurrence.status == SpecialPaymentStatus.completed)
        #expect(summary.syncedAt == today)
    }
}

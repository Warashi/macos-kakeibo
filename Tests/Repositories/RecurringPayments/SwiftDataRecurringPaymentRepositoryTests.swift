import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("SwiftDataRecurringPaymentRepository")
internal struct SwiftDataRecurringPaymentRepositoryTests {
    @Test("definitionsをカテゴリと検索でフィルタできる")
    internal func definitionsFilter() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataRecurringPaymentRepository(modelContainer: container)

        let housing = SwiftDataCategory(name: "住宅")
        let dining = SwiftDataCategory(name: "外食", parent: housing)
        context.insert(housing)
        context.insert(dining)

        let definitionWithCategory = try SwiftDataRecurringPaymentDefinition(
            name: "住宅ローン",
            amount: 200_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: #require(Date.from(year: 2025, month: 1, day: 1)),
            category: housing,
        )

        let definitionWithoutCategory = try SwiftDataRecurringPaymentDefinition(
            name: "旅行積立",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: #require(Date.from(year: 2025, month: 2, day: 1)),
        )

        context.insert(definitionWithCategory)
        context.insert(definitionWithoutCategory)
        try context.save()

        let filter = RecurringPaymentDefinitionFilter(
            searchText: "住宅",
            categoryIds: [housing.id],
        )

        let results = try await repository.definitions(filter: filter)
        #expect(results.count == 1)
        #expect(results.first?.id == definitionWithCategory.id)
    }

    @Test("occurrencesを日付レンジとステータスでフィルタできる")
    internal func occurrencesFilter() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataRecurringPaymentRepository(modelContainer: container)

        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )

        let upcoming = try SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: #require(Date.from(year: 2025, month: 5, day: 31)),
            expectedAmount: 45000,
            status: .planned,
        )

        // swiftlint:disable force_unwrapping
        let completed = SwiftDataRecurringPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2024, month: 5, day: 31)!,
            expectedAmount: 42000,
            status: .completed,
            actualDate: Date.from(year: 2024, month: 5, day: 30)!,
            actualAmount: 42000,
        )
        // swiftlint:enable force_unwrapping

        definition.occurrences = [upcoming, completed]
        context.insert(definition)
        context.insert(upcoming)
        context.insert(completed)
        try context.save()

        let query = try RecurringPaymentOccurrenceQuery(
            range: RecurringPaymentOccurrenceRange(
                startDate: #require(Date.from(year: 2025, month: 1, day: 1)),
                endDate: #require(Date.from(year: 2025, month: 12, day: 31)),
            ),
            statusFilter: [.planned],
        )

        let results = try await repository.occurrences(query: query)
        #expect(results.count == 1)
        #expect(results.first?.id == upcoming.id)
    }

    @Test("synchronizeでOccurrenceが生成される")
    internal func synchronizeCreatesOccurrences() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let repository = SwiftDataRecurringPaymentRepository(modelContainer: container)
        await repository.useCurrentDateProvider { referenceDate }

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "保険料",
            amount: 50000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: referenceDate,
        )

        context.insert(definition)
        try context.save()

        let summary = try await repository.synchronize(
            definitionId: definition.id,
            horizonMonths: 12,
            referenceDate: referenceDate,
            backfillFromFirstDate: false,
        )

        #expect(summary.createdCount >= 2)
        let definitionId = definition.id
        let refreshed = try #require(
            context.fetch(RecurringPaymentQueries.definitions(
                predicate: #Predicate { $0.id == definitionId },
            )).first,
        )
        #expect(refreshed.occurrences.count == summary.createdCount)
    }

    @Test("markOccurrenceCompletedで完了と再同期が行われる")
    internal func markOccurrenceCompletedTriggersResync() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let today = try #require(Date.from(year: 2025, month: 1, day: 1))
        let repository = SwiftDataRecurringPaymentRepository(modelContainer: container)
        await repository.useCurrentDateProvider { today }

        let definition = SwiftDataRecurringPaymentDefinition(
            name: "固定資産税",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: today,
        )

        context.insert(definition)
        try context.save()

        _ = try await repository.synchronize(
            definitionId: definition.id,
            horizonMonths: 12,
            referenceDate: today,
            backfillFromFirstDate: false,
        )

        let definitionId = definition.id
        let refreshedDefinition = try #require(
            context.fetch(RecurringPaymentQueries.definitions(
                predicate: #Predicate { $0.id == definitionId },
            )).first,
        )
        let occurrence = try #require(refreshedDefinition.occurrences.first)

        let summary = try await repository.markOccurrenceCompleted(
            occurrenceId: occurrence.id,
            input: OccurrenceCompletionInput(
                actualDate: today,
                actualAmount: 120_000,
            ),
            horizonMonths: 12,
        )

        let occurrenceId = occurrence.id
        let refreshedOccurrence = try #require(
            context.fetch(RecurringPaymentQueries.occurrences(
                predicate: #Predicate { $0.id == occurrenceId },
            )).first,
        )
        #expect(refreshedOccurrence.status == RecurringPaymentStatus.completed)
        #expect(summary.syncedAt == today)
    }
}

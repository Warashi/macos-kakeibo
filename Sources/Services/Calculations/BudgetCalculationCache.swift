import Foundation
import os.lock

// MARK: - Cache Keys

internal struct MonthlyBudgetCacheKey: Hashable {
    internal let year: Int
    internal let month: Int
    internal let filter: FilterSignature
    internal let excludedCategoriesSignature: Int
    internal let transactionsVersion: Int
    internal let budgetsVersion: Int
}

internal struct RecurringPaymentSavingsCacheKey: Hashable {
    internal let year: Int
    internal let month: Int
    internal let definitionsVersion: Int
    internal let balancesVersion: Int
}

internal struct SavingsAllocationCacheKey: Hashable {
    internal let year: Int
    internal let month: Int
    internal let definitionsVersion: Int
}

internal struct FilterSignature: Hashable {
    internal let includeOnlyCalculationTarget: Bool
    internal let excludeTransfers: Bool
    internal let financialInstitutionId: UUID?
    internal let categoryId: UUID?

    internal init(filter: AggregationFilter) {
        self.includeOnlyCalculationTarget = filter.includeOnlyCalculationTarget
        self.excludeTransfers = filter.excludeTransfers
        self.financialInstitutionId = filter.financialInstitutionId
        self.categoryId = filter.categoryId
    }
}

// MARK: - Cache Metrics

internal struct BudgetCalculationCacheMetrics: Sendable {
    internal let monthlyBudgetHits: Int
    internal let monthlyBudgetMisses: Int
    internal let recurringPaymentHits: Int
    internal let recurringPaymentMisses: Int
    internal let monthlySavingsHits: Int
    internal let monthlySavingsMisses: Int
    internal let categorySavingsHits: Int
    internal let categorySavingsMisses: Int
}

// MARK: - Cache Storage

internal final class BudgetCalculationCache: Sendable {
    private struct StorageMetrics {
        var monthlyBudgetHits: Int = 0
        var monthlyBudgetMisses: Int = 0
        var recurringPaymentHits: Int = 0
        var recurringPaymentMisses: Int = 0
        var monthlySavingsHits: Int = 0
        var monthlySavingsMisses: Int = 0
        var categorySavingsHits: Int = 0
        var categorySavingsMisses: Int = 0
    }

    internal struct Target: OptionSet {
        internal let rawValue: Int

        internal static let monthlyBudget: Target = Target(rawValue: 1 << 0)
        internal static let recurringPaymentSavings: Target = Target(rawValue: 1 << 1)
        internal static let monthlySavings: Target = Target(rawValue: 1 << 2)
        internal static let categorySavings: Target = Target(rawValue: 1 << 3)
        internal static let all: Target = [
            .monthlyBudget,
            .recurringPaymentSavings,
            .monthlySavings,
            .categorySavings,
        ]
    }

    private struct Storage {
        var monthlyBudgetCache: [MonthlyBudgetCacheKey: MonthlyBudgetCalculation] = [:]
        var recurringPaymentSavingsCache: [RecurringPaymentSavingsCacheKey: [RecurringPaymentSavingsCalculation]] = [:]
        var monthlySavingsCache: [SavingsAllocationCacheKey: Decimal] = [:]
        var categorySavingsCache: [SavingsAllocationCacheKey: [UUID: Decimal]] = [:]
        var metrics: StorageMetrics = StorageMetrics()
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    internal var metricsSnapshot: BudgetCalculationCacheMetrics {
        storage.withLock { storage in
            BudgetCalculationCacheMetrics(
                monthlyBudgetHits: storage.metrics.monthlyBudgetHits,
                monthlyBudgetMisses: storage.metrics.monthlyBudgetMisses,
                recurringPaymentHits: storage.metrics.recurringPaymentHits,
                recurringPaymentMisses: storage.metrics.recurringPaymentMisses,
                monthlySavingsHits: storage.metrics.monthlySavingsHits,
                monthlySavingsMisses: storage.metrics.monthlySavingsMisses,
                categorySavingsHits: storage.metrics.categorySavingsHits,
                categorySavingsMisses: storage.metrics.categorySavingsMisses,
            )
        }
    }

    internal func cachedMonthlyBudget(for key: MonthlyBudgetCacheKey) -> MonthlyBudgetCalculation? {
        storage.withLock { storage in
            if let value = storage.monthlyBudgetCache[key] {
                storage.metrics.monthlyBudgetHits += 1
                return value
            }
            storage.metrics.monthlyBudgetMisses += 1
            return nil
        }
    }

    internal func storeMonthlyBudget(_ value: MonthlyBudgetCalculation, for key: MonthlyBudgetCacheKey) {
        storage.withLock { storage in
            storage.monthlyBudgetCache[key] = value
        }
    }

    internal func cachedRecurringPaymentSavings(
        for key: RecurringPaymentSavingsCacheKey,
    ) -> [RecurringPaymentSavingsCalculation]? {
        storage.withLock { storage in
            if let value = storage.recurringPaymentSavingsCache[key] {
                storage.metrics.recurringPaymentHits += 1
                return value
            }
            storage.metrics.recurringPaymentMisses += 1
            return nil
        }
    }

    internal func storeRecurringPaymentSavings(
        _ value: [RecurringPaymentSavingsCalculation],
        for key: RecurringPaymentSavingsCacheKey,
    ) {
        storage.withLock { storage in
            storage.recurringPaymentSavingsCache[key] = value
        }
    }

    internal func cachedMonthlySavingsAllocation(for key: SavingsAllocationCacheKey) -> Decimal? {
        storage.withLock { storage in
            if let value = storage.monthlySavingsCache[key] {
                storage.metrics.monthlySavingsHits += 1
                return value
            }
            storage.metrics.monthlySavingsMisses += 1
            return nil
        }
    }

    internal func storeMonthlySavingsAllocation(_ value: Decimal, for key: SavingsAllocationCacheKey) {
        storage.withLock { storage in
            storage.monthlySavingsCache[key] = value
        }
    }

    internal func cachedCategorySavingsAllocation(
        for key: SavingsAllocationCacheKey,
    ) -> [UUID: Decimal]? {
        storage.withLock { storage in
            if let value = storage.categorySavingsCache[key] {
                storage.metrics.categorySavingsHits += 1
                return value
            }
            storage.metrics.categorySavingsMisses += 1
            return nil
        }
    }

    internal func storeCategorySavingsAllocation(
        _ value: [UUID: Decimal],
        for key: SavingsAllocationCacheKey,
    ) {
        storage.withLock { storage in
            storage.categorySavingsCache[key] = value
        }
    }

    internal func invalidate(targets: Target) {
        storage.withLock { storage in
            if targets.contains(.monthlyBudget) {
                storage.monthlyBudgetCache.removeAll()
            }
            if targets.contains(.recurringPaymentSavings) {
                storage.recurringPaymentSavingsCache.removeAll()
            }
            if targets.contains(.monthlySavings) {
                storage.monthlySavingsCache.removeAll()
            }
            if targets.contains(.categorySavings) {
                storage.categorySavingsCache.removeAll()
            }
        }
    }
}

// MARK: - Cache Key Helpers

internal enum BudgetCalculationCacheHasher {
    internal static func excludedCategoriesSignature(for categories: Set<UUID>) -> Int {
        var hasher = Hasher()
        hasher.combine(categories.count)
        for id in categories.sorted(by: { $0.uuidString < $1.uuidString }) {
            hasher.combine(id)
        }
        return hasher.finalize()
    }

    internal static func transactionsVersion(for transactions: [Transaction]) -> Int {
        versionHash(for: transactions, id: { $0.id }, updatedAt: { $0.updatedAt })
    }

    internal static func budgetsVersion(for budgets: [Budget]) -> Int {
        versionHash(for: budgets, id: { $0.id }, updatedAt: { $0.updatedAt })
    }

    internal static func balancesVersion(for balances: [RecurringPaymentSavingBalance]) -> Int {
        versionHash(for: balances, id: { $0.id }, updatedAt: { $0.updatedAt })
    }

    internal static func definitionsVersion(_ definitions: [RecurringPaymentDefinition]) -> Int {
        versionHash(for: definitions, id: { $0.id }, updatedAt: { $0.updatedAt })
    }

    private static func versionHash<T>(
        for items: [T],
        id: (T) -> UUID,
        updatedAt: (T) -> Date,
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(items.count)
        let sortedItems = items.sorted { id($0).uuidString < id($1).uuidString }
        for item in sortedItems {
            hasher.combine(id(item))
            hasher.combine(updatedAt(item).timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }
}

// MARK: - Synchronization Helper

private extension NSLock {
    func withLock<T>(_ execute: () -> T) -> T {
        lock()
        defer { unlock() }
        return execute()
    }
}

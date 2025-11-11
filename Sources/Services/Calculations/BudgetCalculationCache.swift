import Foundation

// MARK: - Cache Keys

internal struct MonthlyBudgetCacheKey: Hashable {
    internal let year: Int
    internal let month: Int
    internal let filter: FilterSignature
    internal let excludedCategoriesSignature: Int
    internal let transactionsVersion: Int
    internal let budgetsVersion: Int
}

internal struct SpecialPaymentSavingsCacheKey: Hashable {
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
    internal let specialPaymentHits: Int
    internal let specialPaymentMisses: Int
    internal let monthlySavingsHits: Int
    internal let monthlySavingsMisses: Int
    internal let categorySavingsHits: Int
    internal let categorySavingsMisses: Int
}

// MARK: - Cache Storage

internal final class BudgetCalculationCache: @unchecked Sendable {
    private struct StorageMetrics {
        var monthlyBudgetHits: Int = 0
        var monthlyBudgetMisses: Int = 0
        var specialPaymentHits: Int = 0
        var specialPaymentMisses: Int = 0
        var monthlySavingsHits: Int = 0
        var monthlySavingsMisses: Int = 0
        var categorySavingsHits: Int = 0
        var categorySavingsMisses: Int = 0
    }

    internal struct Target: OptionSet {
        internal let rawValue: Int

        internal static let monthlyBudget: Target = Target(rawValue: 1 << 0)
        internal static let specialPaymentSavings: Target = Target(rawValue: 1 << 1)
        internal static let monthlySavings: Target = Target(rawValue: 1 << 2)
        internal static let categorySavings: Target = Target(rawValue: 1 << 3)
        internal static let all: Target = [
            .monthlyBudget,
            .specialPaymentSavings,
            .monthlySavings,
            .categorySavings,
        ]
    }

    private let lock: NSLock = NSLock()
    private var monthlyBudgetCache: [MonthlyBudgetCacheKey: MonthlyBudgetCalculation] = [:]
    private var specialPaymentSavingsCache: [SpecialPaymentSavingsCacheKey: [SpecialPaymentSavingsCalculation]] = [:]
    private var monthlySavingsCache: [SavingsAllocationCacheKey: Decimal] = [:]
    private var categorySavingsCache: [SavingsAllocationCacheKey: [UUID: Decimal]] = [:]
    private var metrics: StorageMetrics = StorageMetrics()

    internal var metricsSnapshot: BudgetCalculationCacheMetrics {
        lock.withLock {
            BudgetCalculationCacheMetrics(
                monthlyBudgetHits: metrics.monthlyBudgetHits,
                monthlyBudgetMisses: metrics.monthlyBudgetMisses,
                specialPaymentHits: metrics.specialPaymentHits,
                specialPaymentMisses: metrics.specialPaymentMisses,
                monthlySavingsHits: metrics.monthlySavingsHits,
                monthlySavingsMisses: metrics.monthlySavingsMisses,
                categorySavingsHits: metrics.categorySavingsHits,
                categorySavingsMisses: metrics.categorySavingsMisses,
            )
        }
    }

    internal func cachedMonthlyBudget(for key: MonthlyBudgetCacheKey) -> MonthlyBudgetCalculation? {
        lock.withLock {
            if let value = monthlyBudgetCache[key] {
                metrics.monthlyBudgetHits += 1
                return value
            }
            metrics.monthlyBudgetMisses += 1
            return nil
        }
    }

    internal func storeMonthlyBudget(_ value: MonthlyBudgetCalculation, for key: MonthlyBudgetCacheKey) {
        lock.withLock {
            monthlyBudgetCache[key] = value
        }
    }

    internal func cachedSpecialPaymentSavings(
        for key: SpecialPaymentSavingsCacheKey,
    ) -> [SpecialPaymentSavingsCalculation]? {
        lock.withLock {
            if let value = specialPaymentSavingsCache[key] {
                metrics.specialPaymentHits += 1
                return value
            }
            metrics.specialPaymentMisses += 1
            return nil
        }
    }

    internal func storeSpecialPaymentSavings(
        _ value: [SpecialPaymentSavingsCalculation],
        for key: SpecialPaymentSavingsCacheKey,
    ) {
        lock.withLock {
            specialPaymentSavingsCache[key] = value
        }
    }

    internal func cachedMonthlySavingsAllocation(for key: SavingsAllocationCacheKey) -> Decimal? {
        lock.withLock {
            if let value = monthlySavingsCache[key] {
                metrics.monthlySavingsHits += 1
                return value
            }
            metrics.monthlySavingsMisses += 1
            return nil
        }
    }

    internal func storeMonthlySavingsAllocation(_ value: Decimal, for key: SavingsAllocationCacheKey) {
        lock.withLock {
            monthlySavingsCache[key] = value
        }
    }

    internal func cachedCategorySavingsAllocation(
        for key: SavingsAllocationCacheKey,
    ) -> [UUID: Decimal]? {
        lock.withLock {
            if let value = categorySavingsCache[key] {
                metrics.categorySavingsHits += 1
                return value
            }
            metrics.categorySavingsMisses += 1
            return nil
        }
    }

    internal func storeCategorySavingsAllocation(
        _ value: [UUID: Decimal],
        for key: SavingsAllocationCacheKey,
    ) {
        lock.withLock {
            categorySavingsCache[key] = value
        }
    }

    internal func invalidate(targets: Target) {
        lock.withLock {
            if targets.contains(.monthlyBudget) {
                monthlyBudgetCache.removeAll()
            }
            if targets.contains(.specialPaymentSavings) {
                specialPaymentSavingsCache.removeAll()
            }
            if targets.contains(.monthlySavings) {
                monthlySavingsCache.removeAll()
            }
            if targets.contains(.categorySavings) {
                categorySavingsCache.removeAll()
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

    internal static func balancesVersion(for balances: [SpecialPaymentSavingBalanceDTO]) -> Int {
        versionHash(for: balances, id: { $0.id }, updatedAt: { $0.updatedAt })
    }

    internal static func definitionsVersion(_ definitions: [SpecialPaymentDefinitionDTO]) -> Int {
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

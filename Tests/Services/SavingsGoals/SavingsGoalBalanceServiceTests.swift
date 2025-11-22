import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SavingsGoalBalanceService - 月次積立テスト")
internal struct SavingsGoalBalanceSavingsTests {
    private let service: SavingsGoalBalanceService = SavingsGoalBalanceService()

    private func sampleGoal() -> SwiftDataSavingsGoal {
        SwiftDataSavingsGoal(
            name: "緊急費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: nil,
            startDate: Date.from(year: 2025, month: 1) ?? Date(),
            targetDate: nil,
            isActive: true,
        )
    }

    @Test("月次積立を記録：新規作成")
    internal func recordMonthlySavings_newBalance() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        context.insert(goal)

        // When
        let balance = service.recordMonthlySavings(
            params: SavingsGoalBalanceService.MonthlySavingsParameters(
                goal: goal,
                balance: nil,
                year: 2025,
                month: 1,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 10000)
        #expect(balance.totalWithdrawnAmount == 0)
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 1)
    }

    @Test("月次積立を記録：既存残高に加算")
    internal func recordMonthlySavings_addToExisting() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let existingBalance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 10000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(existingBalance)

        // When
        let balance = service.recordMonthlySavings(
            params: SavingsGoalBalanceService.MonthlySavingsParameters(
                goal: goal,
                balance: existingBalance,
                year: 2025,
                month: 2,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 20000) // 10000 + 10000
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 2)
    }

    @Test("月次積立を記録：同じ年月で重複記録はスキップ")
    internal func recordMonthlySavings_skipDuplicate() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let existingBalance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 10000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(existingBalance)

        // When
        let balance = service.recordMonthlySavings(
            params: SavingsGoalBalanceService.MonthlySavingsParameters(
                goal: goal,
                balance: existingBalance,
                year: 2025,
                month: 1, // 同じ年月
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 10000) // 変わらない
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 1)
    }
}

@Suite("SavingsGoalBalanceService - 引出処理テスト")
internal struct SavingsGoalBalanceWithdrawalTests {
    private let service: SavingsGoalBalanceService = SavingsGoalBalanceService()

    private func sampleGoal() -> SwiftDataSavingsGoal {
        SwiftDataSavingsGoal(
            name: "旅行積立",
            targetAmount: 500_000,
            monthlySavingAmount: 50000,
            categoryId: nil,
            notes: nil,
            startDate: Date.from(year: 2025, month: 1) ?? Date(),
            targetDate: nil,
            isActive: true,
        )
    }

    @Test("引出処理：残高から引出額を差し引く")
    internal func processWithdrawal_success() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 100_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 2,
        )
        context.insert(goal)
        context.insert(balance)

        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 30000,
            withdrawalDate: Date(),
            purpose: "旅行費用",
            transaction: nil,
        )
        context.insert(withdrawal)

        // When
        let remainingBalance = service.processWithdrawal(
            withdrawal: withdrawal,
            balance: balance,
        )

        // Then
        #expect(balance.totalWithdrawnAmount == 30000)
        #expect(remainingBalance == 70000) // 100000 - 30000
    }

    @Test("引出処理：複数回の引出")
    internal func processWithdrawal_multiple() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 150_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 3,
        )
        context.insert(goal)
        context.insert(balance)

        let withdrawal1 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 50000,
            withdrawalDate: Date(),
            purpose: "1回目",
            transaction: nil,
        )
        let withdrawal2 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 30000,
            withdrawalDate: Date(),
            purpose: "2回目",
            transaction: nil,
        )
        context.insert(withdrawal1)
        context.insert(withdrawal2)

        // When
        let balance1 = service.processWithdrawal(
            withdrawal: withdrawal1,
            balance: balance,
        )
        let balance2 = service.processWithdrawal(
            withdrawal: withdrawal2,
            balance: balance,
        )

        // Then
        #expect(balance.totalWithdrawnAmount == 80000) // 50000 + 30000
        #expect(balance2 == 70000) // 150000 - 80000
    }
}

@Suite("SavingsGoalBalanceService - 残高再計算テスト")
internal struct SavingsGoalBalanceRecalculationTests {
    private let service: SavingsGoalBalanceService = SavingsGoalBalanceService()

    private func sampleGoal() -> SwiftDataSavingsGoal {
        SwiftDataSavingsGoal(
            name: "税金積立",
            targetAmount: 1_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date.from(year: 2025, month: 1) ?? Date(),
            targetDate: nil,
            isActive: true,
        )
    }

    @Test("残高再計算：開始年月から経過月数を計算")
    internal func recalculateBalance_fromStartDate() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(balance)

        // When: 2025年1月から2025年6月まで（6ヶ月）
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: nil,
                startMonth: nil,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 600_000) // 100000 * 6
        #expect(balance.totalWithdrawnAmount == 0)
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 6)
    }

    @Test("残高再計算：明示的な開始年月を指定")
    internal func recalculateBalance_withExplicitStartDate() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(balance)

        // When: 2025年3月から2025年12月まで（10ヶ月）
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 12,
                startYear: 2025,
                startMonth: 3,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 1_000_000) // 100000 * 10
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 12)
    }

    @Test("残高再計算：引出がある場合")
    internal func recalculateBalance_withWithdrawals() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )

        let withdrawal1 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 50000,
            withdrawalDate: Date(),
            purpose: "引出1",
            transaction: nil,
        )
        let withdrawal2 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 30000,
            withdrawalDate: Date(),
            purpose: "引出2",
            transaction: nil,
        )

        context.insert(goal)
        context.insert(balance)
        context.insert(withdrawal1)
        context.insert(withdrawal2)

        // When: 2025年1月から2025年6月まで（6ヶ月）
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: nil,
                startMonth: nil,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 600_000) // 100000 * 6
        #expect(balance.totalWithdrawnAmount == 80000) // 50000 + 30000
        #expect(balance.balance == 520_000) // 600000 - 80000
    }

    @Test("残高再計算：年をまたぐ場合")
    internal func recalculateBalance_acrossYears() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2024,
            lastUpdatedMonth: 10,
        )
        context.insert(goal)
        context.insert(balance)

        // When: 2024年10月から2025年6月まで（9ヶ月）
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2024,
                startMonth: 10,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 900_000) // 100000 * 9
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 6)
    }
}

@Suite("SavingsGoalBalanceService - キャッシュテスト")
internal struct SavingsGoalBalanceCacheTests {
    private func sampleGoal() -> SwiftDataSavingsGoal {
        SwiftDataSavingsGoal(
            name: "キャッシュテスト",
            targetAmount: nil,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: nil,
            startDate: Date.from(year: 2025, month: 1) ?? Date(),
            targetDate: nil,
            isActive: true,
        )
    }

    @Test("同一パラメータで残高再計算を繰り返すとキャッシュがヒット")
    internal func recalculateBalance_cacheHit() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(balance)
        let service = SavingsGoalBalanceService()

        var metrics = service.cacheMetrics()
        #expect(metrics.hits == 0)
        #expect(metrics.misses == 0)

        // 1回目：キャッシュミス
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        // 2回目：キャッシュヒット
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        metrics = service.cacheMetrics()
        #expect(metrics.hits == 1)
        #expect(metrics.misses == 1)
    }

    @Test("積立記録後はキャッシュが無効化される")
    internal func invalidateCache_afterSavings() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(balance)
        let service = SavingsGoalBalanceService()

        // 1回目：再計算でキャッシュに保存
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        // 2回目：キャッシュヒット
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        var metrics = service.cacheMetrics()
        #expect(metrics.hits == 1)
        #expect(metrics.invalidations == 0)

        // 積立記録（キャッシュ無効化）
        service.recordMonthlySavings(
            params: SavingsGoalBalanceService.MonthlySavingsParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 7,
            ),
        )

        metrics = service.cacheMetrics()
        #expect(metrics.invalidations == 1)

        // 3回目：キャッシュミス（無効化されたため）
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        metrics = service.cacheMetrics()
        #expect(metrics.misses == 2) // 初回 + 無効化後
    }

    @Test("引出処理後はキャッシュが無効化される")
    internal func invalidateCache_afterWithdrawal() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 100_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(goal)
        context.insert(balance)
        let service = SavingsGoalBalanceService()

        // 再計算でキャッシュに保存
        service.recalculateBalance(
            params: SavingsGoalBalanceService.RecalculateBalanceParameters(
                goal: goal,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 10000,
            withdrawalDate: Date(),
            purpose: nil,
            transaction: nil,
        )
        context.insert(withdrawal)

        // 引出処理（キャッシュ無効化）
        service.processWithdrawal(
            withdrawal: withdrawal,
            balance: balance,
        )

        let metrics = service.cacheMetrics()
        #expect(metrics.invalidations == 1)
    }
}

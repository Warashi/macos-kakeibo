import Foundation
import SwiftData

internal extension ModelContainer {
    /// Kakeiboアプリ用のModelContainerを作成
    static func createKakeiboContainer() throws -> ModelContainer {
        let schema = Schema([
            SwiftDataTransaction.self,
            SwiftDataCategory.self,
            SwiftDataBudget.self,
            SwiftDataAnnualBudgetConfig.self,
            SwiftDataFinancialInstitution.self,
            SwiftDataRecurringPaymentDefinition.self,
            SwiftDataRecurringPaymentOccurrence.self,
            SwiftDataRecurringPaymentSavingBalance.self,
            SwiftDataCustomHoliday.self,
            SwiftDataSavingsGoal.self,
            SwiftDataSavingsGoalBalance.self,
            SwiftDataSavingsGoalWithdrawal.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration],
        )
    }

    /// テスト用のインメモリModelContainerを作成
    static func createInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            SwiftDataTransaction.self,
            SwiftDataCategory.self,
            SwiftDataBudget.self,
            SwiftDataAnnualBudgetConfig.self,
            SwiftDataFinancialInstitution.self,
            SwiftDataRecurringPaymentDefinition.self,
            SwiftDataRecurringPaymentOccurrence.self,
            SwiftDataRecurringPaymentSavingBalance.self,
            SwiftDataCustomHoliday.self,
            SwiftDataSavingsGoal.self,
            SwiftDataSavingsGoalBalance.self,
            SwiftDataSavingsGoalWithdrawal.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration],
        )
    }
}

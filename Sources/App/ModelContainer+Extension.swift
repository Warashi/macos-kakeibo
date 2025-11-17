import Foundation
import SwiftData

internal extension ModelContainer {
    /// Kakeiboアプリ用のModelContainerを作成
    static func createKakeiboContainer() throws -> ModelContainer {
        let schema = Schema([
            TransactionEntity.self,
            CategoryEntity.self,
            BudgetEntity.self,
            AnnualBudgetConfigEntity.self,
            FinancialInstitutionEntity.self,
            RecurringPaymentDefinitionEntity.self,
            RecurringPaymentOccurrenceEntity.self,
            RecurringPaymentSavingBalanceEntity.self,
            CustomHoliday.self,
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
            TransactionEntity.self,
            CategoryEntity.self,
            BudgetEntity.self,
            AnnualBudgetConfigEntity.self,
            FinancialInstitutionEntity.self,
            RecurringPaymentDefinitionEntity.self,
            RecurringPaymentOccurrenceEntity.self,
            RecurringPaymentSavingBalanceEntity.self,
            CustomHoliday.self,
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

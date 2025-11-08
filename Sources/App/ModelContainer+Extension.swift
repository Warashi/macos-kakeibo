import Foundation
import SwiftData

internal extension ModelContainer {
    /// Kakeiboアプリ用のModelContainerを作成
    static func createKakeiboContainer() throws -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Budget.self,
            AnnualBudgetConfig.self,
            FinancialInstitution.self,
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
            Transaction.self,
            Category.self,
            Budget.self,
            AnnualBudgetConfig.self,
            FinancialInstitution.self,
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

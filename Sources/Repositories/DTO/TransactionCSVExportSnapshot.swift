import Foundation

/// CSVエクスポート用に必要な取引と参照データ
internal struct TransactionCSVExportSnapshot: Sendable {
    internal let transactions: [Transaction]
    internal let categories: [Category]
    internal let institutions: [FinancialInstitution]

    internal var referenceData: TransactionReferenceData {
        TransactionReferenceData(institutions: institutions, categories: categories)
    }
}

import Foundation

/// 定期支払いドメインで使用する共通エラー
internal enum RecurringPaymentDomainError: Error, Equatable {
    case invalidRecurrence
    case invalidHorizon
    case validationFailed([String])
    case categoryNotFound
    case definitionNotFound
    case occurrenceNotFound
}

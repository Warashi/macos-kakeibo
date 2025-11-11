import Foundation

/// 特別支払いドメインで使用する共通エラー
internal enum SpecialPaymentDomainError: Error, Equatable {
    case invalidRecurrence
    case invalidHorizon
    case validationFailed([String])
    case categoryNotFound
    case definitionNotFound
    case occurrenceNotFound
}

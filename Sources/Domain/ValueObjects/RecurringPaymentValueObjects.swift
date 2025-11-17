import Foundation

internal enum RecurringPaymentSavingStrategy: String, Codable, Sendable {
    case disabled // 積立なし
    case evenlyDistributed // 周期で均等積立
    case customMonthly // 手動で月次金額を指定
}

internal enum RecurringPaymentStatus: String, Codable, Sendable {
    case planned // 予定のみ
    case saving // 積立中
    case completed // 実績反映済み
    case cancelled // 中止
}

internal enum DateAdjustmentPolicy: String, Codable, Sendable {
    case none // 調整なし
    case moveToPreviousBusinessDay // 前営業日に移動
    case moveToNextBusinessDay // 次営業日に移動
}

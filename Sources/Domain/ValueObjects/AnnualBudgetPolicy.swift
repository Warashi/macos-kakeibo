import Foundation

/// 年次特別枠の充当ポリシー
internal enum AnnualBudgetPolicy: String, Codable, CaseIterable, Sendable {
    case automatic // 予算超過分のみ自動充当
    case manual // 手動充当
    case fullCoverage // 特定カテゴリの支出を全額年次特別枠で処理
    case disabled // 無効
}

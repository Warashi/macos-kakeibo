import Foundation

/// 休日調整方法
public enum BusinessDayAdjustment: String, Codable, Sendable, CaseIterable {
    /// 調整なし
    case none
    /// 前営業日に調整
    case previous
    /// 次営業日に調整
    case next

    /// 表示名
    public var displayName: String {
        switch self {
        case .none:
            "調整しない"
        case .previous:
            "前営業日"
        case .next:
            "次営業日"
        }
    }
}

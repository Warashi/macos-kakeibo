import SwiftUI

/// アプリケーション全体で使用する統一的なカラーテーマ
///
/// セマンティックな命名により、色の意味を明確にし、
/// デザインの一貫性を保ちます。
public extension Color {
    // MARK: - Semantic Colors for Finance

    /// 収入を表す色（青）
    static let income: Color = .blue

    /// 支出を表す色（赤）
    static let expense: Color = .red

    /// プラスの差引を表す色（緑）
    static let positive: Color = .green

    /// マイナスの差引を表す色（オレンジ）
    static let negative: Color = .orange

    // MARK: - Budget Status Colors

    /// 予算が健全な状態（70%未満）
    static let budgetHealthy: Color = .green

    /// 予算が警告状態（70-90%）
    static let budgetWarning: Color = .orange

    /// 予算が危険な状態（90%以上）
    static let budgetDanger: Color = .red

    // MARK: - General Status Colors

    /// 成功状態を表す色（緑）
    static let success: Color = .green

    /// 警告状態を表す色（オレンジ）
    static let warning: Color = .orange

    /// エラー状態を表す色（赤）
    static let error: Color = .red

    /// 情報を表す色（青）
    static let info: Color = .blue

    /// ニュートラルな状態を表す色（グレー）
    static let neutral: Color = .gray

    // MARK: - Background Colors

    /// 主要な背景色（白）
    static let backgroundPrimary: Color = .white

    /// 二次的な背景色（薄いグレー）
    static let backgroundSecondary: Color = .gray.opacity(0.05)

    /// 三次的な背景色（少し濃いグレー）
    static let backgroundTertiary: Color = .gray.opacity(0.1)

    // MARK: - Semantic Background Colors

    /// 情報系の背景色（薄い青）
    static let backgroundInfo: Color = .blue.opacity(0.1)

    /// 成功系の背景色（薄い緑）
    static let backgroundSuccess: Color = .green.opacity(0.1)

    /// 警告系の背景色（薄いオレンジ）
    static let backgroundWarning: Color = .orange.opacity(0.15)

    /// エラー系の背景色（薄い赤）
    static let backgroundError: Color = .red.opacity(0.1)

    // MARK: - Shadow Colors

    /// デフォルトの影の色
    static let shadowDefault: Color = .black.opacity(0.1)

    // MARK: - Badge Background Colors

    /// バッジのデフォルト背景色
    static let badgeBackgroundDefault: Color = .gray.opacity(0.2)

    /// バッジのプライマリ背景色
    static let badgeBackgroundPrimary: Color = .blue.opacity(0.2)

    /// バッジの成功背景色
    static let badgeBackgroundSuccess: Color = .green.opacity(0.2)

    /// バッジの警告背景色
    static let badgeBackgroundWarning: Color = .orange.opacity(0.2)

    /// バッジのエラー背景色
    static let badgeBackgroundError: Color = .red.opacity(0.2)

    // MARK: - Helper Methods

    /// 予算の使用率に基づいて適切な色を返す
    /// - Parameter usageRate: 使用率（0.0〜1.0以上）
    /// - Returns: 使用率に応じた色
    static func budgetColor(for usageRate: Double) -> Color {
        if usageRate >= 0.9 {
            budgetDanger
        } else if usageRate >= 0.7 {
            budgetWarning
        } else {
            budgetHealthy
        }
    }

    /// 金額の正負に基づいて適切な色を返す
    /// - Parameter amount: 金額
    /// - Returns: 金額が正ならpositive、負ならnegative
    static func amountColor(for amount: Decimal) -> Color {
        amount >= 0 ? positive : negative
    }
}

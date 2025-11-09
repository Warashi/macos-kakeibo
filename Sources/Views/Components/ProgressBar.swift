import SwiftUI

/// プログレスバーの表示スタイル
public enum ProgressBarStyle {
    /// 標準スタイル（緑）
    case standard
    /// 警告スタイル（黄色）- 70%以上
    case warning
    /// 危険スタイル（赤）- 90%以上
    case danger
    /// カスタムカラー
    case custom(Color)

    /// スタイルに対応する色を返す
    internal var color: Color {
        switch self {
        case .standard:
            Color.budgetHealthy
        case .warning:
            Color.budgetWarning
        case .danger:
            Color.budgetDanger
        case let .custom(color):
            color
        }
    }

    /// 進捗率に基づいて自動的にスタイルを決定する
    /// - Parameter progress: 進捗率（0.0〜1.0）
    /// - Returns: 適切なProgressBarStyle
    public static func automatic(progress: Double) -> ProgressBarStyle {
        if progress >= 0.9 {
            .danger
        } else if progress >= 0.7 {
            .warning
        } else {
            .standard
        }
    }
}

/// プログレスバーコンポーネント
///
/// 予算使用率などの進捗を視覚的に表示します。
public struct ProgressBar: View {
    /// 進捗率（0.0〜1.0）
    private let progress: Double
    /// プログレスバーのスタイル
    private let style: ProgressBarStyle
    /// プログレスバーの高さ
    private let height: CGFloat
    /// ラベルの表示有無
    private let showLabel: Bool
    /// ラベルのフォーマット関数
    private let labelFormatter: ((Double) -> String)?

    /// ProgressBarを初期化します
    /// - Parameters:
    ///   - progress: 進捗率（0.0〜1.0）
    ///   - style: プログレスバーのスタイル（デフォルト: 自動）
    ///   - height: プログレスバーの高さ（デフォルト: 8）
    ///   - showLabel: ラベルの表示有無（デフォルト: true）
    ///   - labelFormatter: ラベルのフォーマット関数（デフォルト: パーセント表示）
    public init(
        progress: Double,
        style: ProgressBarStyle? = nil,
        height: CGFloat = 8,
        showLabel: Bool = true,
        labelFormatter: ((Double) -> String)? = nil,
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.style = style ?? .automatic(progress: self.progress)
        self.height = height
        self.showLabel = showLabel
        self.labelFormatter = labelFormatter
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                Text(formattedLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Rectangle()
                        .fill(Color.badgeBackgroundDefault)
                        .frame(height: height)
                        .cornerRadius(height / 2)

                    // 進捗バー
                    Rectangle()
                        .fill(style.color)
                        .frame(width: geometry.size.width * progress, height: height)
                        .cornerRadius(height / 2)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: height)
        }
    }

    /// フォーマット済みのラベル文字列
    private var formattedLabel: String {
        if let formatter: ((Double) -> String) = labelFormatter {
            formatter(progress)
        } else {
            String(format: "%.0f%%", progress * 100)
        }
    }
}

#if DEBUG
#Preview("Progress Variations") {
    VStack(spacing: 20) {
        VStack(alignment: .leading) {
            Text("30% - 標準")
                .font(.caption)
            ProgressBar(progress: 0.3)
        }

        VStack(alignment: .leading) {
            Text("75% - 警告")
                .font(.caption)
            ProgressBar(progress: 0.75)
        }

        VStack(alignment: .leading) {
            Text("95% - 危険")
                .font(.caption)
            ProgressBar(progress: 0.95)
        }

        VStack(alignment: .leading) {
            Text("カスタムカラー")
                .font(.caption)
            ProgressBar(progress: 0.6, style: .custom(.purple))
        }

        VStack(alignment: .leading) {
            Text("カスタムフォーマッタ")
                .font(.caption)
            ProgressBar(
                progress: 0.45,
                labelFormatter: { progress in
                    String(format: "¥%.0f / ¥100,000", progress * 100_000)
                },
            )
        }

        VStack(alignment: .leading) {
            Text("ラベルなし・太め")
                .font(.caption)
            ProgressBar(progress: 0.8, height: 16, showLabel: false)
        }
    }
    .padding()
    .frame(width: 400)
}
#endif

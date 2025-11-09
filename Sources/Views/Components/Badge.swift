import SwiftUI

/// バッジのスタイル
public enum BadgeStyle {
    /// デフォルトスタイル（グレー）
    case `default`
    /// プライマリスタイル（ブルー）
    case primary
    /// 成功スタイル（グリーン）
    case success
    /// 警告スタイル（イエロー）
    case warning
    /// エラースタイル（レッド）
    case error
    /// カスタムカラー
    case custom(foreground: Color, background: Color)

    /// スタイルに対応する前景色を返す
    internal var foregroundColor: Color {
        switch self {
        case .default:
            Color.secondary
        case .primary:
            Color.info
        case .success:
            Color.success
        case .warning:
            Color.warning
        case .error:
            Color.error
        case let .custom(foreground, _):
            foreground
        }
    }

    /// スタイルに対応する背景色を返す
    internal var backgroundColor: Color {
        switch self {
        case .default:
            Color.badgeBackgroundDefault
        case .primary:
            Color.badgeBackgroundPrimary
        case .success:
            Color.badgeBackgroundSuccess
        case .warning:
            Color.badgeBackgroundWarning
        case .error:
            Color.badgeBackgroundError
        case let .custom(_, background):
            background
        }
    }
}

/// バッジのサイズ
public enum BadgeSize {
    /// 小サイズ
    case small
    /// 中サイズ
    case medium
    /// 大サイズ
    case large

    /// サイズに対応するフォント
    internal var font: Font {
        switch self {
        case .small:
            .caption2
        case .medium:
            .caption
        case .large:
            .footnote
        }
    }

    /// サイズに対応する水平パディング
    internal var horizontalPadding: CGFloat {
        switch self {
        case .small:
            6
        case .medium:
            8
        case .large:
            10
        }
    }

    /// サイズに対応する垂直パディング
    internal var verticalPadding: CGFloat {
        switch self {
        case .small:
            2
        case .medium:
            4
        case .large:
            6
        }
    }

    /// サイズに対応するコーナー半径
    internal var cornerRadius: CGFloat {
        switch self {
        case .small:
            4
        case .medium:
            6
        case .large:
            8
        }
    }
}

/// バッジコンポーネント
///
/// ステータスやカテゴリを表示するための小さなラベル。
public struct Badge: View {
    /// バッジのテキスト
    private let text: String
    /// バッジのスタイル
    private let style: BadgeStyle
    /// バッジのサイズ
    private let size: BadgeSize
    /// アイコン（オプション）
    private let icon: String?

    /// Badgeを初期化します
    /// - Parameters:
    ///   - text: バッジのテキスト
    ///   - style: バッジのスタイル（デフォルト: .default）
    ///   - size: バッジのサイズ（デフォルト: .medium）
    ///   - icon: アイコン（SF Symbolsの名前、オプション）
    public init(
        _ text: String,
        style: BadgeStyle = .default,
        size: BadgeSize = .medium,
        icon: String? = nil,
    ) {
        self.text = text
        self.style = style
        self.size = size
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let iconName: String = icon {
                Image(systemName: iconName)
                    .font(size.font)
            }

            Text(text)
                .font(size.font)
        }
        .foregroundColor(style.foregroundColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(style.backgroundColor)
        .cornerRadius(size.cornerRadius)
    }
}

#if DEBUG
#Preview("Badge Styles") {
    VStack(spacing: 12) {
        Text("バッジのスタイル")
            .font(.headline)

        HStack(spacing: 8) {
            Badge("デフォルト", style: .default)
            Badge("プライマリ", style: .primary)
            Badge("成功", style: .success)
        }

        HStack(spacing: 8) {
            Badge("警告", style: .warning)
            Badge("エラー", style: .error)
            Badge("カスタム", style: .custom(foreground: .purple, background: .purple.opacity(0.2)))
        }
    }
    .padding()
}

#Preview("Badge Sizes") {
    VStack(spacing: 12) {
        Text("バッジのサイズ")
            .font(.headline)

        HStack(spacing: 8) {
            Badge("小", style: .primary, size: .small)
            Badge("中", style: .primary, size: .medium)
            Badge("大", style: .primary, size: .large)
        }
    }
    .padding()
}

#Preview("Badge with Icons") {
    VStack(spacing: 12) {
        Text("アイコン付きバッジ")
            .font(.headline)

        HStack(spacing: 8) {
            Badge("収入", style: .success, icon: "arrow.down.circle.fill")
            Badge("支出", style: .error, icon: "arrow.up.circle.fill")
            Badge("予算", style: .primary, icon: "chart.bar.fill")
        }

        HStack(spacing: 8) {
            Badge("食費", style: .default, size: .small, icon: "fork.knife")
            Badge("交通費", style: .default, size: .small, icon: "car.fill")
            Badge("光熱費", style: .default, size: .small, icon: "bolt.fill")
        }
    }
    .padding()
}

#Preview("Badge Usage Example") {
    VStack(alignment: .leading, spacing: 16) {
        Text("カテゴリ表示例")
            .font(.headline)

        HStack {
            Text("食費")
                .font(.body)
            Badge("予算超過", style: .error, size: .small)
        }

        HStack {
            Text("交通費")
                .font(.body)
            Badge("70%", style: .warning, size: .small)
        }

        HStack {
            Text("住居費")
                .font(.body)
            Badge("30%", style: .success, size: .small)
        }
    }
    .padding()
}
#endif

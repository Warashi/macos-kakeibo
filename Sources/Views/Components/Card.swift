import SwiftUI

/// カードスタイルを表すビューモディファイア
///
/// ダッシュボードやリストビューで使用する統一されたカードスタイルを提供します。
public struct CardStyle: ViewModifier {
    /// カードの背景色
    private let backgroundColor: Color
    /// カードのコーナー半径
    private let cornerRadius: CGFloat
    /// カードの影の半径
    private let shadowRadius: CGFloat
    /// カードのパディング
    private let padding: EdgeInsets

    /// CardStyleを初期化します
    /// - Parameters:
    ///   - backgroundColor: カードの背景色（デフォルト: .white）
    ///   - cornerRadius: カードのコーナー半径（デフォルト: 12）
    ///   - shadowRadius: カードの影の半径（デフォルト: 4）
    ///   - padding: カードのパディング（デフォルト: 16）
    public init(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 4,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
    }
}

/// Viewにカードスタイルを適用するための拡張
public extension View {
    /// カードスタイルを適用します
    /// - Parameters:
    ///   - backgroundColor: カードの背景色（デフォルト: .white）
    ///   - cornerRadius: カードのコーナー半径（デフォルト: 12）
    ///   - shadowRadius: カードの影の半径（デフォルト: 4）
    ///   - padding: カードのパディング（デフォルト: 16）
    /// - Returns: カードスタイルが適用されたビュー
    func cardStyle(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 4,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
    ) -> some View {
        modifier(
            CardStyle(
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius,
                shadowRadius: shadowRadius,
                padding: padding,
            ),
        )
    }
}

/// タイトル付きカードビュー
///
/// タイトルとコンテンツを持つカードを表示します。
public struct Card<Content: View>: View {
    /// カードのタイトル
    private let title: String
    /// カードのコンテンツ
    private let content: Content

    /// Cardを初期化します
    /// - Parameters:
    ///   - title: カードのタイトル
    ///   - content: カードのコンテンツ
    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content
        }
        .cardStyle()
    }
}

#if DEBUG
#Preview("Card with Text") {
    Card(title: "サンプルカード") {
        Text("これはカードのコンテンツです")
    }
    .padding()
    .frame(width: 300)
}

#Preview("Card with List") {
    Card(title: "リストカード") {
        VStack(alignment: .leading, spacing: 8) {
            Text("項目1")
            Text("項目2")
            Text("項目3")
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Custom Style Card") {
    VStack {
        Text("カスタムスタイルのコンテンツ")
    }
    .cardStyle(
        backgroundColor: .blue.opacity(0.1),
        cornerRadius: 8,
        shadowRadius: 2,
    )
    .padding()
    .frame(width: 300)
}
#endif

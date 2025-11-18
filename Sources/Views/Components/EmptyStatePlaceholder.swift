import SwiftUI

/// 共通の空状態プレースホルダ
///
/// カード内などでゼロ件時の表示を揃えるためのユーティリティビュー。
internal struct EmptyStatePlaceholder: View {
    internal let systemImage: String
    internal let title: String
    internal let message: String
    internal let minHeight: CGFloat

    internal init(
        systemImage: String,
        title: String,
        message: String,
        minHeight: CGFloat = 200,
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.minHeight = minHeight
    }

    internal var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
    }
}

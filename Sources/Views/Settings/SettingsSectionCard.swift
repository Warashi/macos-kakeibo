import SwiftUI

/// 設定画面の共通カード
internal struct SettingsSectionCard<Content: View>: View {
    internal let title: String
    internal let iconName: String
    internal let description: String
    internal let content: Content

    internal init(
        title: String,
        iconName: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.iconName = iconName
        self.description = description
        self.content = content()
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UserInterface.cornerRadius)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: AppConstants.UserInterface.cardShadowRadius)
        )
    }
}

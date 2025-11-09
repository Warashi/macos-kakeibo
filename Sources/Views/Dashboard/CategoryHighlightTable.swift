import SwiftUI

/// カテゴリ別ハイライトテーブル
///
/// カテゴリ別の支出額をテーブル形式で表示します。
internal struct CategoryHighlightTable: View {
    internal let categories: [CategorySummary]
    internal let title: String

    internal var body: some View {
        Card(title: title) {
            if categories.isEmpty {
                Text("データがありません")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Text("カテゴリ")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("支出")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 120, alignment: .trailing)

                        Text("収入")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 120, alignment: .trailing)

                        Text("件数")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.backgroundTertiary)

                    Divider()

                    // データ行
                    ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                        categoryRow(category: category)
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categoryRow(category: CategorySummary) -> some View {
        HStack {
            Text(category.categoryName)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(category.totalExpense.currencyFormatted)
                .font(.body)
                .foregroundColor(.expense)
                .frame(width: 120, alignment: .trailing)

            Text(category.totalIncome.currencyFormatted)
                .font(.body)
                .foregroundColor(.income)
                .frame(width: 120, alignment: .trailing)

            Text("\(category.transactionCount)")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

import SwiftData
import SwiftUI

/// 予算ビューの特別支払いリストセクション
internal struct BudgetSpecialPaymentSection: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    internal let onEdit: (SpecialPaymentDefinition) -> Void
    internal let onDelete: (SpecialPaymentDefinition) -> Void
    internal let onAdd: () -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("特別支払い")
                    .font(.title2.bold())
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }

            if specialPaymentDefinitions.isEmpty {
                ContentUnavailableView {
                    Label("特別支払いがありません", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("定期的な大きな支払いを登録して、月次の積立計画を立てましょう。")
                }
                .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    ForEach(specialPaymentDefinitions) { definition in
                        SpecialPaymentRow(
                            definition: definition,
                            onEdit: { onEdit(definition) },
                            onDelete: { onDelete(definition) },
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(10)
    }

    private var specialPaymentDefinitions: [SpecialPaymentDefinition] {
        let descriptor: ModelFetchRequest<SpecialPaymentDefinition> = ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\SpecialPaymentDefinition.firstOccurrenceDate),
                SortDescriptor(\SpecialPaymentDefinition.name),
            ],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

import SwiftData
import SwiftUI

/// 予算ビューの定期支払いリストセクション
internal struct BudgetRecurringPaymentSection: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    internal let onEdit: (SwiftDataRecurringPaymentDefinition) -> Void
    internal let onDelete: (SwiftDataRecurringPaymentDefinition) -> Void
    internal let onAdd: () -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("定期支払い")
                    .font(.title2.bold())
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }

            if recurringPaymentDefinitions.isEmpty {
                ContentUnavailableView {
                    Label("定期支払いがありません", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("定期的な大きな支払いを登録して、月次の積立計画を立てましょう。")
                }
                .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    ForEach(recurringPaymentDefinitions) { definition in
                        RecurringPaymentRow(
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

    private var recurringPaymentDefinitions: [SwiftDataRecurringPaymentDefinition] {
        let descriptor: ModelFetchRequest<SwiftDataRecurringPaymentDefinition> = ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\SwiftDataRecurringPaymentDefinition.firstOccurrenceDate),
                SortDescriptor(\SwiftDataRecurringPaymentDefinition.name),
            ],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

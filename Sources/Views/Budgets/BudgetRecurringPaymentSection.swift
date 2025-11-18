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
                    .font(.headline)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }

            if recurringPaymentDefinitions.isEmpty {
                EmptyStatePlaceholder(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "定期支払いがありません",
                    message: "定期的な大きな支払いを登録して、月次の積立計画を立てましょう。",
                )
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
        .cardStyle()
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

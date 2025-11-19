import Foundation
import SwiftUI

/// 予算ビューの定期支払いリストセクション
internal struct BudgetRecurringPaymentSection: View {
    internal let definitions: [RecurringPaymentDefinition]
    internal let categories: [Category]
    internal let onEdit: (RecurringPaymentDefinition) -> Void
    internal let onDelete: (RecurringPaymentDefinition) -> Void
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

            if sortedDefinitions.isEmpty {
                EmptyStatePlaceholder(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "定期支払いがありません",
                    message: "定期的な大きな支払いを登録して、月次の積立計画を立てましょう。",
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedDefinitions) { definition in
                        RecurringPaymentRow(
                            definition: definition,
                            categoryName: categoryName(for: definition),
                            onEdit: { onEdit(definition) },
                            onDelete: { onDelete(definition) },
                        )
                    }
                }
            }
        }
        .cardStyle()
    }

    private var sortedDefinitions: [RecurringPaymentDefinition] {
        definitions.sorted { lhs, rhs in
            if lhs.firstOccurrenceDate == rhs.firstOccurrenceDate {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.firstOccurrenceDate < rhs.firstOccurrenceDate
        }
    }

    private var categoryLookup: [UUID: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private func categoryName(for definition: RecurringPaymentDefinition) -> String? {
        guard let categoryId = definition.categoryId else { return nil }
        guard let category = categoryLookup[categoryId] else { return nil }

        if let parentId = category.parentId, let parent = categoryLookup[parentId] {
            return "\(parent.name) / \(category.name)"
        }

        return category.name
    }
}

import SwiftUI

internal struct TransactionFilterBar: View {
    @Bindable internal var store: TransactionStore

    private var institutions: [FinancialInstitution] {
        store.availableInstitutions.sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.name < rhs.name
            }
            return lhs.displayOrder < rhs.displayOrder
        }
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    store.moveToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                }

                Text(store.currentMonthLabel)
                    .font(.title3.weight(.semibold))

                Button {
                    store.moveToNextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                }

                Button("今月") {
                    store.moveToCurrentMonth()
                }

                Spacer()

                Button {
                    store.resetFilters()
                } label: {
                    Label("フィルタをリセット", systemImage: "arrow.counterclockwise")
                }
            }

            HStack(spacing: 12) {
                TextField("内容・メモ・カテゴリ・金融機関で検索", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("表示順", selection: $store.sortOption) {
                    ForEach(TransactionSortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
            }

            HStack(spacing: 12) {
                SegmentedControl(
                    selection: $store.selectedFilterKind,
                    items: TransactionFilterKind.allCases.map { ($0, $0.label) },
                )
                .frame(maxWidth: 340)

                Toggle("計算対象のみ", isOn: $store.includeOnlyCalculationTarget)
                Toggle("振替を除外", isOn: $store.excludeTransfers)
            }

            HStack(spacing: 12) {
                Picker("金融機関", selection: Binding(get: {
                    store.selectedInstitutionId
                }, set: { newValue in
                    store.selectedInstitutionId = newValue
                })) {
                    Text("すべて").tag(UUID?.none)
                    ForEach(institutions, id: \.id) { institution in
                        Text(institution.name).tag(Optional(institution.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)

                CategoryHierarchyPicker(
                    categories: store.categoryFilter.availableCategories,
                    selectedMajorCategoryId: $store.categoryFilter.selectedMajorCategoryId,
                    selectedMinorCategoryId: $store.categoryFilter.selectedMinorCategoryId,
                    majorPlaceholder: "すべて",
                    minorPlaceholder: "中項目を選択",
                    inactiveMinorMessage: "大項目を選択すると中項目でも絞り込めます",
                    noMinorMessage: "この大項目に中項目はありません",
                )
                .frame(minWidth: 220, alignment: .leading)
            }
        }
        .padding()
        .background(Color.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

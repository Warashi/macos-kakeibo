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

    private var categories: [Category] {
        store.availableCategories.sorted { lhs, rhs in
            lhs.fullName < rhs.fullName
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
                    ForEach(TransactionStore.SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
            }

            HStack(spacing: 12) {
                SegmentedControl(
                    selection: $store.selectedFilterKind,
                    items: TransactionStore.TransactionFilterKind.allCases.map { ($0, $0.label) }
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

                Picker("カテゴリ", selection: Binding(get: {
                    store.selectedCategoryId
                }, set: { newValue in
                    store.selectedCategoryId = newValue
                })) {
                    Text("すべて").tag(UUID?.none)
                    ForEach(categories, id: \.id) { category in
                        Text(category.fullName).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 220)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

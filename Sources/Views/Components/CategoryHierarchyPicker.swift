import SwiftUI

/// 大項目→中項目の順にカテゴリを選択するための共通ピッカー。
internal struct CategoryHierarchyPicker: View {
    internal let categories: [Category]
    @Binding internal var selectedMajorCategoryId: UUID?
    @Binding internal var selectedMinorCategoryId: UUID?
    internal let majorPlaceholder: String
    internal let minorPlaceholder: String
    internal let inactiveMinorMessage: String?
    internal let noMinorMessage: String

    private var grouping: CategoryHierarchyGrouping {
        CategoryHierarchyGrouping(categories: categories)
    }

    internal init(
        categories: [Category],
        selectedMajorCategoryId: Binding<UUID?>,
        selectedMinorCategoryId: Binding<UUID?>,
        majorPlaceholder: String = "大項目を選択",
        minorPlaceholder: String = "中項目を選択",
        inactiveMinorMessage: String? = nil,
        noMinorMessage: String = "この大項目に中項目はありません",
    ) {
        self.categories = categories
        _selectedMajorCategoryId = selectedMajorCategoryId
        _selectedMinorCategoryId = selectedMinorCategoryId
        self.majorPlaceholder = majorPlaceholder
        self.minorPlaceholder = minorPlaceholder
        self.inactiveMinorMessage = inactiveMinorMessage
        self.noMinorMessage = noMinorMessage
    }

    private var majorSelection: Binding<UUID?> {
        Binding(
            get: { selectedMajorCategoryId },
            set: { newValue in
                guard selectedMajorCategoryId != newValue else { return }
                selectedMajorCategoryId = newValue
                selectedMinorCategoryId = nil
            },
        )
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("大項目", selection: majorSelection) {
                Text(majorPlaceholder).tag(UUID?.none)
                ForEach(grouping.majorCategories, id: \.id) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let majorId = selectedMajorCategoryId {
                let minors = grouping.minorCategories(forMajorId: majorId)
                if minors.isEmpty {
                    if !noMinorMessage.isEmpty {
                        Text(noMinorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("中項目", selection: $selectedMinorCategoryId) {
                        Text(minorPlaceholder).tag(UUID?.none)
                        ForEach(minors, id: \.id) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let inactiveMinorMessage {
                Text(inactiveMinorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

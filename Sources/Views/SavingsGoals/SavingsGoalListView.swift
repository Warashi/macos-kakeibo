import SwiftData
import SwiftUI

/// 貯蓄目標一覧ビュー
internal struct SavingsGoalListView: View {
    @State private var store: SavingsGoalStore
    @Query private var goals: [SwiftDataSavingsGoal]

    internal init(modelContext: ModelContext) {
        _store = State(initialValue: SavingsGoalStore(modelContext: modelContext))
    }

    internal var body: some View {
        List {
            ForEach(goals) { goal in
                SavingsGoalRow(
                    goal: goal.toDomain(),
                    balance: goal.balance?.toDomain(),
                    onToggleActive: {
                        try? store.toggleGoalActive(goal.id)
                    },
                    onEdit: {
                        store.prepareFormForEdit(goal.toDomain())
                    },
                    onDelete: {
                        try? store.deleteGoal(goal.id)
                    },
                )
            }
        }
        .navigationTitle("貯蓄目標")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新規作成") {
                    store.prepareFormForCreate()
                }
            }
        }
        .sheet(isPresented: $store.isShowingForm) {
            SavingsGoalFormView(store: store)
        }
        .onAppear {
            store.loadGoals()
        }
    }
}

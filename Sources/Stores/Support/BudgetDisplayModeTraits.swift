import Foundation

/// 予算表示モードに紐づくUI要素
internal struct BudgetDisplayModeTraits {
    internal enum NavigationStyle {
        case monthly
        case annual
        case hidden
    }

    internal let mode: BudgetStore.DisplayMode

    internal var navigationStyle: NavigationStyle {
        switch mode {
        case .monthly:
            .monthly
        case .annual:
            .annual
        case .recurringPaymentsList:
            .hidden
        }
    }

    internal var presentButtonLabel: String? {
        switch mode {
        case .monthly:
            "今月"
        case .annual:
            "今年"
        case .recurringPaymentsList:
            nil
        }
    }

    internal var showsNavigation: Bool {
        navigationStyle != .hidden
    }
}

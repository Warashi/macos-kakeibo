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
            return .monthly
        case .annual:
            return .annual
        case .specialPaymentsList:
            return .hidden
        }
    }

    internal var presentButtonLabel: String? {
        switch mode {
        case .monthly:
            return "今月"
        case .annual:
            return "今年"
        case .specialPaymentsList:
            return nil
        }
    }

    internal var showsNavigation: Bool {
        navigationStyle != .hidden
    }
}

import Foundation

/// 定期支払い提案UseCase のプロトコル
internal protocol RecurringPaymentSuggestionUseCaseProtocol: Sendable {
    /// 取引データから定期支払いの提案を生成
    func generateSuggestions(
        criteria: RecurringPaymentDetectionCriteria
    ) async throws -> [RecurringPaymentSuggestion]
}

/// 定期支払い提案UseCase の実装
internal struct RecurringPaymentSuggestionUseCase: RecurringPaymentSuggestionUseCaseProtocol {
    private let transactionRepository: TransactionRepository
    private let recurringPaymentRepository: RecurringPaymentRepository
    private let detectionService: RecurringPaymentDetectionService
    private let clock: @Sendable () -> Date

    internal init(
        transactionRepository: TransactionRepository,
        recurringPaymentRepository: RecurringPaymentRepository,
        detectionService: RecurringPaymentDetectionService = RecurringPaymentDetectionService(),
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transactionRepository = transactionRepository
        self.recurringPaymentRepository = recurringPaymentRepository
        self.detectionService = detectionService
        self.clock = clock
    }

    internal func generateSuggestions(
        criteria: RecurringPaymentDetectionCriteria = .default
    ) async throws -> [RecurringPaymentSuggestion] {
        // 1. 過去N年の取引を取得
        let transactions = try await fetchTransactionsInLookbackPeriod(years: criteria.lookbackYears)

        // 2. 既存の定期支払い定義を取得
        let existingDefinitions = try await recurringPaymentRepository.definitions(filter: nil)

        // 3. 検出サービスで提案を生成
        let suggestions = detectionService.detectSuggestions(
            from: transactions,
            existingDefinitions: existingDefinitions
        )

        return suggestions
    }

    // MARK: - Private Helpers

    /// 過去N年の取引を取得
    private func fetchTransactionsInLookbackPeriod(years: Int) async throws -> [Transaction] {
        let now = clock()
        let calendar = Calendar.current

        // 過去N年前の日付を計算
        guard let startDate = calendar.date(byAdding: .year, value: -years, to: now) else {
            return []
        }

        // 全取引を取得してフィルタ
        // NOTE: TransactionRepositoryに日付範囲クエリがあればそれを使う方が効率的
        let allTransactions = try await transactionRepository.fetchAllTransactions()
        return allTransactions.filter { $0.date >= startDate }
    }
}

import Foundation

internal struct RecurringPaymentScheduleService {
    /// 既定のスケジュール生成期間（月単位）
    internal static let defaultHorizonMonths: Int = 36

    /// 生成対象となるOccurrenceの情報
    internal struct ScheduleTarget: Equatable {
        internal let scheduledDate: Date
        internal let expectedAmount: Decimal
    }

    /// スケジュール同期結果
    internal struct SynchronizationResult {
        internal let created: [SwiftDataRecurringPaymentOccurrence]
        internal let updated: [SwiftDataRecurringPaymentOccurrence]
        internal let removed: [SwiftDataRecurringPaymentOccurrence]
        internal let locked: [SwiftDataRecurringPaymentOccurrence]
        internal let occurrences: [SwiftDataRecurringPaymentOccurrence]
        internal let referenceDate: Date
    }

    private let calendar: Calendar
    private let businessDayService: BusinessDayService
    private let maxIterations: Int = 600

    internal init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil,
    ) {
        self.calendar = calendar
        if let businessDayService {
            self.businessDayService = businessDayService
        } else {
            self.businessDayService = BusinessDayService(
                calendar: calendar,
                holidays: [],
                holidayProvider: holidayProvider,
            )
        }
    }

    /// 営業日への日付調整を行う
    /// - Parameters:
    ///   - date: 調整対象の日付
    ///   - policy: 調整ポリシー
    /// - Returns: 調整後の日付
    internal func adjustDateForBusinessDay(_ date: Date, policy: DateAdjustmentPolicy) -> Date {
        switch policy {
        case .none:
            return date

        case .moveToPreviousBusinessDay:
            if businessDayService.isBusinessDay(date) {
                return date
            }
            return businessDayService.previousBusinessDay(from: date) ?? date

        case .moveToNextBusinessDay:
            if businessDayService.isBusinessDay(date) {
                return date
            }
            return businessDayService.nextBusinessDay(from: date) ?? date
        }
    }

    /// 差分適用用の同期計画を生成
    /// - Parameters:
    ///   - definition: 対象の定期支払い定義
    ///   - referenceDate: 判定基準日
    ///   - horizonMonths: 生成対象期間
    ///   - backfillFromFirstDate: trueの場合、完了済みOccurrenceより前にも開始日から遡ってOccurrenceを生成する
    /// - Returns: 同期結果
    internal func synchronizationPlan(
        for definition: SwiftDataRecurringPaymentDefinition,
        referenceDate: Date,
        horizonMonths: Int,
        backfillFromFirstDate: Bool = false,
    ) -> SynchronizationResult {
        let seedDate = backfillFromFirstDate ? definition.firstOccurrenceDate : nextSeedDate(for: definition)
        let targets = scheduleTargets(
            for: definition,
            seedDate: seedDate,
            referenceDate: referenceDate,
            horizonMonths: horizonMonths,
        )

        let locked = definition.occurrences.filter(\.isSchedulingLocked)

        guard !targets.isEmpty else {
            return SynchronizationResult(
                created: [],
                updated: [],
                removed: [],
                locked: locked,
                occurrences: definition.occurrences,
                referenceDate: referenceDate,
            )
        }

        let effectiveNextDate = computeNextUpcomingDate(for: definition, targets: targets)

        let result = processSyncTargets(
            targets: targets,
            definition: definition,
            referenceDate: referenceDate,
            effectiveNextDate: effectiveNextDate,
        )

        let occurrences = (result.matched + locked).sorted(by: { $0.scheduledDate < $1.scheduledDate })

        return SynchronizationResult(
            created: result.created,
            updated: result.updated,
            removed: result.remaining,
            locked: locked,
            occurrences: occurrences,
            referenceDate: referenceDate,
        )
    }

    /// 定義に基づき、指定した開始日から将来のOccurrence候補を生成する
    /// - Parameters:
    ///   - definition: 定期支払い定義
    ///   - seedDate: 計算開始基準日（通常は初回発生日か、最新実績の次回予定日）
    ///   - referenceDate: 判定基準となる日付（通常は「今日」）
    ///   - horizonMonths: 参照日から先の生成期間（月数）
    /// - Returns: 作成対象のOccurrence
    internal func scheduleTargets(
        for definition: SwiftDataRecurringPaymentDefinition,
        seedDate: Date,
        referenceDate: Date,
        horizonMonths: Int,
    ) -> [ScheduleTarget] {
        guard definition.recurrenceIntervalMonths > 0 else {
            return []
        }

        let safeSeed = max(seedDate, definition.firstOccurrenceDate)
        let safeHorizon = max(0, horizonMonths)
        let referenceStart = referenceDate.startOfMonth

        // 生成開始点: firstOccurrenceDate.startOfMonth と referenceStart の早い方
        // これにより過去の開始日を指定した場合でもその日付以降の発生を生成する
        let generationStart = min(definition.firstOccurrenceDate.startOfMonth, referenceStart)

        var currentDate = safeSeed
        var iterationCount = 0

        while currentDate < generationStart, iterationCount < maxIterations {
            guard let next = nextOccurrence(
                from: currentDate,
                intervalMonths: definition.recurrenceIntervalMonths,
                pattern: definition.recurrenceDayPattern,
            ) else {
                break
            }
            currentDate = next
            iterationCount += 1
        }

        let horizonEnd = calendar.date(byAdding: .month, value: safeHorizon, to: referenceStart) ?? referenceStart

        // 終了日が設定されている場合は、horizonEndと比較して小さい方を採用
        let effectiveEnd: Date = if let endDate = definition.endDate {
            min(horizonEnd, endDate)
        } else {
            horizonEnd
        }

        let endBoundary = max(effectiveEnd, currentDate)

        var targets: [ScheduleTarget] = []
        var generationDate = currentDate
        var generationIteration = iterationCount

        while generationDate <= endBoundary, generationIteration < maxIterations {
            // 終了日を超えた場合は生成を打ち切る
            if let endDate = definition.endDate, generationDate > endDate {
                break
            }
            let adjustedDate = adjustDateForBusinessDay(generationDate, policy: definition.dateAdjustmentPolicy)
            targets.append(
                ScheduleTarget(
                    scheduledDate: adjustedDate,
                    expectedAmount: definition.amount,
                ),
            )

            guard let next = nextOccurrence(
                from: generationDate,
                intervalMonths: definition.recurrenceIntervalMonths,
                pattern: definition.recurrenceDayPattern,
            ) else {
                break
            }

            generationDate = next
            generationIteration += 1
        }

        if targets.isEmpty {
            let adjustedDate = adjustDateForBusinessDay(currentDate, policy: definition.dateAdjustmentPolicy)
            targets.append(
                ScheduleTarget(
                    scheduledDate: adjustedDate,
                    expectedAmount: definition.amount,
                ),
            )
        }

        return targets
    }

    /// 次の予定かどうかに応じたデフォルトステータス
    /// - Parameters:
    ///   - scheduledDate: 予定日
    ///   - referenceDate: 判定基準日（未使用だが互換性のため保持）
    ///   - isNextUpcoming: 直近の次の支払いかどうか
    /// - Returns: 予定/積立ステータス
    internal func defaultStatus(
        for scheduledDate: Date,
        referenceDate: Date,
        isNextUpcoming: Bool,
    ) -> RecurringPaymentStatus {
        isNextUpcoming ? .saving : .planned
    }

    /// 次の発生日を計算する
    /// - Parameters:
    ///   - date: 基準となる日付
    ///   - intervalMonths: 周期（月数）
    ///   - pattern: 日付パターン（nilの場合は標準カレンダー計算）
    /// - Returns: 次の発生日
    private func nextOccurrence(
        from date: Date,
        intervalMonths: Int,
        pattern: DayOfMonthPattern?,
    ) -> Date? {
        // まず月を進める
        guard let nextMonth = calendar.date(byAdding: .month, value: intervalMonths, to: date) else {
            return nil
        }

        // パターンが指定されている場合は、そのパターンに従って日付を計算
        if let pattern {
            let components = calendar.dateComponents([.year, .month], from: nextMonth)
            guard let year = components.year, let month = components.month else {
                return nil
            }
            return pattern.date(
                in: year,
                month: month,
                calendar: calendar,
                businessDayService: businessDayService,
            )
        } else {
            // パターンがない場合は標準のカレンダー計算
            return nextMonth
        }
    }

    private func nextSeedDate(for definition: SwiftDataRecurringPaymentDefinition) -> Date {
        let latestCompleted = definition.occurrences
            .filter { $0.status == .completed }
            .map(\.scheduledDate)
            .max()

        guard let latestCompleted else {
            return definition.firstOccurrenceDate
        }

        // 完了済み（ロック済み）Occurrenceの最小scheduledDateを取得
        let earliestLockedDate = definition.occurrences
            .filter(\.isSchedulingLocked)
            .map(\.scheduledDate)
            .min()

        // firstOccurrenceDateが完了済みOccurrenceの最小scheduledDateより前の場合、
        // 開始日が過去に変更されたと判定し、firstOccurrenceDateから生成し直す
        // これにより、開始日変更後の穴が自動的に埋められる
        if let earliestLockedDate, definition.firstOccurrenceDate < earliestLockedDate {
            return definition.firstOccurrenceDate
        }

        // それ以外は最新完了の次回から
        return calendar.date(
            byAdding: .month,
            value: definition.recurrenceIntervalMonths,
            to: latestCompleted,
        ) ?? definition.firstOccurrenceDate
    }

    /// 同期処理の結果
    private struct SyncProcessingResult {
        internal let created: [SwiftDataRecurringPaymentOccurrence]
        internal let updated: [SwiftDataRecurringPaymentOccurrence]
        internal let matched: [SwiftDataRecurringPaymentOccurrence]
        internal let remaining: [SwiftDataRecurringPaymentOccurrence]
    }

    /// 未完了の次回支払い予定日を計算
    /// - Parameters:
    ///   - definition: 定期支払い定義
    ///   - targets: スケジュールターゲット一覧
    /// - Returns: 次回支払い予定日
    private func computeNextUpcomingDate(
        for definition: SwiftDataRecurringPaymentDefinition,
        targets: [ScheduleTarget],
    ) -> Date? {
        let nextUpcomingDate = definition.occurrences
            .filter { $0.status != .completed && $0.status != .cancelled }
            .map(\.scheduledDate)
            .min()

        return nextUpcomingDate ?? targets.first?.scheduledDate
    }

    /// スケジュールターゲットを処理し、Occurrence を作成・更新
    /// - Parameters:
    ///   - targets: スケジュールターゲット一覧
    ///   - definition: 定期支払い定義
    ///   - referenceDate: 判定基準日
    ///   - effectiveNextDate: 次回支払い予定日
    /// - Returns: 同期処理の結果
    private func processSyncTargets(
        targets: [ScheduleTarget],
        definition: SwiftDataRecurringPaymentDefinition,
        referenceDate: Date,
        effectiveNextDate: Date?,
    ) -> SyncProcessingResult {
        var editableOccurrences = definition.occurrences.filter { !$0.isSchedulingLocked }
        var created: [SwiftDataRecurringPaymentOccurrence] = []
        var updated: [SwiftDataRecurringPaymentOccurrence] = []
        var matched: [SwiftDataRecurringPaymentOccurrence] = []

        for target in targets {
            let isNextUpcoming = effectiveNextDate.map { isSameDay(target.scheduledDate, $0) } ?? false

            if let existingIndex = editableOccurrences.firstIndex(
                where: { isSameDay($0.scheduledDate, target.scheduledDate) },
            ) {
                let occurrence = editableOccurrences.remove(at: existingIndex)
                let changed = apply(
                    target: target,
                    to: occurrence,
                    referenceDate: referenceDate,
                    isNextUpcoming: isNextUpcoming,
                )
                if changed {
                    updated.append(occurrence)
                }
                matched.append(occurrence)
            } else {
                let occurrence = SwiftDataRecurringPaymentOccurrence(
                    definition: definition,
                    scheduledDate: target.scheduledDate,
                    expectedAmount: target.expectedAmount,
                    status: defaultStatus(
                        for: target.scheduledDate,
                        referenceDate: referenceDate,
                        isNextUpcoming: isNextUpcoming,
                    ),
                )
                occurrence.updatedAt = referenceDate
                created.append(occurrence)
                matched.append(occurrence)
            }
        }

        return SyncProcessingResult(
            created: created,
            updated: updated,
            matched: matched,
            remaining: editableOccurrences,
        )
    }

    @discardableResult
    private func apply(
        target: ScheduleTarget,
        to occurrence: SwiftDataRecurringPaymentOccurrence,
        referenceDate: Date,
        isNextUpcoming: Bool,
    ) -> Bool {
        var didMutate = false

        if occurrence.expectedAmount != target.expectedAmount {
            occurrence.expectedAmount = target.expectedAmount
            didMutate = true
        }

        if !isSameDay(occurrence.scheduledDate, target.scheduledDate) {
            occurrence.scheduledDate = target.scheduledDate
            didMutate = true
        }

        let statusChanged = updateStatusIfNeeded(
            for: occurrence,
            referenceDate: referenceDate,
            isNextUpcoming: isNextUpcoming,
        )
        if statusChanged {
            didMutate = true
        }

        occurrence.updatedAt = referenceDate
        return didMutate
    }

    private func updateStatusIfNeeded(
        for occurrence: SwiftDataRecurringPaymentOccurrence,
        referenceDate: Date,
        isNextUpcoming: Bool,
    ) -> Bool {
        guard !occurrence.isSchedulingLocked else {
            return false
        }

        let status = defaultStatus(
            for: occurrence.scheduledDate,
            referenceDate: referenceDate,
            isNextUpcoming: isNextUpcoming,
        )

        if occurrence.status != status {
            occurrence.status = status
            return true
        }

        return false
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}

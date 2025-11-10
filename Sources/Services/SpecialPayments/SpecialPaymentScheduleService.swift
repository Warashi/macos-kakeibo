import Foundation

internal struct SpecialPaymentScheduleService {
    /// 既定のスケジュール生成期間（月単位）
    internal static let defaultHorizonMonths: Int = 36

    /// 生成対象となるOccurrenceの情報
    internal struct ScheduleTarget: Equatable {
        internal let scheduledDate: Date
        internal let expectedAmount: Decimal
    }

    /// スケジュール同期結果
    internal struct SynchronizationResult {
        internal let created: [SpecialPaymentOccurrence]
        internal let updated: [SpecialPaymentOccurrence]
        internal let removed: [SpecialPaymentOccurrence]
        internal let locked: [SpecialPaymentOccurrence]
        internal let occurrences: [SpecialPaymentOccurrence]
        internal let referenceDate: Date

        internal init(
            created: [SpecialPaymentOccurrence],
            updated: [SpecialPaymentOccurrence],
            removed: [SpecialPaymentOccurrence],
            locked: [SpecialPaymentOccurrence],
            occurrences: [SpecialPaymentOccurrence],
            referenceDate: Date
        ) {
            self.created = created
            self.updated = updated
            self.removed = removed
            self.locked = locked
            self.occurrences = occurrences
            self.referenceDate = referenceDate
        }
    }

    private let calendar: Calendar
    private let businessDayService: BusinessDayService
    private let maxIterations: Int = 600

    internal init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil
    ) {
        self.calendar = calendar
        if let businessDayService {
            self.businessDayService = businessDayService
        } else {
            self.businessDayService = BusinessDayService(
                calendar: calendar,
                holidays: [],
                holidayProvider: holidayProvider
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
    ///   - definition: 対象の特別支払い定義
    ///   - referenceDate: 判定基準日
    ///   - horizonMonths: 生成対象期間
    /// - Returns: 同期結果
    internal func synchronizationPlan(
        for definition: SpecialPaymentDefinition,
        referenceDate: Date,
        horizonMonths: Int
    ) -> SynchronizationResult {
        let seedDate = nextSeedDate(for: definition)
        let targets = scheduleTargets(
            for: definition,
            seedDate: seedDate,
            referenceDate: referenceDate,
            horizonMonths: horizonMonths
        )

        let locked = definition.occurrences.filter(\.isSchedulingLocked)

        guard !targets.isEmpty else {
            return SynchronizationResult(
                created: [],
                updated: [],
                removed: [],
                locked: locked,
                occurrences: definition.occurrences,
                referenceDate: referenceDate
            )
        }

        var editableOccurrences = definition.occurrences.filter { !$0.isSchedulingLocked }
        var created: [SpecialPaymentOccurrence] = []
        var updated: [SpecialPaymentOccurrence] = []
        var matched: [SpecialPaymentOccurrence] = []

        for target in targets {
            if let existingIndex = editableOccurrences.firstIndex(
                where: { isSameDay($0.scheduledDate, target.scheduledDate) }
            ) {
                let occurrence = editableOccurrences.remove(at: existingIndex)
                let changed = apply(
                    target: target,
                    to: occurrence,
                    referenceDate: referenceDate,
                    leadTimeMonths: definition.leadTimeMonths
                )
                if changed {
                    updated.append(occurrence)
                }
                matched.append(occurrence)
            } else {
                let occurrence = SpecialPaymentOccurrence(
                    definition: definition,
                    scheduledDate: target.scheduledDate,
                    expectedAmount: target.expectedAmount,
                    status: defaultStatus(
                        for: target.scheduledDate,
                        referenceDate: referenceDate,
                        leadTimeMonths: definition.leadTimeMonths
                    )
                )
                occurrence.updatedAt = referenceDate
                created.append(occurrence)
                matched.append(occurrence)
            }
        }

        let occurrences = (matched + locked).sorted(by: { $0.scheduledDate < $1.scheduledDate })

        return SynchronizationResult(
            created: created,
            updated: updated,
            removed: editableOccurrences,
            locked: locked,
            occurrences: occurrences,
            referenceDate: referenceDate
        )
    }

    /// 定義に基づき、指定した開始日から将来のOccurrence候補を生成する
    /// - Parameters:
    ///   - definition: 特別支払い定義
    ///   - seedDate: 計算開始基準日（通常は初回発生日か、最新実績の次回予定日）
    ///   - referenceDate: 判定基準となる日付（通常は「今日」）
    ///   - horizonMonths: 参照日から先の生成期間（月数）
    /// - Returns: 作成対象のOccurrence
    internal func scheduleTargets(
        for definition: SpecialPaymentDefinition,
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

        var currentDate = safeSeed
        var iterationCount = 0

        while currentDate < referenceStart, iterationCount < maxIterations {
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
        let endBoundary = max(horizonEnd, currentDate)

        var targets: [ScheduleTarget] = []
        var generationDate = currentDate
        var generationIteration = iterationCount

        while generationDate <= endBoundary, generationIteration < maxIterations {
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

    /// リードタイムと参照日に応じたデフォルトステータス
    /// - Parameters:
    ///   - scheduledDate: 予定日
    ///   - referenceDate: 判定基準日
    ///   - leadTimeMonths: リードタイム（月数）
    /// - Returns: 予定/積立ステータス
    internal func defaultStatus(
        for scheduledDate: Date,
        referenceDate: Date,
        leadTimeMonths: Int,
    ) -> SpecialPaymentStatus {
        let normalizedReference = referenceDate.startOfMonth
        let normalizedScheduled = scheduledDate.startOfMonth

        if normalizedScheduled <= normalizedReference {
            return .saving
        }

        let clampedLeadTime = max(0, leadTimeMonths)
        let monthsUntil = calendar.dateComponents(
            [.month],
            from: normalizedReference,
            to: normalizedScheduled,
        ).month ?? 0

        return monthsUntil <= clampedLeadTime ? .saving : .planned
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

    private func nextSeedDate(for definition: SpecialPaymentDefinition) -> Date {
        let latestCompleted = definition.occurrences
            .filter { $0.status == .completed }
            .map(\.scheduledDate)
            .max()

        guard let latestCompleted else {
            return definition.firstOccurrenceDate
        }

        return calendar.date(
            byAdding: .month,
            value: definition.recurrenceIntervalMonths,
            to: latestCompleted
        ) ?? definition.firstOccurrenceDate
    }

    @discardableResult
    private func apply(
        target: ScheduleTarget,
        to occurrence: SpecialPaymentOccurrence,
        referenceDate: Date,
        leadTimeMonths: Int
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
            leadTimeMonths: leadTimeMonths
        )
        if statusChanged {
            didMutate = true
        }

        occurrence.updatedAt = referenceDate
        return didMutate
    }

    private func updateStatusIfNeeded(
        for occurrence: SpecialPaymentOccurrence,
        referenceDate: Date,
        leadTimeMonths: Int
    ) -> Bool {
        guard !occurrence.isSchedulingLocked else {
            return false
        }

        let status = defaultStatus(
            for: occurrence.scheduledDate,
            referenceDate: referenceDate,
            leadTimeMonths: leadTimeMonths
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

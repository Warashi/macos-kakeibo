import Foundation

internal protocol DashboardRepository: Sendable {
    func fetchSnapshot(year: Int, month: Int) async throws -> DashboardSnapshot
    func resolveInitialYear(defaultYear: Int) async throws -> Int
}

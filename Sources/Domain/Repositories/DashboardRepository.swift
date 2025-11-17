import Foundation

@DatabaseActor
internal protocol DashboardRepository: Sendable {
    func fetchSnapshot(year: Int, month: Int) throws -> DashboardSnapshot
    func resolveInitialYear(defaultYear: Int) throws -> Int
}

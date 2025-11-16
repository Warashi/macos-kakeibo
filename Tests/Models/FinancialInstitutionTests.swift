import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("FinancialInstitutionEntity Tests")
internal struct FinancialInstitutionEntityTests {
    // MARK: - 初期化テスト

    @Test("金融機関を初期化できる")
    internal func initializeFinancialInstitutionEntity() {
        let institution = FinancialInstitutionEntity(name: "三菱UFJ")

        #expect(institution.name == "三菱UFJ")
        #expect(institution.displayOrder == 0)
    }

    @Test("パラメータ付きで金融機関を初期化できる")
    internal func initializeFinancialInstitutionEntityWithParameters() {
        let institution = FinancialInstitutionEntity(
            name: "楽天銀行",
            displayOrder: 5,
        )

        #expect(institution.name == "楽天銀行")
        #expect(institution.displayOrder == 5)
    }

    // MARK: - 表示順序テスト

    @Test("表示順序を設定できる")
    internal func setDisplayOrder() {
        let institution1 = FinancialInstitutionEntity(name: "三菱UFJ", displayOrder: 1)
        let institution2 = FinancialInstitutionEntity(name: "三井住友", displayOrder: 2)
        let institution3 = FinancialInstitutionEntity(name: "楽天", displayOrder: 3)

        #expect(institution1.displayOrder == 1)
        #expect(institution2.displayOrder == 2)
        #expect(institution3.displayOrder == 3)
    }

    // MARK: - 日時テスト

    @Test("作成日時と更新日時が設定される")
    internal func setCreatedAndUpdatedDates() {
        let before = Date()
        let institution = FinancialInstitutionEntity(name: "三菱UFJ")
        let after = Date()

        #expect(institution.createdAt >= before)
        #expect(institution.createdAt <= after)
        #expect(institution.updatedAt >= before)
        #expect(institution.updatedAt <= after)
        #expect(institution.createdAt == institution.updatedAt)
    }

    // MARK: - 複数インスタンステスト

    @Test("複数の金融機関を作成できる")
    internal func createMultipleFinancialInstitutionEntitys() {
        let institutions = [
            FinancialInstitutionEntity(name: "三菱UFJ", displayOrder: 1),
            FinancialInstitutionEntity(name: "三井住友", displayOrder: 2),
            FinancialInstitutionEntity(name: "楽天", displayOrder: 3),
        ]

        #expect(institutions.count == 3)
        #expect(institutions[0].name == "三菱UFJ")
        #expect(institutions[1].name == "三井住友")
        #expect(institutions[2].name == "楽天")
    }
}

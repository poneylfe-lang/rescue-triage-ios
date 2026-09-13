import XCTest
@testable import RescueTriage

final class ScoreCalculatorTests: XCTestCase {

    private func declaration(reason: RejectReason = .calibreOut) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Elvi", productName: "Apples", category: .produce,
            quantity: 6, unit: "crates",
            arrivalDate: Date(), expiryDate: Date(),
            expiryKind: .bestBefore, declaredReason: reason,
            coldChainGapMinutes: nil, storageTempC: nil,
            retailUnitPrice: 12, estimatedWeightKg: 60
        )
    }

    private func observation(
        damage: Int = 0,
        packaging: PackagingIntegrity = .intact,
        legible: Bool = true,
        discrepancies: [Discrepancy] = []
    ) -> ScanObservation {
        ScanObservation(
            damageSeverity: damage, packagingIntegrity: packaging,
            spoilageSigns: [], labelLegible: legible,
            observedProduct: "apples", observedQuantityPlausible: true,
            discrepancies: discrepancies, visualNotes: ""
        )
    }

    private func score(_ o: ScanObservation, _ rules: RuleAssessment = .clean,
                       _ d: SupplierDeclaration? = nil) -> Double {
        ScoreCalculator.score(declaration: d ?? declaration(), observation: o, ruleAssessment: rules)
    }

    func test_perfectProduct_scoresTen() {
        XCTAssertEqual(score(observation()), 10.0, accuracy: 0.001)
    }

    func test_cosmeticRejectReasonCostsNothing() {
        for reason in RejectReason.allCases where reason.isCosmetic {
            XCTAssertEqual(score(observation(), .clean, declaration(reason: reason)), 10.0,
                           accuracy: 0.001, "\(reason) should be free")
        }
    }

    func test_damageSeverityCostsOnePointFiveEach() {
        XCTAssertEqual(score(observation(damage: 1)), 8.5, accuracy: 0.001)
        XCTAssertEqual(score(observation(damage: 2)), 7.0, accuracy: 0.001)
        XCTAssertEqual(score(observation(damage: 4)), 4.0, accuracy: 0.001)
    }

    func test_packagingPenalties() {
        XCTAssertEqual(score(observation(packaging: .dented)), 9.5, accuracy: 0.001)
        XCTAssertEqual(score(observation(packaging: .compromised)), 8.0, accuracy: 0.001)
    }

    func test_illegibleLabelCostsHalfAPoint() {
        XCTAssertEqual(score(observation(legible: false)), 9.5, accuracy: 0.001)
    }

    func test_discrepancyPenalties() {
        let minor = Discrepancy(field: "quantity", declared: "6", observed: "5", severity: .minor)
        let major = Discrepancy(field: "packaging", declared: "dent", observed: "torn open", severity: .major)
        XCTAssertEqual(score(observation(discrepancies: [minor])), 9.0, accuracy: 0.001)
        XCTAssertEqual(score(observation(discrepancies: [major])), 8.0, accuracy: 0.001)
        XCTAssertEqual(score(observation(discrepancies: [minor, major])), 7.0, accuracy: 0.001)
    }

    func test_rulePenaltiesAreSubtracted() {
        XCTAssertEqual(score(observation(), RuleAssessment(penalty: 2.5)), 7.5, accuracy: 0.001)
    }

    func test_scoreNeverGoesBelowZero() {
        let worst = observation(damage: 4, packaging: .compromised, legible: false)
        XCTAssertEqual(score(worst, RuleAssessment(penalty: 9.0)), 0.0, accuracy: 0.001)
    }

    func test_scoreNeverGoesAboveTen() {
        XCTAssertEqual(score(observation(), RuleAssessment(penalty: -5)), 10.0, accuracy: 0.001)
    }
}

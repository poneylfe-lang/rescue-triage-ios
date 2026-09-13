import XCTest
@testable import RescueTriage

final class ColdChainRuleTests: XCTestCase {

    private func gap(_ category: ProductCategory, _ minutes: Int?) -> RuleAssessment {
        SafetyRules.coldChain(category: category, gapMinutes: minutes)
    }

    private func temp(_ category: ProductCategory, _ celsius: Double?) -> RuleAssessment {
        SafetyRules.temperature(category: category, tempC: celsius)
    }

    // --- Cold chain, meat & fish: zero tolerance, hold to 15, reject past it ---

    func test_meat_noGapDeclared_isClean() {
        XCTAssertEqual(gap(.meatFish, nil), .clean)
        XCTAssertEqual(gap(.meatFish, 0).floor, .none)
    }

    func test_meat_oneMinute_isHeld() {
        XCTAssertEqual(gap(.meatFish, 1).floor, .hold)
    }

    func test_meat_fifteenMinutes_isHeld() {
        XCTAssertEqual(gap(.meatFish, 15).floor, .hold)
    }

    func test_meat_sixteenMinutes_isVetoedRejection() {
        let a = gap(.meatFish, 16)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed)
    }

    // --- Cold chain, dairy and chilled prepared: 15 clean, 30 held, past that rejected ---

    func test_dairy_fifteenMinutes_isClean() {
        XCTAssertEqual(gap(.dairy, 15).floor, .none)
    }

    func test_dairy_sixteenMinutes_isHeld() {
        XCTAssertEqual(gap(.dairy, 16).floor, .hold)
    }

    func test_dairy_thirtyMinutes_isHeld() {
        XCTAssertEqual(gap(.dairy, 30).floor, .hold)
    }

    func test_dairy_fortyMinutes_isVetoedRejection() {
        let a = gap(.dairy, 40)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed, "the Sky&More yoghurt case")
    }

    func test_chilledPrepared_followsTheDairyThresholds() {
        XCTAssertEqual(gap(.chilledPrepared, 30).floor, .hold)
        XCTAssertEqual(gap(.chilledPrepared, 31).floor, .reject)
    }

    // --- Cold chain, frozen: zero tolerance, hold to 20 ---

    func test_frozen_twentyMinutes_isHeld() {
        XCTAssertEqual(gap(.frozen, 20).floor, .hold)
    }

    func test_frozen_twentyOneMinutes_isVetoedRejection() {
        XCTAssertTrue(gap(.frozen, 21).vetoed)
    }

    // --- Cold chain does not apply to ambient goods ---

    func test_ambientAndProduceAndBakery_ignoreColdChainEntirely() {
        XCTAssertEqual(gap(.ambient, 500), .clean)
        XCTAssertEqual(gap(.produce, 500), .clean)
        XCTAssertEqual(gap(.bakery, 500), .clean)
    }

    // --- Penalty: one point per started 10 minutes, while not vetoed ---

    func test_toleratedGapCostsOnePointPerStartedTenMinutes() {
        XCTAssertEqual(gap(.dairy, 5).penalty, 1.0, accuracy: 0.001)
        XCTAssertEqual(gap(.dairy, 10).penalty, 1.0, accuracy: 0.001)
        XCTAssertEqual(gap(.dairy, 11).penalty, 2.0, accuracy: 0.001)
    }

    // --- Temperature ---

    func test_chilledAtFourDegrees_isClean() {
        XCTAssertEqual(temp(.dairy, 4.0).floor, .none)
    }

    func test_chilledAtSixDegrees_isHeld() {
        XCTAssertEqual(temp(.dairy, 6.0).floor, .hold)
    }

    func test_chilledAtNineDegrees_isVetoedRejection() {
        let a = temp(.dairy, 9.0)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed)
    }

    func test_frozenAtMinusEighteen_isClean() {
        XCTAssertEqual(temp(.frozen, -18.0).floor, .none)
    }

    func test_frozenAtMinusFifteen_isHeld() {
        XCTAssertEqual(temp(.frozen, -15.0).floor, .hold)
    }

    func test_frozenAtMinusTen_isVetoedRejection() {
        XCTAssertTrue(temp(.frozen, -10.0).vetoed)
    }

    func test_ambientTemperatureIsIgnored() {
        XCTAssertEqual(temp(.ambient, 25.0), .clean)
        XCTAssertEqual(temp(.bakery, 25.0), .clean)
    }

    func test_noTemperatureDeclared_isClean() {
        XCTAssertEqual(temp(.dairy, nil), .clean)
    }
}

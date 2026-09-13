import XCTest
@testable import RescueTriage

final class ModelTests: XCTestCase {

    func test_coldChainGapIsTheOnlyNonCosmeticReason() {
        let nonCosmetic = RejectReason.allCases.filter { !$0.isCosmetic }
        XCTAssertEqual(nonCosmetic, [.coldChainGap])
    }

    func test_everyReasonHasANonEmptyLabel() {
        for reason in RejectReason.allCases {
            XCTAssertFalse(reason.label.isEmpty, "\(reason) has no label")
        }
    }

    func test_outcomeOrdering() {
        XCTAssertTrue(Outcome.rejected.isWorse(than: .heldForHuman))
        XCTAssertTrue(Outcome.heldForHuman.isWorse(than: .accepted))
        XCTAssertFalse(Outcome.accepted.isWorse(than: .rejected))
        XCTAssertFalse(Outcome.accepted.isWorse(than: .accepted))
    }

    func test_observationDecodesGeminiShapedJSONWithoutIDs() throws {
        let json = """
        {
          "damageSeverity": 2,
          "packagingIntegrity": "dented",
          "spoilageSigns": [],
          "labelLegible": true,
          "observedProduct": "yoghurt case",
          "observedQuantityPlausible": true,
          "discrepancies": [
            { "field": "packaging", "declared": "slight dent", "observed": "corner torn", "severity": "major" }
          ],
          "visualNotes": "Outer carton scuffed."
        }
        """.data(using: .utf8)!

        let observation = try JSONDecoder().decode(ScanObservation.self, from: json)
        XCTAssertEqual(observation.damageSeverity, 2)
        XCTAssertEqual(observation.packagingIntegrity, .dented)
        XCTAssertEqual(observation.discrepancies.count, 1)
        XCTAssertEqual(observation.discrepancies[0].severity, .major)
    }

    func test_coldSensitiveCategories() {
        XCTAssertTrue(ProductCategory.dairy.isColdSensitive)
        XCTAssertTrue(ProductCategory.meatFish.isColdSensitive)
        XCTAssertTrue(ProductCategory.chilledPrepared.isColdSensitive)
        XCTAssertTrue(ProductCategory.frozen.isColdSensitive)
        XCTAssertFalse(ProductCategory.bakery.isColdSensitive)
        XCTAssertFalse(ProductCategory.produce.isColdSensitive)
        XCTAssertFalse(ProductCategory.ambient.isColdSensitive)
    }
}

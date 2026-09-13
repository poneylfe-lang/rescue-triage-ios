import XCTest
@testable import RescueTriage

final class DemoBatchTests: XCTestCase {

    func test_twelveBatchesLoadFromTheBundle() {
        XCTAssertEqual(DemoBatch.all.count, 12)
    }

    func test_everyBatchHasASupplierFromTheConceptSite() {
        let known: Set<String> = [
            "Rimi", "Maxima", "Lidl", "Sky&More", "Barbora", "Elvi",
            "top!", "Mego", "Aibe", "LaTS", "Your Neighbour Grocery", "Baltic Fresh"
        ]
        for batch in DemoBatch.all {
            XCTAssertTrue(known.contains(batch.declaration.supplier),
                          "\(batch.declaration.supplier) is not one of the site's feeders")
        }
    }

    func test_eachBatchProducesItsExpectedVerdict() {
        let now = Date()
        for batch in DemoBatch.all {
            guard let expected = batch.expectedOutcome else { continue }
            let verdict = VerdictEngine.evaluate(
                declaration: batch.declaration,
                observation: batch.syntheticObservation,
                now: now
            )
            XCTAssertEqual(verdict.outcome, expected,
                           "\(batch.declaration.supplier) · \(batch.declaration.productName)")
        }
    }

    func test_theSkyAndMoreYoghurtIsRejectedByVetoDespiteACleanPhoto() {
        let batch = try! XCTUnwrap(DemoBatch.all.first { $0.declaration.supplier == "Sky&More" })
        let verdict = VerdictEngine.evaluate(
            declaration: batch.declaration, observation: .unavailable, now: Date()
        )
        XCTAssertEqual(verdict.outcome, .rejected)
        XCTAssertTrue(verdict.vetoed)
    }

    func test_batchesCoverAllThreeOutcomes() {
        let outcomes = Set(DemoBatch.all.compactMap(\.expectedOutcome))
        XCTAssertTrue(outcomes.contains(.accepted))
        XCTAssertTrue(outcomes.contains(.heldForHuman))
        XCTAssertTrue(outcomes.contains(.rejected))
    }
}

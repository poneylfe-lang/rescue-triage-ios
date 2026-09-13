import XCTest
@testable import RescueTriage

@MainActor
final class SessionStoreTests: XCTestCase {

    private func declaration(weight: Double, price: Decimal, quantity: Double = 1) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Rimi", productName: "Test", category: .ambient,
            quantity: quantity, unit: "case", arrivalDate: Date(), expiryDate: Date(),
            expiryKind: .bestBefore, declaredReason: .discontinued,
            coldChainGapMinutes: nil, storageTempC: nil,
            retailUnitPrice: price, estimatedWeightKg: weight
        )
    }

    private func verdict(_ outcome: Outcome) -> Verdict {
        Verdict(outcome: outcome, score: 8, reasons: [], discrepancies: [],
                vetoed: false, humanOverride: nil, sellToday: false, partial: false)
    }

    func test_freshSessionIsEmpty() {
        let store = SessionStore(queue: [])
        XCTAssertEqual(store.tally.count, 0)
        XCTAssertEqual(store.tally.kgDiverted, 0, accuracy: 0.001)
    }

    func test_acceptedItemAddsWeightAndValue() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 21, price: 1.9, quantity: 42),
                     verdict: verdict(.accepted))
        XCTAssertEqual(store.tally.accepted, 1)
        XCTAssertEqual(store.tally.kgDiverted, 21, accuracy: 0.001)
        XCTAssertEqual(store.tally.valueRecovered, Decimal(1.9) * 42)
    }

    func test_rejectedItemCountsButDivertsNothing() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 8, price: 22), verdict: verdict(.rejected))
        XCTAssertEqual(store.tally.rejected, 1)
        XCTAssertEqual(store.tally.kgDiverted, 0, accuracy: 0.001)
        XCTAssertEqual(store.tally.valueRecovered, 0)
    }

    func test_heldItemCountsButDivertsNothingUntilDecided() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 5, price: 3), verdict: verdict(.heldForHuman))
        XCTAssertEqual(store.tally.held, 1)
        XCTAssertEqual(store.tally.kgDiverted, 0, accuracy: 0.001)
    }

    func test_humanOverrideMovesTheItemInTheTally() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 5, price: 3), verdict: verdict(.heldForHuman))
        let id = try! XCTUnwrap(store.processed.first?.id)

        store.applyOverride(.accepted, to: id)

        XCTAssertEqual(store.tally.held, 0)
        XCTAssertEqual(store.tally.accepted, 1)
        XCTAssertEqual(store.tally.kgDiverted, 5, accuracy: 0.001)
    }

    func test_recordingRemovesTheItemFromTheQueue() {
        let batch = DemoBatch.all[0]
        let store = SessionStore(queue: [batch.declaration])
        XCTAssertEqual(store.queue.count, 1)
        store.record(declaration: batch.declaration, verdict: verdict(.accepted))
        XCTAssertTrue(store.queue.isEmpty)
    }

    func test_resetClearsEverything() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 5, price: 3), verdict: verdict(.accepted))
        store.reset()
        XCTAssertEqual(store.tally.count, 0)
        XCTAssertTrue(store.processed.isEmpty)
        XCTAssertEqual(store.queue.count, DemoBatch.all.count)
    }
}

import XCTest
@testable import RescueTriage

final class VerdictEngineTests: XCTestCase {

    private let now = ISO8601DateFormatter().date(from: "2026-09-13T09:00:00Z")!
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func declaration(
        category: ProductCategory = .produce,
        expiryKind: ExpiryKind = .bestBefore,
        expiryOffsetDays: Int = 5,
        reason: RejectReason = .calibreOut,
        gap: Int? = nil,
        temp: Double? = nil
    ) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Elvi", productName: "Apples", category: category,
            quantity: 6, unit: "crates", arrivalDate: now,
            expiryDate: calendar.date(byAdding: .day, value: expiryOffsetDays, to: now)!,
            expiryKind: expiryKind, declaredReason: reason,
            coldChainGapMinutes: gap, storageTempC: temp,
            retailUnitPrice: 12, estimatedWeightKg: 60
        )
    }

    private func observation(
        damage: Int = 0,
        packaging: PackagingIntegrity = .intact,
        spoilage: [String] = [],
        discrepancies: [Discrepancy] = []
    ) -> ScanObservation {
        ScanObservation(
            damageSeverity: damage, packagingIntegrity: packaging,
            spoilageSigns: spoilage, labelLegible: true,
            observedProduct: "apples", observedQuantityPlausible: true,
            discrepancies: discrepancies, visualNotes: ""
        )
    }

    private func evaluate(
        _ d: SupplierDeclaration, _ o: ScanObservation, geminiAvailable: Bool = true
    ) -> Verdict {
        VerdictEngine.evaluate(declaration: d, observation: o, now: now,
                               calendar: calendar, geminiAvailable: geminiAvailable)
    }

    // --- Priority 1: the safety veto beats everything ---

    func test_pristineProductWithPassedUseBy_isRejected() {
        let v = evaluate(declaration(category: .dairy, expiryKind: .useBy, expiryOffsetDays: -1),
                         observation())
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
        XCTAssertGreaterThanOrEqual(v.score, 7.0, "the photo looked fine — the veto is why it failed")
    }

    func test_spoilageSignsVeto() {
        let v = evaluate(declaration(), observation(spoilage: ["mould on the rind"]))
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
    }

    func test_breachedPackagingVetoes() {
        let v = evaluate(declaration(), observation(packaging: .breached))
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
    }

    func test_theSkyAndMoreYoghurtCase() {
        let v = evaluate(
            declaration(category: .dairy, expiryKind: .useBy, expiryOffsetDays: 2,
                        reason: .coldChainGap, gap: 40),
            observation()
        )
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
    }

    // --- Priority 3: a rule floor holds a high score down ---

    func test_majorDiscrepancyForcesHoldDespiteHighScore() {
        let major = Discrepancy(field: "packaging", declared: "small dent",
                                observed: "corner torn open", severity: .major)
        let v = evaluate(declaration(), observation(discrepancies: [major]))
        XCTAssertEqual(v.score, 8.0, accuracy: 0.001)
        XCTAssertEqual(v.outcome, .heldForHuman, "score says accept; the contradiction says look at it")
        XCTAssertFalse(v.vetoed)
    }

    func test_minorDiscrepancyDoesNotForceHold() {
        let minor = Discrepancy(field: "quantity", declared: "6", observed: "5", severity: .minor)
        XCTAssertEqual(evaluate(declaration(), observation(discrepancies: [minor])).outcome, .accepted)
    }

    // --- Priority 4: score bands ---

    func test_scoreBandBoundaries() {
        // 10 - 1.5*2 = 7.0 → accepted
        XCTAssertEqual(evaluate(declaration(), observation(damage: 2)).outcome, .accepted)
        // 10 - 1.5*2 - 0.5 = 6.5 → held
        XCTAssertEqual(evaluate(declaration(), observation(damage: 2, packaging: .dented)).outcome,
                       .heldForHuman)
        // 10 - 1.5*4 = 4.0 → held
        XCTAssertEqual(evaluate(declaration(), observation(damage: 4)).outcome, .heldForHuman)
        // 10 - 1.5*4 - 2.0 = 2.0 → rejected
        XCTAssertEqual(evaluate(declaration(), observation(damage: 4, packaging: .compromised)).outcome,
                       .rejected)
    }

    // --- Cosmetic reasons ---

    func test_everyCosmeticReasonOnACleanPhotoIsAccepted() {
        for reason in RejectReason.allCases where reason.isCosmetic {
            let v = evaluate(declaration(reason: reason), observation())
            XCTAssertEqual(v.outcome, .accepted, "\(reason) should sail through")
            XCTAssertEqual(v.score, 10.0, accuracy: 0.001)
        }
    }

    // --- Sell-today flag ---

    func test_useByTodayIsAcceptedAndFlagged() {
        let v = evaluate(declaration(category: .bakery, expiryKind: .useBy, expiryOffsetDays: 0),
                         observation())
        XCTAssertEqual(v.outcome, .accepted)
        XCTAssertTrue(v.sellToday)
        XCTAssertEqual(v.score, 9.0, accuracy: 0.001)
    }

    // --- Degraded mode ---

    func test_withoutGeminiTheVerdictIsMarkedPartialButStillRuns() {
        let v = evaluate(declaration(category: .dairy, expiryKind: .useBy, expiryOffsetDays: -1),
                         .unavailable, geminiAvailable: false)
        XCTAssertTrue(v.partial)
        XCTAssertEqual(v.outcome, .rejected, "the regulatory half still stands on its own")
    }

    func test_reasonsAreNeverEmpty() {
        XCTAssertFalse(evaluate(declaration(), observation()).reasons.isEmpty)
    }
}

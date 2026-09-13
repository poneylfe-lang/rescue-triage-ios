import XCTest
@testable import RescueTriage

final class ExpiryRuleTests: XCTestCase {

    private let now = ISO8601DateFormatter().date(from: "2026-09-13T09:00:00Z")!
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func declaration(_ kind: ExpiryKind, daysFromNow: Int) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Rimi", productName: "Test", category: .ambient,
            quantity: 1, unit: "case",
            arrivalDate: now, expiryDate: calendar.date(byAdding: .day, value: daysFromNow, to: now)!,
            expiryKind: kind, declaredReason: .discontinued,
            coldChainGapMinutes: nil, storageTempC: nil,
            retailUnitPrice: 1, estimatedWeightKg: 1
        )
    }

    private func assess(_ kind: ExpiryKind, _ days: Int) -> RuleAssessment {
        SafetyRules.expiry(declaration: declaration(kind, daysFromNow: days), now: now, calendar: calendar)
    }

    // --- Use-by (DLC) ---

    func test_useByPassedYesterday_isVetoedRejection() {
        let a = assess(.useBy, -1)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed)
    }

    func test_useByToday_isAcceptedAndFlaggedSellToday() {
        let a = assess(.useBy, 0)
        XCTAssertEqual(a.floor, .none)
        XCTAssertFalse(a.vetoed)
        XCTAssertTrue(a.sellToday)
        XCTAssertEqual(a.penalty, 1.0, accuracy: 0.001)
    }

    func test_useByTomorrow_isClean() {
        let a = assess(.useBy, 1)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.0, accuracy: 0.001)
        XCTAssertFalse(a.sellToday)
    }

    // --- Best-before (DDM) ---

    func test_bestBeforeNotYetPassed_isClean() {
        let a = assess(.bestBefore, 5)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.0, accuracy: 0.001)
    }

    func test_bestBeforeOneDayOver_isAcceptedWithSmallPenalty() {
        let a = assess(.bestBefore, -1)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.5, accuracy: 0.001)
    }

    func test_bestBefore30DaysOver_isStillAccepted() {
        let a = assess(.bestBefore, -30)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.5, accuracy: 0.001)
    }

    func test_bestBefore31DaysOver_isHeld() {
        let a = assess(.bestBefore, -31)
        XCTAssertEqual(a.floor, .hold)
        XCTAssertEqual(a.penalty, 1.0, accuracy: 0.001)
    }

    func test_bestBefore90DaysOver_isHeld() {
        XCTAssertEqual(assess(.bestBefore, -90).floor, .hold)
    }

    func test_bestBefore91DaysOver_isRejectedButNotVetoed() {
        let a = assess(.bestBefore, -91)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertFalse(a.vetoed, "unsellable quality is not a food-safety veto")
    }
}

import Foundation

enum Outcome: String, Codable, CaseIterable {
    case accepted
    case heldForHuman
    case rejected

    var label: String {
        switch self {
        case .accepted: "ACCEPTED"
        case .heldForHuman: "HELD"
        case .rejected: "REJECTED"
        }
    }

    /// Severity ranking. Rules may only ever push a verdict further down this
    /// order, never back up it.
    var severity: Int {
        switch self {
        case .accepted: 0
        case .heldForHuman: 1
        case .rejected: 2
        }
    }

    func isWorse(than other: Outcome) -> Bool { severity > other.severity }
}

struct VerdictReason: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var code: String
    var label: String

    private enum CodingKeys: String, CodingKey { case code, label }

    init(_ code: String, _ label: String) {
        self.code = code
        self.label = label
    }
}

struct Verdict: Codable, Equatable {
    var outcome: Outcome
    var score: Double
    var reasons: [VerdictReason]
    var discrepancies: [Discrepancy]
    /// True when a food-safety rule forced the rejection. Nothing overrides it.
    var vetoed: Bool
    /// Set when an operator overruled a held verdict.
    var humanOverride: Outcome?
    var sellToday: Bool
    /// True when Gemini was unreachable and only the regulatory rules ran.
    var partial: Bool

    /// What the session tally counts: the human's call when there was one.
    var effectiveOutcome: Outcome { humanOverride ?? outcome }
}

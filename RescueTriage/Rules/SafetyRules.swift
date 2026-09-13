import Foundation

/// The worst outcome a rule insists on. Rules set floors; they never set
/// ceilings. A floor of `.hold` means "no better than held".
enum RuleFloor: Int, Equatable {
    case none = 0
    case hold = 1
    case reject = 2

    var asOutcome: Outcome? {
        switch self {
        case .none: nil
        case .hold: .heldForHuman
        case .reject: .rejected
        }
    }
}

/// One rule's finding: how far it forces the verdict down, whether that force is
/// a food-safety veto, what it costs in score, and why.
struct RuleAssessment: Equatable {
    var floor: RuleFloor = .none
    var vetoed: Bool = false
    var penalty: Double = 0
    var sellToday: Bool = false
    var reasons: [VerdictReason] = []

    static let clean = RuleAssessment()

    /// Combine findings: worst floor wins, any veto sticks, penalties add up.
    static func merge(_ assessments: [RuleAssessment]) -> RuleAssessment {
        RuleAssessment(
            floor: assessments.map(\.floor).max(by: { $0.rawValue < $1.rawValue }) ?? .none,
            vetoed: assessments.contains(where: \.vetoed),
            penalty: assessments.reduce(0) { $0 + $1.penalty },
            sellToday: assessments.contains(where: \.sellToday),
            reasons: assessments.flatMap(\.reasons)
        )
    }
}

/// Every date, temperature and cold-chain decision. Pure functions: no network,
/// no disk, no ambient clock. That is what makes the boundaries testable, and
/// it is why these rules — not the language model — hold the veto.
enum SafetyRules {

    // MARK: Expiry

    static func expiry(
        declaration: SupplierDeclaration,
        now: Date,
        calendar: Calendar = .current
    ) -> RuleAssessment {
        let today = calendar.startOfDay(for: now)
        let expiry = calendar.startOfDay(for: declaration.expiryDate)
        let daysLeft = calendar.dateComponents([.day], from: today, to: expiry).day ?? 0

        switch declaration.expiryKind {
        case .useBy:
            if daysLeft < 0 {
                return RuleAssessment(
                    floor: .reject,
                    vetoed: true,
                    reasons: [VerdictReason("expiry.useBy.passed",
                                            "Use-by date passed \(-daysLeft) day(s) ago — food safety, no appeal")]
                )
            }
            if daysLeft == 0 {
                return RuleAssessment(
                    penalty: 1.0,
                    sellToday: true,
                    reasons: [VerdictReason("expiry.useBy.today", "Use-by is today — sell today")]
                )
            }
            return .clean

        case .bestBefore:
            guard daysLeft < 0 else { return .clean }
            let daysOver = -daysLeft
            let blocks = Int(ceil(Double(daysOver) / 30.0))
            let penalty = Double(blocks) * 0.5

            if daysOver > 90 {
                return RuleAssessment(
                    floor: .reject,
                    vetoed: false,
                    penalty: penalty,
                    reasons: [VerdictReason("expiry.bestBefore.unsellable",
                                            "Best-before passed \(daysOver) days ago — past sellable quality")]
                )
            }
            if daysOver > 30 {
                return RuleAssessment(
                    floor: .hold,
                    penalty: penalty,
                    reasons: [VerdictReason("expiry.bestBefore.long",
                                            "Best-before passed \(daysOver) days ago — needs a taste call")]
                )
            }
            return RuleAssessment(
                penalty: penalty,
                reasons: [VerdictReason("expiry.bestBefore.short",
                                        "Best-before passed \(daysOver) day(s) ago — legal to sell, and our business")]
            )
        }
    }
}

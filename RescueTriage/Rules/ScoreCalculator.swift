import Foundation

/// Sellability out of 10, on the same scale the concept site's triage log uses.
///
/// The declared reject reason contributes nothing when it is cosmetic, which is
/// the whole inversion Rescue runs on: a supermarket refuses goods for looking
/// wrong, and that costs us zero points because looking wrong is what we sell.
enum ScoreCalculator {

    static func score(
        declaration: SupplierDeclaration,
        observation: ScanObservation,
        ruleAssessment: RuleAssessment
    ) -> Double {
        var score = 10.0

        score -= Double(observation.damageSeverity) * 1.5

        switch observation.packagingIntegrity {
        case .intact: break
        case .dented: score -= 0.5
        case .compromised: score -= 2.0
        case .breached: score -= 10.0  // vetoed anyway; floor it so the number matches the verdict
        }

        if !observation.labelLegible { score -= 0.5 }

        for discrepancy in observation.discrepancies {
            score -= discrepancy.severity == .major ? 2.0 : 1.0
        }

        // Expiry pressure and tolerated cold-chain gaps, already quantified by the rules.
        score -= ruleAssessment.penalty

        // Cosmetic reasons are deliberately free. No branch needed — this line
        // documents the absence.
        _ = declaration.declaredReason.isCosmetic

        return min(10.0, max(0.0, score))
    }
}

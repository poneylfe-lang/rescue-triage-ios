import Foundation

/// Fuses the deterministic rules with the model's visual reading.
///
/// The order below is the whole safety argument of this app. Gemini describes
/// the photograph; it never decides. A rule can push a verdict down the
/// severity ladder, never back up it.
enum VerdictEngine {

    static func evaluate(
        declaration: SupplierDeclaration,
        observation: ScanObservation,
        now: Date,
        calendar: Calendar = .current,
        geminiAvailable: Bool = true
    ) -> Verdict {

        let rules = RuleAssessment.merge([
            SafetyRules.expiry(declaration: declaration, now: now, calendar: calendar),
            SafetyRules.coldChain(category: declaration.category,
                                  gapMinutes: declaration.coldChainGapMinutes),
            SafetyRules.temperature(category: declaration.category,
                                    tempC: declaration.storageTempC),
            visualVeto(observation)
        ])

        let score = ScoreCalculator.score(
            declaration: declaration, observation: observation, ruleAssessment: rules
        )

        var reasons = rules.reasons
        reasons.append(contentsOf: observationReasons(observation))
        if declaration.declaredReason.isCosmetic {
            reasons.append(VerdictReason(
                "reason.cosmetic",
                "Supplier's reason — \(declaration.declaredReason.label.lowercased()) — is exactly what we sell"
            ))
        }
        if !geminiAvailable {
            reasons.append(VerdictReason(
                "gemini.unavailable",
                "Photo analysis unavailable — regulatory checks only"
            ))
        }

        let hasMajorDiscrepancy = observation.discrepancies.contains { $0.severity == .major }
        if hasMajorDiscrepancy {
            reasons.append(VerdictReason(
                "discrepancy.major",
                "Photo contradicts the declaration — a human decides this one"
            ))
        }

        return Verdict(
            outcome: resolve(score: score, rules: rules, hasMajorDiscrepancy: hasMajorDiscrepancy),
            score: score,
            reasons: reasons,
            discrepancies: observation.discrepancies,
            vetoed: rules.vetoed,
            humanOverride: nil,
            sellToday: rules.sellToday,
            partial: !geminiAvailable
        )
    }

    /// Priority order, first match wins. See spec §6.
    private static func resolve(
        score: Double, rules: RuleAssessment, hasMajorDiscrepancy: Bool
    ) -> Outcome {
        // 1. Food-safety veto. Nothing annuls it.
        if rules.vetoed { return .rejected }

        // 2–3. A rule floor. It may only make the verdict worse.
        let band = band(for: score)
        var outcome = band
        if let floor = rules.floor.asOutcome, floor.isWorse(than: outcome) {
            outcome = floor
        }
        // A contradiction between declaration and photo is never auto-stamped.
        if hasMajorDiscrepancy, Outcome.heldForHuman.isWorse(than: outcome) {
            outcome = .heldForHuman
        }
        return outcome
    }

    /// Spec §6 bands, chosen to reproduce the concept site's own log:
    /// 8.6 / 9.0 / 8.1 / 7.1 pass, 6.2 hold, 3.4 reject.
    private static func band(for score: Double) -> Outcome {
        switch score {
        case 7.0...: .accepted
        case 4.0..<7.0: .heldForHuman
        default: .rejected
        }
    }

    /// The two things in a photograph that are food-safety facts, not opinions.
    private static func visualVeto(_ observation: ScanObservation) -> RuleAssessment {
        var assessments: [RuleAssessment] = []

        if !observation.spoilageSigns.isEmpty {
            assessments.append(RuleAssessment(
                floor: .reject, vetoed: true,
                reasons: [VerdictReason("visual.spoilage",
                                        "Spoilage visible: \(observation.spoilageSigns.joined(separator: ", "))")]
            ))
        }
        if observation.packagingIntegrity == .breached {
            assessments.append(RuleAssessment(
                floor: .reject, vetoed: true,
                reasons: [VerdictReason("visual.breached", "Sealed packaging is breached")]
            ))
        }
        return RuleAssessment.merge(assessments)
    }

    private static func observationReasons(_ observation: ScanObservation) -> [VerdictReason] {
        var reasons: [VerdictReason] = []
        if observation.damageSeverity > 0 {
            reasons.append(VerdictReason("visual.damage",
                                         "Visible damage, severity \(observation.damageSeverity)/4"))
        }
        if observation.packagingIntegrity == .dented || observation.packagingIntegrity == .compromised {
            reasons.append(VerdictReason("visual.packaging",
                                         "Packaging \(observation.packagingIntegrity.label.lowercased()) — contents look unaffected"))
        }
        if !observation.labelLegible {
            reasons.append(VerdictReason("visual.label", "Label not fully legible"))
        }
        return reasons
    }
}

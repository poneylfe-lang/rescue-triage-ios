import Foundation

enum PackagingIntegrity: String, Codable, CaseIterable {
    case intact
    case dented
    case compromised
    case breached

    var label: String {
        switch self {
        case .intact: "Intact"
        case .dented: "Dented"
        case .compromised: "Compromised"
        case .breached: "Breached"
        }
    }
}

/// A contradiction between what the supplier declared and what the photo shows.
/// A supplier who is wrong — or lying — earns a human look, never a rubber stamp.
struct Discrepancy: Codable, Equatable, Identifiable {
    enum Severity: String, Codable {
        case minor
        case major
    }

    var id: UUID = UUID()
    var field: String
    var declared: String
    var observed: String
    var severity: Severity

    private enum CodingKeys: String, CodingKey {
        case field, declared, observed, severity
    }
}

/// What the model saw in the photograph. Description only — no judgement.
/// The verdict is never Gemini's to make.
struct ScanObservation: Codable, Equatable {
    var damageSeverity: Int
    var packagingIntegrity: PackagingIntegrity
    var spoilageSigns: [String]
    var labelLegible: Bool
    var observedProduct: String
    var observedQuantityPlausible: Bool
    var discrepancies: [Discrepancy]
    var visualNotes: String

    /// Used when Gemini could not be reached: describes nothing, penalises
    /// nothing, and lets the safety rules stand on their own.
    static let unavailable = ScanObservation(
        damageSeverity: 0,
        packagingIntegrity: .intact,
        spoilageSigns: [],
        labelLegible: true,
        observedProduct: "",
        observedQuantityPlausible: true,
        discrepancies: [],
        visualNotes: ""
    )
}

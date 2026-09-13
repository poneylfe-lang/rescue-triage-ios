import Foundation

/// A pre-loaded case from the concept site's triage log, ready to demo in one tap.
///
/// Dates are stored as day offsets from "now" rather than absolute dates: a demo
/// with a hard-coded 2026 date stops making sense within a week of shipping.
struct DemoBatch: Identifiable, Equatable {
    var id: UUID { declaration.id }
    var declaration: SupplierDeclaration
    var samplePhotoName: String
    var expectedOutcome: Outcome?
    /// Stand-in for Gemini, so the demo set can be verdict-tested without a network call.
    var syntheticObservation: ScanObservation

    private struct Raw: Decodable {
        let supplier: String
        let productName: String
        let category: ProductCategory
        let quantity: Double
        let unit: String
        let arrivalOffsetDays: Int
        let expiryOffsetDays: Int
        let expiryKind: ExpiryKind
        let declaredReason: RejectReason
        let coldChainGapMinutes: Int?
        let storageTempC: Double?
        let retailUnitPrice: Double
        let estimatedWeightKg: Double
        let samplePhotoName: String
        let expectedOutcome: Outcome?
        let synthetic: ScanObservation
    }

    static let all: [DemoBatch] = load()

    private static func load(now: Date = Date(), calendar: Calendar = .current) -> [DemoBatch] {
        guard let url = Bundle.main.url(forResource: "DemoBatches", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raws = try? JSONDecoder().decode([Raw].self, from: data)
        else {
            assertionFailure("DemoBatches.json missing or malformed — it is bundled, so this is a build problem")
            return []
        }

        return raws.map { raw in
            DemoBatch(
                declaration: SupplierDeclaration(
                    supplier: raw.supplier,
                    productName: raw.productName,
                    category: raw.category,
                    quantity: raw.quantity,
                    unit: raw.unit,
                    arrivalDate: calendar.date(byAdding: .day, value: raw.arrivalOffsetDays, to: now) ?? now,
                    expiryDate: calendar.date(byAdding: .day, value: raw.expiryOffsetDays, to: now) ?? now,
                    expiryKind: raw.expiryKind,
                    declaredReason: raw.declaredReason,
                    coldChainGapMinutes: raw.coldChainGapMinutes,
                    storageTempC: raw.storageTempC,
                    retailUnitPrice: Decimal(raw.retailUnitPrice),
                    estimatedWeightKg: raw.estimatedWeightKg
                ),
                samplePhotoName: raw.samplePhotoName,
                expectedOutcome: raw.expectedOutcome,
                syntheticObservation: raw.synthetic
            )
        }
    }
}

import Foundation

/// Use-by (DLC) versus best-before (DDM). This is the sharpest line in the
/// domain: a passed use-by date is a food-safety rejection with no appeal, while
/// a passed best-before date is Rescue's entire business model. There is
/// deliberately no default value — every declaration must state which it is.
enum ExpiryKind: String, Codable, CaseIterable, Identifiable {
    case useBy
    case bestBefore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .useBy: "Use by (DLC)"
        case .bestBefore: "Best before (DDM)"
        }
    }
}

/// Why the supermarket refused the goods. Vocabulary lifted from the concept
/// site's triage log so the app and the website tell the same story.
enum RejectReason: String, Codable, CaseIterable, Identifiable {
    case endOfDayBake
    case hailMarks
    case calibreOut
    case oldPackaging
    case sellByTomorrow
    case shortShelfLife
    case discontinued
    case postPromoOverstock
    case spottySkin
    case overproduction
    case dentedOuterBox
    case holidaySurplus
    case packagingRedesign
    case shortDatedBatch
    case gradedOutForShape
    case coldChainGap

    var id: String { rawValue }

    /// Cosmetic and commercial reasons cost nothing at all in the score. What a
    /// supermarket throws away for looking wrong is exactly what Rescue sells.
    /// A broken cold chain is the one reason that is about safety, not appearance.
    var isCosmetic: Bool { self != .coldChainGap }

    var label: String {
        switch self {
        case .endOfDayBake: "End-of-day bake"
        case .hailMarks: "Hail marks"
        case .calibreOut: "Out of calibre"
        case .oldPackaging: "Old packaging design"
        case .sellByTomorrow: "Sell-by tomorrow"
        case .shortShelfLife: "Short shelf life left"
        case .discontinued: "Discontinued line"
        case .postPromoOverstock: "Post-promo overstock"
        case .spottySkin: "Spotty skin"
        case .overproduction: "Kitchen overproduction"
        case .dentedOuterBox: "Dented outer box"
        case .holidaySurplus: "Holiday surplus"
        case .packagingRedesign: "Packaging redesign"
        case .shortDatedBatch: "Short-dated batch"
        case .gradedOutForShape: "Graded out for shape"
        case .coldChainGap: "Cold-chain gap"
        }
    }
}

/// What the supplier claims about the goods. Everything here is assertion, not
/// fact — checking it against the photo is the whole point of the app.
struct SupplierDeclaration: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var supplier: String
    var productName: String
    var category: ProductCategory
    var quantity: Double
    var unit: String
    var arrivalDate: Date
    var expiryDate: Date
    var expiryKind: ExpiryKind
    var declaredReason: RejectReason
    var coldChainGapMinutes: Int?
    var storageTempC: Double?
    var retailUnitPrice: Decimal
    var estimatedWeightKg: Double

    private enum CodingKeys: String, CodingKey {
        case supplier, productName, category, quantity, unit
        case arrivalDate, expiryDate, expiryKind, declaredReason
        case coldChainGapMinutes, storageTempC, retailUnitPrice, estimatedWeightKg
    }

    var summaryLine: String {
        "\(formattedQuantity) \(unit) · \(declaredReason.label)"
    }

    var formattedQuantity: String {
        quantity == quantity.rounded()
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
    }
}

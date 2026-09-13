import Foundation

/// What kind of food this is. Drives every cold-chain and temperature threshold,
/// so the cases are deliberately coarse — they match how a supplier's reject list
/// is actually written, not a nutritionist's taxonomy.
enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case dairy
    case bakery
    case produce
    case meatFish
    case chilledPrepared
    case frozen
    case ambient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dairy: "Dairy"
        case .bakery: "Bakery"
        case .produce: "Fruit & veg"
        case .meatFish: "Meat & fish"
        case .chilledPrepared: "Chilled prepared"
        case .frozen: "Frozen"
        case .ambient: "Ambient"
        }
    }

    /// Bakery, produce and ambient goods have no cold chain to break.
    var isColdSensitive: Bool {
        switch self {
        case .dairy, .meatFish, .chilledPrepared, .frozen: true
        case .bakery, .produce, .ambient: false
        }
    }
}

import Foundation
import SwiftUI

/// What the operator has got through so far. This is the number that turns a
/// technical demo into a business case, so it counts the human's decision when
/// one was made, not the machine's first guess.
struct SessionTally: Equatable {
    var count: Int = 0
    var accepted: Int = 0
    var held: Int = 0
    var rejected: Int = 0
    var kgDiverted: Double = 0
    var valueRecovered: Decimal = 0
}

struct ProcessedItem: Identifiable, Equatable {
    let id: UUID
    var declaration: SupplierDeclaration
    var verdict: Verdict
    var processedAt: Date
}

@MainActor
final class SessionStore: ObservableObject {

    @Published private(set) var queue: [SupplierDeclaration]
    @Published private(set) var processed: [ProcessedItem] = []

    init(queue: [SupplierDeclaration]? = nil) {
        self.queue = queue ?? DemoBatch.all.map(\.declaration)
    }

    /// Recomputed rather than accumulated, so an override can never leave the
    /// running totals out of step with the list they summarise.
    var tally: SessionTally {
        processed.reduce(into: SessionTally()) { tally, item in
            tally.count += 1
            switch item.verdict.effectiveOutcome {
            case .accepted:
                tally.accepted += 1
                tally.kgDiverted += item.declaration.estimatedWeightKg
                tally.valueRecovered += item.declaration.retailUnitPrice
                    * Decimal(item.declaration.quantity)
            case .heldForHuman:
                tally.held += 1
            case .rejected:
                tally.rejected += 1
            }
        }
    }

    func add(_ declaration: SupplierDeclaration) {
        queue.append(declaration)
    }

    func record(declaration: SupplierDeclaration, verdict: Verdict) {
        queue.removeAll { $0.id == declaration.id }
        processed.insert(
            ProcessedItem(id: declaration.id, declaration: declaration,
                          verdict: verdict, processedAt: Date()),
            at: 0
        )
    }

    func applyOverride(_ outcome: Outcome, to id: UUID) {
        guard let index = processed.firstIndex(where: { $0.id == id }) else { return }
        processed[index].verdict.humanOverride = outcome
    }

    func reset() {
        processed.removeAll()
        queue = DemoBatch.all.map(\.declaration)
    }
}

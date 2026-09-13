import SwiftUI

struct VerdictCardView: View {
    let declaration: SupplierDeclaration
    let verdict: Verdict
    var onOverride: ((Outcome) -> Void)?
    var onDone: (() -> Void)?

    private var outcome: Outcome { verdict.effectiveOutcome }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                body(for: verdict)
            }
        }
        .background(RescuePalette.cream)
        .safeAreaInset(edge: .bottom) { doneBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(declaration.supplier.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.6)
                .opacity(0.75)

            Text(outcome.label)
                .font(.system(size: 46, weight: .black))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 10) {
                Text(String(format: "%.1f", verdict.score))
                    .font(.system(size: 19, weight: .heavy, design: .monospaced))
                Text("/ 10 sellability")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.8)

                if verdict.vetoed {
                    Spacer()
                    Label("SAFETY VETO", systemImage: "exclamationmark.octagon.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.black.opacity(0.22), in: Capsule())
                }
            }

            if verdict.sellToday {
                Label("Sell today", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            if verdict.humanOverride != nil {
                Label("Operator decision", systemImage: "person.fill.checkmark")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RescuePalette.background(for: outcome))
        .foregroundStyle(RescuePalette.foreground(for: outcome))
    }

    @ViewBuilder
    private func body(for verdict: Verdict) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(declaration.productName) · \(declaration.category.label)")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 20)

            if verdict.partial {
                noticeRow(
                    "Photo analysis unavailable — this verdict rests on the regulatory checks alone.",
                    icon: "wifi.slash"
                )
            }

            if !verdict.discrepancies.isEmpty {
                section("Contradicts the declaration") {
                    ForEach(verdict.discrepancies) { discrepancy in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(discrepancy.field.capitalized)
                                .font(.system(size: 13, weight: .heavy))
                            Text("Declared: \(discrepancy.declared)")
                                .font(.system(size: 13))
                            Text("Photo shows: \(discrepancy.observed)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            (discrepancy.severity == .major ? RescuePalette.orange : RescuePalette.amber)
                                .opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
            }

            section("Why") {
                ForEach(verdict.reasons) { reason in
                    HStack(alignment: .top, spacing: 9) {
                        Text("·").font(.system(size: 15, weight: .black))
                        Text(reason.label).font(.system(size: 14))
                    }
                }
            }

            if outcome == .heldForHuman, let onOverride {
                section("Your call") {
                    HStack(spacing: 10) {
                        overrideButton("Accept", .accepted, RescuePalette.lime, RescuePalette.ink, onOverride)
                        overrideButton("Reject", .rejected, RescuePalette.orange, .white, onOverride)
                    }
                }
            }
        }
        .foregroundStyle(RescuePalette.ink)
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    private func overrideButton(
        _ title: String, _ outcome: Outcome, _ background: Color,
        _ foreground: Color, _ action: @escaping (Outcome) -> Void
    ) -> some View {
        Button { action(outcome) } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(background, in: Capsule())
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private func noticeRow(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RescuePalette.navy.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(RescuePalette.muted)
            content()
        }
    }

    private var doneBar: some View {
        Button { onDone?() } label: {
            Text("Next item")
                .font(.system(size: 16, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RescuePalette.navy, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
        .background(RescuePalette.cream)
    }
}

#Preview("Accepted") {
    VerdictCardView(
        declaration: DemoBatch.all[1].declaration,
        verdict: Verdict(outcome: .accepted, score: 9.0,
                         reasons: [VerdictReason("reason.cosmetic",
                                                 "Supplier's reason — out of calibre — is exactly what we sell")],
                         discrepancies: [], vetoed: false, humanOverride: nil,
                         sellToday: false, partial: false)
    )
}

#Preview("Vetoed") {
    VerdictCardView(
        declaration: DemoBatch.all[11].declaration,
        verdict: Verdict(outcome: .rejected, score: 8.0,
                         reasons: [VerdictReason("coldChain.broken",
                                                 "40 min cold-chain gap on dairy — over the 30 min limit")],
                         discrepancies: [], vetoed: true, humanOverride: nil,
                         sellToday: false, partial: false)
    )
}

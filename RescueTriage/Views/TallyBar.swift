import SwiftUI

/// The running session total. This is the line that makes the demo a business
/// case rather than a gadget.
struct TallyBar: View {
    let tally: SessionTally

    private var euros: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: tally.valueRecovered as NSDecimalNumber) ?? "—"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                cell("\(tally.count)", "triaged")
                cell("\(tally.accepted)", "accepted", tint: RescuePalette.lime)
                cell("\(tally.held)", "held", tint: RescuePalette.amber)
                cell("\(tally.rejected)", "rejected", tint: RescuePalette.orange)
            }
            if tally.count > 0 {
                HStack(spacing: 18) {
                    Text("\(String(format: "%.0f", tally.kgDiverted)) kg out of the bin")
                    Text("·")
                    Text("\(euros) recovered")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RescuePalette.navy)
    }

    private func cell(_ value: String, _ label: String, tint: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

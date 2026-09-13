import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var selected: SupplierDeclaration?
    @State private var showingEditor = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TallyBar(tally: store.tally)
                list
            }
            .background(RescuePalette.cream)
            .navigationTitle("Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(item: $selected) { declaration in
                DeclarationView(declaration: declaration)
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    DeclarationEditor { store.add($0) }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }

    private var list: some View {
        List {
            if !store.queue.isEmpty {
                Section("Waiting") {
                    ForEach(store.queue) { declaration in
                        Button { selected = declaration } label: { row(declaration) }
                            .buttonStyle(.plain)
                    }
                }
            }
            if !store.processed.isEmpty {
                Section("Done") {
                    ForEach(store.processed) { item in
                        processedRow(item)
                    }
                }
            }
            if store.queue.isEmpty && store.processed.isEmpty {
                Text("Nothing in the queue.")
                    .foregroundStyle(RescuePalette.muted)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(_ declaration: SupplierDeclaration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(declaration.supplier.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(RescuePalette.orange)
            Text(declaration.productName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RescuePalette.ink)
            Text(declaration.summaryLine)
                .font(.system(size: 13))
                .foregroundStyle(RescuePalette.muted)
        }
        .padding(.vertical, 4)
    }

    private func processedRow(_ item: ProcessedItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.declaration.productName)
                    .font(.system(size: 15, weight: .semibold))
                Text(item.declaration.supplier)
                    .font(.system(size: 12))
                    .foregroundStyle(RescuePalette.muted)
            }
            Spacer()
            Text(item.verdict.effectiveOutcome.label)
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(
                    RescuePalette.background(for: item.verdict.effectiveOutcome),
                    in: Capsule()
                )
                .foregroundStyle(RescuePalette.foreground(for: item.verdict.effectiveOutcome))
        }
    }
}

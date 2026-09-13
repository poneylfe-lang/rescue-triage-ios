import SwiftUI

/// Read the supplier's claims, correct anything wrong, then go and photograph it.
struct DeclarationView: View {
    let declaration: SupplierDeclaration
    @State private var editable: SupplierDeclaration
    @State private var scanning = false

    init(declaration: SupplierDeclaration) {
        self.declaration = declaration
        _editable = State(initialValue: declaration)
    }

    var body: some View {
        Form {
            Section("Supplier") {
                LabeledContent("Store", value: editable.supplier)
                LabeledContent("Product", value: editable.productName)
                LabeledContent("Category", value: editable.category.label)
                LabeledContent("Quantity",
                               value: "\(editable.formattedQuantity) \(editable.unit)")
            }

            Section("Dates") {
                DatePicker("Arrived at supplier", selection: $editable.arrivalDate,
                           displayedComponents: .date)
                Picker("Date type", selection: $editable.expiryKind) {
                    ForEach(ExpiryKind.allCases) { Text($0.label).tag($0) }
                }
                DatePicker(editable.expiryKind.label, selection: $editable.expiryDate,
                           displayedComponents: .date)
            }

            Section("Their stated problem") {
                Picker("Reason", selection: $editable.declaredReason) {
                    ForEach(RejectReason.allCases) { Text($0.label).tag($0) }
                }
                if editable.declaredReason.isCosmetic {
                    Label("Cosmetic — costs nothing in our scoring",
                          systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RescuePalette.muted)
                }
            }

            if editable.category.isColdSensitive {
                Section("Cold chain") {
                    Stepper(
                        editable.coldChainGapMinutes.map { "Gap: \($0) min" } ?? "No gap declared",
                        value: Binding(
                            get: { editable.coldChainGapMinutes ?? 0 },
                            set: { editable.coldChainGapMinutes = $0 == 0 ? nil : $0 }
                        ),
                        in: 0...180, step: 5
                    )
                    if let temp = editable.storageTempC {
                        LabeledContent("Storage temperature",
                                       value: String(format: "%.1f °C", temp))
                    }
                }
            }
        }
        .navigationTitle("Declaration")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { scanning = true } label: {
                Label("Scan the product", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RescuePalette.orange, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .navigationDestination(isPresented: $scanning) {
            ScanView(declaration: editable)
        }
    }
}

/// Manual entry, for the cases the pre-loaded batches do not cover.
struct DeclarationEditor: View {
    var onSave: (SupplierDeclaration) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var supplier = "Rimi"
    @State private var productName = ""
    @State private var category: ProductCategory = .produce
    @State private var quantity = 1.0
    @State private var unit = "crates"
    @State private var arrivalDate = Date()
    @State private var expiryDate = Date()
    @State private var expiryKind: ExpiryKind = .bestBefore
    @State private var reason: RejectReason = .calibreOut
    @State private var coldChainGap = 0
    @State private var storageTemp = ""
    @State private var price = "1.00"
    @State private var weight = "10"

    private static let suppliers = [
        "Rimi", "Maxima", "Lidl", "Sky&More", "Barbora", "Elvi",
        "top!", "Mego", "Aibe", "LaTS", "Your Neighbour Grocery", "Baltic Fresh"
    ]

    var body: some View {
        Form {
            Section("Supplier") {
                Picker("Store", selection: $supplier) {
                    ForEach(Self.suppliers, id: \.self) { Text($0).tag($0) }
                }
                TextField("Product", text: $productName)
                Picker("Category", selection: $category) {
                    ForEach(ProductCategory.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    TextField("Quantity", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Unit", text: $unit)
                }
            }
            Section("Dates") {
                DatePicker("Arrived at supplier", selection: $arrivalDate, displayedComponents: .date)
                Picker("Date type", selection: $expiryKind) {
                    ForEach(ExpiryKind.allCases) { Text($0.label).tag($0) }
                }
                DatePicker(expiryKind.label, selection: $expiryDate, displayedComponents: .date)
            }
            Section("Their stated problem") {
                Picker("Reason", selection: $reason) {
                    ForEach(RejectReason.allCases) { Text($0.label).tag($0) }
                }
            }
            if category.isColdSensitive {
                Section("Cold chain") {
                    Stepper("Gap: \(coldChainGap) min", value: $coldChainGap, in: 0...180, step: 5)
                    TextField("Storage temperature °C", text: $storageTemp)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            Section("Economics") {
                TextField("Unit price €", text: $price).keyboardType(.decimalPad)
                TextField("Total weight kg", text: $weight).keyboardType(.decimalPad)
            }
        }
        .navigationTitle("New item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        onSave(SupplierDeclaration(
            supplier: supplier,
            productName: productName,
            category: category,
            quantity: quantity,
            unit: unit,
            arrivalDate: arrivalDate,
            expiryDate: expiryDate,
            expiryKind: expiryKind,
            declaredReason: reason,
            coldChainGapMinutes: coldChainGap == 0 ? nil : coldChainGap,
            storageTempC: Double(storageTemp.replacingOccurrences(of: ",", with: ".")),
            retailUnitPrice: Decimal(Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0),
            estimatedWeightKg: Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        ))
        dismiss()
    }
}

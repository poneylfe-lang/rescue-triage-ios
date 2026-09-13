import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var model = UserDefaults.standard.string(forKey: "gemini.model")
        ?? GeminiClient.defaultModel
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                SecureField("AIza…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Model", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save") { save() }
                if saved {
                    Label("Saved to the Keychain", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(RescuePalette.muted)
                        .font(.system(size: 13, weight: .semibold))
                }
            } header: {
                Text("Gemini")
            } footer: {
                Text("""
                The key is stored in this device's Keychain and never leaves it except \
                in calls to Google. Without a key the app still runs: it applies the \
                expiry, cold-chain and temperature rules and marks each verdict as partial.

                Model identifiers change faster than app releases, which is why this \
                field is editable.
                """)
            }

            Section("Session") {
                LabeledContent("Triaged", value: "\(store.tally.count)")
                Button("Reset the session", role: .destructive) {
                    store.reset()
                    dismiss()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .onAppear { apiKey = KeychainStore.read() ?? "" }
    }

    private func save() {
        try? KeychainStore.save(apiKey)
        UserDefaults.standard.set(model.trimmingCharacters(in: .whitespaces), forKey: "gemini.model")
        saved = true
    }
}

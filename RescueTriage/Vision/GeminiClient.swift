import Foundation

enum GeminiError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case emptyResponse
    case malformedObservation
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "No Gemini API key. Add one in Settings."
        case .http(let code, let message): "Gemini returned \(code): \(message)"
        case .emptyResponse: "Gemini returned no candidates."
        case .malformedObservation: "Gemini's answer did not match the expected shape."
        case .transport(let message): "Network error: \(message)"
        }
    }
}

/// Calls Gemini to describe a product photograph.
///
/// It is asked to *describe*, never to decide. The verdict belongs to
/// `VerdictEngine`, whose rules can overrule anything said here. `responseSchema`
/// forces structured JSON back, so a demo cannot collapse because the model felt
/// chatty that afternoon.
struct GeminiClient {

    let apiKey: String
    let model: String
    private let session: URLSession

    static let defaultModel = "gemini-2.5-flash"

    init(apiKey: String, model: String = GeminiClient.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    /// Built from the Keychain plus the model chosen in Settings.
    static func fromStoredSettings() -> GeminiClient {
        let model = UserDefaults.standard.string(forKey: "gemini.model") ?? defaultModel
        return GeminiClient(apiKey: KeychainStore.read() ?? "", model: model)
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func analyse(imageData: Data, declaration: SupplierDeclaration) async throws -> ScanObservation {
        guard isConfigured else { throw GeminiError.missingAPIKey }

        var request = URLRequest(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(imageData: imageData, declaration: declaration)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw GeminiError.http(http.statusCode, String(message))
        }

        return try Self.decodeObservation(from: data)
    }

    // MARK: Request

    private func requestBody(imageData: Data, declaration: SupplierDeclaration) -> [String: Any] {
        [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt(for: declaration)],
                    ["inline_data": ["mime_type": "image/jpeg",
                                     "data": imageData.base64EncodedString()]]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json",
                "responseSchema": Self.responseSchema
            ]
        ]
    }

    private func prompt(for declaration: SupplierDeclaration) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return """
        You are inspecting surplus food goods arriving at Rescue, an anti-waste \
        supermarket that deliberately sells produce other shops refuse for looking wrong.

        Describe ONLY what the photograph shows. Do not decide whether to accept \
        the goods — that decision is made elsewhere by food-safety rules.

        The supplier declared:
        - Product: \(declaration.productName) (\(declaration.category.label))
        - Quantity: \(declaration.formattedQuantity) \(declaration.unit)
        - Arrived at supplier: \(formatter.string(from: declaration.arrivalDate))
        - \(declaration.expiryKind.label): \(formatter.string(from: declaration.expiryDate))
        - Their stated reason for rejecting it: \(declaration.declaredReason.label)
        \(declaration.coldChainGapMinutes.map { "- Declared cold-chain gap: \($0) min" } ?? "")
        \(declaration.storageTempC.map { "- Declared storage temperature: \($0) °C" } ?? "")

        Report any contradiction between that declaration and the photograph as a \
        discrepancy. Use severity "major" when the truth is materially worse than \
        declared — for example a declared small dent that is actually a torn or \
        punctured pack. Use "minor" for differences that do not change how sellable \
        the goods are.

        damageSeverity: 0 none, 1 trivial, 2 noticeable, 3 serious, 4 severe.
        Cosmetic imperfection — odd shape, blemished skin, old packaging — is NOT \
        damage here. Report it as 0 and mention it in visualNotes.
        List spoilageSigns only for actual signs of spoiled food: mould, slime, \
        discolouration, leaking fluid. An empty list when there are none.
        """
    }

    private static let responseSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "damageSeverity": ["type": "INTEGER"],
            "packagingIntegrity": ["type": "STRING",
                                   "enum": ["intact", "dented", "compromised", "breached"]],
            "spoilageSigns": ["type": "ARRAY", "items": ["type": "STRING"]],
            "labelLegible": ["type": "BOOLEAN"],
            "observedProduct": ["type": "STRING"],
            "observedQuantityPlausible": ["type": "BOOLEAN"],
            "discrepancies": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "field": ["type": "STRING"],
                        "declared": ["type": "STRING"],
                        "observed": ["type": "STRING"],
                        "severity": ["type": "STRING", "enum": ["minor", "major"]]
                    ],
                    "required": ["field", "declared", "observed", "severity"]
                ]
            ],
            "visualNotes": ["type": "STRING"]
        ],
        "required": [
            "damageSeverity", "packagingIntegrity", "spoilageSigns", "labelLegible",
            "observedProduct", "observedQuantityPlausible", "discrepancies", "visualNotes"
        ]
    ]

    // MARK: Response

    private struct Envelope: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    static func decodeObservation(from data: Data) throws -> ScanObservation {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let text = envelope.candidates?.first?.content?.parts?
            .compactMap(\.text).first, !text.isEmpty
        else { throw GeminiError.emptyResponse }

        guard let inner = text.data(using: .utf8),
              var observation = try? JSONDecoder().decode(ScanObservation.self, from: inner)
        else { throw GeminiError.malformedObservation }

        observation.damageSeverity = min(4, max(0, observation.damageSeverity))
        return observation
    }
}

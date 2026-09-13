import XCTest
@testable import RescueTriage

final class GeminiClientTests: XCTestCase {

    /// A real-shaped Gemini response: the observation JSON arrives as a string
    /// inside candidates[0].content.parts[0].text.
    private let recordedResponse = """
    {
      "candidates": [
        { "content": { "parts": [ { "text": "{\\"damageSeverity\\":1,\\"packagingIntegrity\\":\\"dented\\",\\"spoilageSigns\\":[],\\"labelLegible\\":true,\\"observedProduct\\":\\"passata bottles\\",\\"observedQuantityPlausible\\":true,\\"discrepancies\\":[{\\"field\\":\\"packaging\\",\\"declared\\":\\"dented outer box\\",\\"observed\\":\\"one bottle cracked\\",\\"severity\\":\\"major\\"}],\\"visualNotes\\":\\"Corner crushed.\\"}" } ], "role": "model" },
          "finishReason": "STOP" }
      ]
    }
    """.data(using: .utf8)!

    func test_decodesTheObservationOutOfAGeminiEnvelope() throws {
        let observation = try GeminiClient.decodeObservation(from: recordedResponse)
        XCTAssertEqual(observation.damageSeverity, 1)
        XCTAssertEqual(observation.packagingIntegrity, .dented)
        XCTAssertEqual(observation.observedProduct, "passata bottles")
        XCTAssertEqual(observation.discrepancies.count, 1)
        XCTAssertEqual(observation.discrepancies[0].severity, .major)
    }

    func test_emptyCandidatesThrows() {
        let empty = #"{"candidates":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GeminiClient.decodeObservation(from: empty))
    }

    func test_nonJSONTextPartThrows() {
        let prose = """
        { "candidates": [ { "content": { "parts": [ { "text": "The yoghurt looks fine to me." } ] } } ] }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try GeminiClient.decodeObservation(from: prose))
    }

    func test_damageSeverityIsClampedToTheZeroToFourRange() throws {
        let outOfRange = """
        { "candidates": [ { "content": { "parts": [ { "text": "{\\"damageSeverity\\":9,\\"packagingIntegrity\\":\\"intact\\",\\"spoilageSigns\\":[],\\"labelLegible\\":true,\\"observedProduct\\":\\"x\\",\\"observedQuantityPlausible\\":true,\\"discrepancies\\":[],\\"visualNotes\\":\\"\\"}" } ] } } ] }
        """.data(using: .utf8)!
        XCTAssertEqual(try GeminiClient.decodeObservation(from: outOfRange).damageSeverity, 4)
    }

    func test_missingAPIKeyIsReportedBeforeAnyNetworkCall() async {
        let client = GeminiClient(apiKey: "", model: "gemini-2.5-flash")
        do {
            _ = try await client.analyse(imageData: Data(), declaration: Self.sampleDeclaration)
            XCTFail("should have thrown")
        } catch let error as GeminiError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    private static let sampleDeclaration = SupplierDeclaration(
        supplier: "top!", productName: "1 case passata", category: .ambient,
        quantity: 1, unit: "case", arrivalDate: Date(), expiryDate: Date(),
        expiryKind: .bestBefore, declaredReason: .dentedOuterBox,
        coldChainGapMinutes: nil, storageTempC: nil,
        retailUnitPrice: 18, estimatedWeightKg: 12
    )
}

import XCTest
@testable import RescueTriage

final class KeychainStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? KeychainStore.delete()
    }

    override func tearDown() {
        try? KeychainStore.delete()
        super.tearDown()
    }

    func test_readingWhenNothingIsStoredReturnsNil() {
        XCTAssertNil(KeychainStore.read())
    }

    func test_savedKeyComesBack() throws {
        try KeychainStore.save("AIzaTESTKEY123")
        XCTAssertEqual(KeychainStore.read(), "AIzaTESTKEY123")
    }

    func test_savingTwiceOverwrites() throws {
        try KeychainStore.save("first")
        try KeychainStore.save("second")
        XCTAssertEqual(KeychainStore.read(), "second")
    }

    func test_deleteRemovesTheKey() throws {
        try KeychainStore.save("AIzaTESTKEY123")
        try KeychainStore.delete()
        XCTAssertNil(KeychainStore.read())
    }

    func test_savingAnEmptyStringDeletesInstead() throws {
        try KeychainStore.save("AIzaTESTKEY123")
        try KeychainStore.save("   ")
        XCTAssertNil(KeychainStore.read(), "whitespace is not a key")
    }
}

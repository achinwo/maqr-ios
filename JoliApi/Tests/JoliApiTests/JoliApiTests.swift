import XCTest
@testable import JoliApi

final class JoliApiTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print("hello world")
        doTest()
        XCTAssertEqual(JoliApi().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

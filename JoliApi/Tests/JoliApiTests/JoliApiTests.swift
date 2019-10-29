import XCTest
@testable import JoliApi

@available(OSX 10.12, *)
final class JoliApiTests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let expectation = self.expectation(description: "running async test")
        
        doTest() {
            expectation.fulfill()
        }
        
        
        
        wait(for: [expectation], timeout: 2)
        
        XCTAssertEqual(JoliApi().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

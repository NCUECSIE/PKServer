import XCTest

class GridsParserTests: XCTestCase {
    func testNonConsecutiveGrids() {
        let ncGrids: NonConsecutiveGrids = "10.00-10.01:30.00-30.01,20.00-20.03:20.00-20.03"
        var count = 0
        for _ in ncGrids {
            count += 1
        }
        XCTAssertEqual(count, 10)
    }
}

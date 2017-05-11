import XCTest

class GridsParserTests: XCTestCase {
    func testNonConsecutiveGrids() {
        let ncGrids: NonConsecutiveGrids = "10.00-10.01:30.00-30.01,20.00-20.03:20.00-20.03"
        var count = 0
        
        var expectedGrids = [
            "10.00:30.00": false,
            "20.00:20.00": false,
            "20.00:20.01": false,
            "20.00:20.02": false,
            "20.01:20.00": false,
            "20.01:20.01": false,
            "20.01:20.02": false,
            "20.02:20.00": false,
            "20.02:20.01": false,
            "20.02:20.02": false,
        ]
        
        for grid in ncGrids {
            let spec = grid.description
            expectedGrids[spec] = true
            
            count += 1
        }
        
        XCTAssertEqual(count, 10)
        XCTAssert(expectedGrids.reduce(true, { $0 && $1.1 }), "Not all grids show up.")
    }
}

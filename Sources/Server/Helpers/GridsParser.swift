//
//  Gridsparser.swift
//  PKServer
//
//  Created by Peter Chen on 2017/5/9.
//
//

import Foundation
import CoreLocation

protocol Grids: Sequence {
    var consecutiveGrids: [ConsecutiveGrids] { get }
    var grids: [Grid] { get }
}

// MARK: Sequence Conformance
extension Grids {
    typealias Iterator = IndexingIterator<[Grid]>
    func makeIterator() -> IndexingIterator<[Grid]> {
        return grids.makeIterator()
    }
}

/// 用來表示多個不連續方格
struct NonConsecutiveGrids: Grids, ExpressibleByStringLiteral, CustomStringConvertible {
    // TODO: 當兩個方格有重複的部分時，必須處理掉
    /* 假設狀況如下：
     |*|*|*|*| | |
     |*|*|*|*| | |
     
     | | | | | | |
     | | | |*|*|*|
     
     則應該拆成三個部分
     
     |*|*|*| | | |
     |*|*|*| | | |
     
     | | | |*| | |
     | | | | | | |
     
     | | | | | | |
     | | | |*|*|*|
     */
    
    // MARK: Stored Properties
    let consecutiveGrids: [ConsecutiveGrids]
    
    // MARK: Computed Properties
    var grids: [Grid] {
        return consecutiveGrids.map({ $0.grids }).reduce([], { $0 + $1 })
    }
    
    // MARK: ExpressibleByStringLiteral
    typealias StringLiteralType = String
    init(stringLiteral: String) {
        let consecutives = stringLiteral.characters.split(separator: ",")
        consecutiveGrids = consecutives.map() { ConsecutiveGrids(stringLiteral: String($0)) }
    }
    
    // MARK: CustomStringConvertible
    var description: String {
        return consecutiveGrids.map { "\($0)" }.joined(separator: ",")
    }
    
    // MARK: 不會用到的 Protocol（從單一字元初始化）
    typealias UnicodeScalarLiteralType = String
    typealias ExtendedGraphemeClusterLiteralType = String
    init(extendedGraphemeClusterLiteral: String) { fatalError() }
    init(unicodeScalarLiteral: String) { fatalError() }
}

/// 用來表示連續方格
struct ConsecutiveGrids: Grids, ExpressibleByStringLiteral, CustomStringConvertible {
    // MARK: Stored Properties
    let lowerLeft: CLLocationCoordinate2D
    let upperRight: CLLocationCoordinate2D
    
    // MARK: Computed Properties
    var consecutiveGrids: [ConsecutiveGrids] {
        return [self]
    }
    var grids: [Grid] {
        var result: [Grid] = []
        
        let minLatitude: Int = Int(lowerLeft.latitude * 100.0)
        let minLongitude: Int = Int(lowerLeft.longitude * 100.0)
        let maxLatitude: Int = Int(upperRight.latitude * 100.0)
        let maxLongitude: Int = Int(upperRight.longitude * 100.0)
        
        for i in minLatitude ..< maxLatitude {
            for j in minLongitude ..< maxLongitude {
                let di = Double(i) / 100.0
                let dj = Double(j) / 100.0
                
                result.append(Grid(latitude: di, longitude: dj))
            }
        }
        
        return result
    }
    
    // MARK: ExpressibleByStringLiteral
    typealias StringLiteralType = String
    init(stringLiteral: String) {
        let latlng = stringLiteral.characters.split(separator: ":").map { String($0) }
        guard latlng.count == 2 else {
            lowerLeft = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
            upperRight = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
            return
        }
        
        let ranges = latlng.map() { range -> (from: Double, to: Double) in
            let splits = range.characters.split(separator: "-").map() { String($0) }
            guard splits.count == 2 else { return (from: 0.0, to: 0.0) }
            guard let from = Double(splits[0]),
                let to = Double(splits[1]) else { return (from: 0.0, to: 0.0) }
            return (from: from, to: to)
        }
        let lat = ranges[0]
        let lng = ranges[1]
        lowerLeft = CLLocationCoordinate2D(latitude: lat.from, longitude: lng.from)
        upperRight = CLLocationCoordinate2D(latitude: lat.to, longitude: lng.to)
    }
    
    // MARK: CustomStringConvertible
    var description: String {
        var roundedRange = (latitude: (min: "", max: ""), longitude: (min: "", max: ""))
        roundedRange.latitude = (min: String(format: "%02f", lowerLeft.latitude), max: String(format: "%02f", upperRight.latitude))
        roundedRange.longitude = (min: String(format: "%02f", lowerLeft.longitude), max: String(format: "%02f", upperRight.longitude))
        
        return "\(roundedRange.latitude.min)-\(roundedRange.latitude.max):\(roundedRange.longitude.min)-\(roundedRange.longitude.max)"
    }
    
    // MARK: Grid 所使用，建立 1x1 連續方格的方法
    fileprivate init(__coordinate: CLLocationCoordinate2D) {
        lowerLeft = __coordinate
        upperRight = CLLocationCoordinate2D(latitude: __coordinate.latitude + 0.01, longitude: __coordinate.longitude + 0.01)
    }
    
    // MARK: 不會用到的 Protocol（從單一字元初始化）
    typealias UnicodeScalarLiteralType = String
    typealias ExtendedGraphemeClusterLiteralType = String
    init(extendedGraphemeClusterLiteral: String) { fatalError() }
    init(unicodeScalarLiteral: String) { fatalError() }
}

/// 用來表示方格
struct Grid: Grids, CustomStringConvertible {
    // MARK: Stored Properties
    let location: CLLocationCoordinate2D
    
    // MARK: Computed Properties
    var consecutiveGrids: [ConsecutiveGrids] {
        return [ ConsecutiveGrids(__coordinate: location) ]
    }
    var grids: [Grid] {
        return [self]
    }
    
    init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // MARK: CustomStringConvertible
    var description: String {
        return "\(location.latitude):\(location.longitude)"
    }
}

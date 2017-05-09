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

extension Grids {
    typealias Iterator = IndexingIterator<[Grid]>
    func makeIterator() -> IndexingIterator<[Grid]> {
        return grids.makeIterator()
    }
}

struct NonConsecutiveGrids: ExpressibleByStringLiteral, Grids {
    let consecutiveGrids: [ConsecutiveGrids]
    
    var grids: [Grid] {
        return consecutiveGrids.map({ $0.grids }).reduce([], { $0 + $1 })
    }
    
    typealias StringLiteralType = String
    
    init(stringLiteral: String) {
        let consecutives = stringLiteral.characters.split(separator: ",")
        consecutiveGrids = consecutives.map() { ConsecutiveGrids(stringLiteral: String($0)) }
    }
    
    typealias UnicodeScalarLiteralType = String
    typealias ExtendedGraphemeClusterLiteralType = String
    init(extendedGraphemeClusterLiteral: String) { fatalError() }
    init(unicodeScalarLiteral: String) { fatalError() }
}

struct ConsecutiveGrids: ExpressibleByStringLiteral, Grids {
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
                
                result.append(Grid(di, dj))
            }
        }
        
        return result
    }
    
    let lowerLeft: CLLocationCoordinate2D
    let upperRight: CLLocationCoordinate2D
    
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
    
    fileprivate init(__coordinate: CLLocationCoordinate2D) {
        lowerLeft = __coordinate
        upperRight = CLLocationCoordinate2D(latitude: __coordinate.latitude + 0.01, longitude: __coordinate.longitude + 0.01)
    }
    
    typealias UnicodeScalarLiteralType = String
    typealias ExtendedGraphemeClusterLiteralType = String
    init(extendedGraphemeClusterLiteral: String) { fatalError() }
    init(unicodeScalarLiteral: String) { fatalError() }
}

struct Grid: Grids {
    var consecutiveGrids: [ConsecutiveGrids] {
        return [ ConsecutiveGrids(__coordinate: location) ]
    }
    var grids: [Grid] {
        return [ self ]
    }
    
    let location: CLLocationCoordinate2D
    
    init(_ latitude: Double, _ longitude: Double) {
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}


























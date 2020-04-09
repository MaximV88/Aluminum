//
//  Path.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation

public typealias Path = [PathComponent]

public enum PathComponent {
    case argument(String)
    case index(UInt) // TODO: convert to Int
    case range(PathRange)
}

public protocol PathRange {
    var inclusiveLowerBound: Int { get }
    var nonInclusiveUpperBound: Int { get }
    var isEmpty: Bool { get }
}

extension Range: PathRange where Bound == Int {
    public var inclusiveLowerBound: Int { lowerBound }
    public var nonInclusiveUpperBound: Int { upperBound }
}

extension ClosedRange: PathRange where Bound == Int {
    public var inclusiveLowerBound: Int { lowerBound }
    public var nonInclusiveUpperBound: Int { upperBound + 1 }
}

internal extension PathComponent {
    var index: UInt? {
        switch self {
        case .index(let i): return i
        default: return nil
        }
    }
}

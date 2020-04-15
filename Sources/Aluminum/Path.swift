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
    case index(Int)
}

internal extension PathComponent {
    var index: UInt? {
        switch self {
        case .index(let i):
            assert(i >= 0)
            return UInt(i)
        default: return nil
        }
    }
}

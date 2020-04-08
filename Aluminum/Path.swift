//
//  Path.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation

public typealias Path = [PathComponent]

public enum PathComponent: Hashable {
    case argument(String)
    case index(UInt)
    // TODO: add case range
}

internal extension PathComponent {
    var index: UInt? {
        switch self {
        case .index(let i): return i
        default: return nil
        }
    }
}

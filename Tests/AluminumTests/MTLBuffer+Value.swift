//
//  MTLBuffer+Value.swift
//  AluminumTests
//
//  Created by Maxim Vainshtein on 10/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal extension MTLBuffer {
    func value<T>() -> T {
        return contents().assumingMemoryBound(to: T.self).pointee
    }
}

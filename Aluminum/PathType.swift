//
//  PathType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum PathType {
    case argument(MTLArgument)
    case bytes(MTLStructMember)
    case buffer(MTLPointerType)
    case argumentBuffer(MTLPointerType)
    case encodableBuffer(MTLPointerType, MTLStructType)
}

//
//  DataType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum DataType: Equatable {
    case argument(MTLArgument)
    case argumentContainingArgumentBuffer(MTLArgument, MTLPointerType)
    case textureArgument(MTLArgument)
    case samplerArgument(MTLArgument)
    case encodableArgument(MTLArgument)
    case argumentBuffer(MTLPointerType)
    case structMember(MTLStructMember)
    case array(MTLArrayType)
    case buffer(MTLPointerType)
    case encodableBuffer(MTLPointerType)
    case metalArray(MTLArrayType, MTLStructMember)
    case atomicVariable(MTLStructMember)
}

// required for comparison without associated value
extension DataType {
    var isArgument: Bool {
        if case .argument = self {
            return true
        }
        return false
    }
    
    var isArgumentContainingArgumentBuffer: Bool {
        if case .argumentContainingArgumentBuffer = self {
            return true
        }
        return false
    }
    
    var isTextureArgument: Bool {
        if case .textureArgument = self {
            return true
        }
        return false
    }
    
    var isSamplerArgument: Bool {
        if case .samplerArgument = self {
            return true
        }
        return false
    }
    
    var isArgumentBuffer: Bool {
         if case .argumentBuffer = self {
             return true
         }
         return false
     }
    
    var isStructMember: Bool {
        if case .structMember = self {
            return true
        }
        return false
    }
    
    var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }
        
    var isBuffer: Bool {
        if case .buffer = self {
            return true
        }
        return false
    }

    var isEncodableBuffer: Bool {
        if case .encodableBuffer = self {
            return true
        }
        return false
    }
    
    var isMetalArray: Bool {
        if case .metalArray = self {
            return true
        }
        return false
    }
    
    var isAtomicVariable: Bool {
        if case .atomicVariable = self {
            return true
        }
        return false
    }
}

extension DataType {
    var isEncodable: Bool {
        return isEncodableBuffer
            || isArgumentBuffer
            || isArgument
            || isArgumentContainingArgumentBuffer
    }
}

extension DataType {
    var isBytes: Bool {
        let dataType: MTLDataType
        switch self {
        case .array(let a), .metalArray(let a, _): dataType = a.elementType
        case .atomicVariable(let s): dataType = s.dataType
        case .structMember(let s): dataType = s.dataType
        default: return false
        }
        
        switch dataType {
        case .pointer, .texture, .sampler, .indirectCommandBuffer: return false
        default: return true
        }
    }
    
    var isTexture: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .texture
        case .atomicVariable(let s): return s.dataType == .texture
        case .structMember(let s): return s.dataType == .texture
        default: return false
        }
    }
    
    var isSampler: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .sampler
        case .atomicVariable(let s): return s.dataType == .sampler
        case .structMember(let s): return s.dataType == .sampler
        default: return false
        }
    }

    @available(OSX 10.14, iOS 13, *)
    var isRenderPipelineState: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .renderPipeline
        case .atomicVariable(let s): return s.dataType == .renderPipeline
        case .structMember(let s): return s.dataType == .renderPipeline
        default: return false
        }
    }

    var isIndirectCommandBuffer: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .indirectCommandBuffer
        case .atomicVariable(let s): return s.dataType == .indirectCommandBuffer
        case .structMember(let s): return s.dataType == .indirectCommandBuffer
        default: return false
        }
    }
}

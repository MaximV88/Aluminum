//
//  MetalType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 17/02/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum MetalType: Hashable {
    case argument(MTLArgument)
    case array(MTLArrayType)
    case `struct`(MTLStructType)
    case pointer(MTLPointerType)
    case structMember(MTLStructMember)
}

internal extension MetalType {
    func children() -> [MetalType] {
        switch self {
        case .argument(let a): return childrenFromArgument(a)
        case .array(let a): return childrenFromArray(a)
        case .struct(let s): return childrenFromStruct(s)
        case .pointer(let p): return childrenFromPointer(p)
        case .structMember(let m): return childrenFromStructMember(m)
        }
    }
}

private extension MetalType {
    func childrenFromArgument(_ argument: MTLArgument) -> [MetalType] {
        switch argument.type {
        case .buffer: return [.pointer(argument.bufferPointerType!)]
        case .texture: fallthrough
        case .sampler: fallthrough
        case .threadgroupMemory: return []
        default: fatalError("Unsupported argument type.")
        }
    }
    
    func childrenFromPointer(_ pointer: MTLPointerType) -> [MetalType] {
        switch pointer.elementType {
        case .struct: return [.struct(pointer.elementStructType()!)]
        case .array: return [.array(pointer.elementArrayType()!)]
        default: return []
        }
    }
    
    func childrenFromArray(_ array: MTLArrayType) -> [MetalType] {
        switch array.elementType {
        case .struct: return [.struct(array.elementStructType()!)]
        case .pointer: return [.pointer(array.elementPointerType()!)]
        case .array: return [.array(array.element()!)]
        default: return []
        }
    }
    
    func childrenFromStruct(_ struct: MTLStructType) -> [MetalType] {
        return `struct`.members.map { .structMember($0) }
    }
    
    func childrenFromStructMember(_ structMember: MTLStructMember) -> [MetalType] {
        switch structMember.dataType {
        case .array: return [.array(structMember.arrayType()!)]
        case .struct: return [.struct(structMember.structType()!)]
        case .pointer: return [.pointer(structMember.pointerType()!)]
        default: return []
        }
    }
}

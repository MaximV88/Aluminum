//
//  Traverser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 17/02/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum Argument: Hashable {
    case argument(MTLArgument)
    case array(MTLArrayType)
    case `struct`(MTLStructType)
    case pointer(MTLPointerType)
    case structMember(MTLStructMember)
}

internal extension Argument {
    func children() -> [Argument] {
        switch self {
        case .argument(let a): return childrenFromArgument(a)
        case .array(let a): return childrenFromArray(a)
        case .struct(let s): return childrenFromStruct(s)
        case .pointer(let p): return childrenFromPointer(p)
        case .structMember(let m): return childrenFromStructMember(m)
        }
    }
}

private extension Argument {
    func childrenFromArgument(_ argument: MTLArgument) -> [Argument] {
        switch argument.type {
        case .buffer: return [.pointer(argument.bufferPointerType!)]
        case .texture: fallthrough
        case .sampler: fallthrough
        case .threadgroupMemory: return []
        default: fatalError("Unsupported argument type.")
        }
    }
    
    func childrenFromPointer(_ pointer: MTLPointerType) -> [Argument] {
        switch pointer.elementType {
        case .struct: return [.struct(pointer.elementStructType()!)]
        case .array: return [.array(pointer.elementArrayType()!)]
        default: return []
        }
    }
    
    func childrenFromArray(_ array: MTLArrayType) -> [Argument] {
        switch array.elementType {
        case .struct: return [.struct(array.elementStructType()!)]
        case .pointer: return [.pointer(array.elementPointerType()!)]
        case .array: return [.array(array.element()!)]
        default: return []
        }
    }
    
    func childrenFromStruct(_ struct: MTLStructType) -> [Argument] {
        return `struct`.members.map { .structMember($0) }
    }
    
    func childrenFromStructMember(_ structMember: MTLStructMember) -> [Argument] {
        switch structMember.dataType {
        case .array: return [.array(structMember.arrayType()!)]
        case .struct: return [.struct(structMember.structType()!)]
        case .pointer: return [.pointer(structMember.pointerType()!)]
        default: return []
        }
    }
}

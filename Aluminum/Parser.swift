//
//  Parser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal



internal class Parser {
    
    static let startIndexDelimiter = "["
    static let endIndexDelimiter = "]"
    static let indexDelimiter = Parser.startIndexDelimiter + Parser.endIndexDelimiter
    

    enum Argument: Hashable {
        case argument(MTLArgument)
        case type(MTLType)
        case structMember(MTLStructMember)
    }
    
    private var mapping = [String: Argument]()
    public var argumentBufferEncodedLength: Int = 0
        
    convenience init(arguments: [MTLArgument]) throws {
        self.init()
        
        try arguments.forEach {
            try parseArgument($0)
        }
    }
    
    func argument(for path: String) -> Argument? {
        return mapping[path]
    }
}

private extension Parser {
    func parseArgument(_ argument: MTLArgument) throws {
        switch argument.type {
        case .buffer: parsePointer(argument.bufferPointerType!, namespace: argument.name)
        case .texture: fallthrough
        case .sampler: fallthrough
        case .threadgroupMemory: mapping[argument.name] = .argument(argument)
        default: fatalError("Unsupported argument type.")
        }
    }
    
    func parsePointer(_ pointer: MTLPointerType, namespace: String) {
        mapping[namespace] = .type(pointer)
        
        if pointer.elementIsArgumentBuffer {
            argumentBufferEncodedLength += pointer.dataSize // TODO: include alignment
        }
        
        switch pointer.elementType {
        case .struct: parseStruct(pointer.elementStructType()!, namespace: namespace)
        case .array: parseArray(pointer.elementArrayType()!, namespace: namespace)
        default: break // already assigned
        }
    }
    
    func parseStruct(_ struct: MTLStructType, namespace: String) {
        // dont override existing namespace
        if mapping[namespace] == nil {
            mapping[namespace] = .type(`struct`)
        }
        
        for member in `struct`.members {
            let internalNamespace = namespace.appending(".\(member.name)")
            
            switch member.dataType {
            case .array: parseArray(member.arrayType()!, namespace: namespace) // ignore internal namespace '__elems' for array
            case .struct: parseStruct(member.structType()!, namespace: internalNamespace)
            case .pointer: parsePointer(member.pointerType()!, namespace: internalNamespace)
            default: mapping[internalNamespace] = .structMember(member)
            }
        }
    }
    
    func parseArray(_ array: MTLArrayType, namespace: String) {
        let arrayNamespace = namespace.appending(Parser.indexDelimiter)
        
        switch array.elementType {
        case .struct: parseStruct(array.elementStructType()!, namespace: arrayNamespace)
        case .pointer: parsePointer(array.elementPointerType()!, namespace: arrayNamespace)
        case .array: parseArray(array.element()!, namespace: arrayNamespace)
        default: mapping[arrayNamespace] = .type(array)
        }
    }
}

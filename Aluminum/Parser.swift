//
//  Parser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


// cant calculate offset unless it is related to specific index - decided not to save offset per each existing permutation
internal class Parser {
    
    private static let startIndexDelimiter = "["
    private static let endIndexDelimiter = "]"
    private static let indexDelimiter = Parser.startIndexDelimiter + Parser.endIndexDelimiter
    
    enum Argument: Hashable {
        case argument(MTLArgument)
        case type(MTLType)
        case structMember(MTLStructMember)
    }
    
    struct Item {
        let argument: Argument
        let indexPath: [Int]
    }
    
    // known regex
    private let arrayRegex = try! NSRegularExpression(pattern: "\\\(Parser.startIndexDelimiter)\\d*\\\(Parser.endIndexDelimiter)")

    private var mapping = [String: Argument]()
    public var argumentBufferEncodedLength: Int = 0
        
    init(arguments: [MTLArgument]) throws {
        try arguments.forEach {
            try parseArgument($0)
        }
    }
    
    func item(for path: String) throws -> Item {
        let normalizedPath = self.normalizedPath(for: path)
        
        guard let argument = mapping[normalizedPath] else {
            throw ComputePipelineStateError.noPathFound
        }
        
        return Item(argument: argument, indexPath: try indices(in: path))
    }
}

private extension Parser {
    func parseArgument(_ argument: MTLArgument) throws {
        switch argument.type {
        case .buffer: _ = parsePointer(argument.bufferPointerType!, namespace: argument.name)
        case .texture: fallthrough
        case .sampler: fallthrough
        case .threadgroupMemory: mapping[argument.name] = .argument(argument)
        default: fatalError("Unsupported argument type.")
        }
    }
    
    func parsePointer(_ pointer: MTLPointerType, namespace: String) {
        if pointer.elementIsArgumentBuffer {
            argumentBufferEncodedLength += pointer.dataSize // TODO: include alignment
        }
        
        switch pointer.elementType {
        case .struct: _ = parseStruct(pointer.elementStructType()!, namespace: namespace)
        case .array: _ = parseArray(pointer.elementArrayType()!, namespace: namespace)
        default: break
        }
        
        mapping[namespace] = .type(pointer)
    }
    
    func parseStruct(_ struct: MTLStructType, namespace: String) {
        for member in `struct`.members {
            let internalNamespace = namespace.appending(".\(member.name)")
            switch member.dataType {
            case .array:
                // ignore internal namespace '__elems' for array
                parseArray(member.arrayType()!, namespace: namespace)
            case .struct:
                parseStruct(member.structType()!, namespace: internalNamespace)
            case .pointer:
                parsePointer(member.pointerType()!, namespace: internalNamespace)
            default:
                mapping[internalNamespace] = .structMember(member)
            }
        }
        
        mapping[namespace] = .type(`struct`)
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

private extension Parser {
    func normalizedPath(for path: String) -> String {
        return arrayRegex.stringByReplacingMatches(in: path,
                                                   options: [],
                                                   range: NSRange(0 ..< path.count),
                                                   withTemplate: Parser.indexDelimiter)
    }
    
    func indices(in path: String) throws -> [Int] {
        let matches = arrayRegex.matches(in: path, options: [], range: NSRange(0 ..< path.count))
        return try matches.map {
            // remove brackets
            guard let range = Range<String.Index>(NSMakeRange($0.range.location + 1, $0.range.length - 2), in: path),
                let index = Int(path[range]) else {
                    throw ComputePipelineStateError.invalidIndexFormat
            }
            
            return index
        }
    }
}

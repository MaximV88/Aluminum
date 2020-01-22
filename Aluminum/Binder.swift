//
//  Binder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal



public protocol ComputePipelineStateEncodable {
    func encode(to computeCommandEncoder: MTLComputeCommandEncoder)
    func encode(to argumentEncoder: MTLArgumentEncoder)
}

public extension ComputePipelineStateController {
    class Binder {
        enum BinderError: Error {
            case noPathFound
            case invalidSyntax
        }

        internal enum Value {
            case bytes(_ bytes: Data)
            case buffer(_ buffer: MTLBuffer)
            case custom(_ encodable: ComputePipelineStateEncodable)
        }
        
        internal enum Binding {
            case arrayMember(_ value: Value, nestedIndices: [UInt])
            case value(_ value: Value)
        }
        
        
        // known regex
        private let arrayRegex = try! NSRegularExpression(pattern: "\\\(Parser.startIndexDelimiter)[0-9]*\\\(Parser.endIndexDelimiter)")
        private let parser: Parser

        private var bindings = [Parser.Argument: Binding]()
        
        internal init(parser: Parser) {
            self.parser = parser
        }
        
        open func bind(_ path: String, to buffer: MTLBuffer) throws {
            try map(path, to: .buffer(buffer))
        }
        
        open func bind(_ path: String, bytes: UnsafeRawPointer, count: Int) throws {
            try map(path, to: .bytes(Data(bytes: bytes, count: count)))
        }
        
        open func bind(_ path: String, to encodable: ComputePipelineStateEncodable) throws {
            try map(path, to: .custom(encodable))
        }
        
        private func map(_ path: String, to value: Value) throws {
            let normalizedPath = arrayRegex.stringByReplacingMatches(in: path,
                                                                     options: [],
                                                                     range: NSRange(0 ..< path.count),
                                                                     withTemplate: Parser.indexDelimiter)
            
            guard let type = parser.argument(for: normalizedPath) else {
                throw BinderError.noPathFound
            }
            
            let matches = arrayRegex.matches(in: path, options: [], range: NSRange(0 ..< path.count))
            let nestedIndices: [UInt] = try matches.reversed().map {
                // remove brackets
                guard let range = Range<String.Index>(NSMakeRange($0.range.location + 1, $0.range.length - 2), in: path),
                    let index = UInt(path[range]) else {
                    throw BinderError.invalidSyntax
                }
                
                return index
            }

            // bind at an associated dictionary by index
            if nestedIndices.isEmpty {
                bindings[type] = .value(value)
            } else {
                bindings[type] = .arrayMember(value, nestedIndices: nestedIndices)
            }
        }
    }
}

public extension ComputePipelineStateController.Binder {
    func bind<T>(_ binding: String, to parameter: T) throws {
        try withUnsafePointer(to: parameter) { ptr in
            try bind(binding, bytes: ptr, count: MemoryLayout<T>.stride)
        }
    }
}

internal extension ComputePipelineStateController.Binder {
    func binding(for argument: Parser.Argument) -> Binding? {
        return bindings[argument]
    }
}

extension ComputePipelineStateController.Binder.BinderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Path doesnt exist.", comment: "Non existing path error")
        case .invalidSyntax: return NSLocalizedString("Invalid syntax.", comment: "Invalid syntax error")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Path was not parsed from arguments.", comment: "Non existing path failure reason")
        case .invalidSyntax: return NSLocalizedString("Syntax does not match arguments.", comment: "Invalid syntax failure reason")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Make sure path is correctly typed.", comment: "Non existing path recovery suggestion")
        case .invalidSyntax: return NSLocalizedString("Check syntax.", comment: "Invalid syntax recovery suggestion")
        }
    }
}


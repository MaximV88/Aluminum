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
        }

        internal enum Binding {
            case bytes(_ bytes: Data)
            case buffer(_ binding: MTLBuffer)
            case custom(_ binding: ComputePipelineStateEncodable)
        }
        
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
        
        private func map(_ path: String, to binding: Binding) throws {
            guard let type = parser.argument(for: path) else {
                throw BinderError.noPathFound
            }
            //TODO: parse path with index
            bindings[type] = binding
        }
    }
}

public extension ComputePipelineStateController.Binder {
    func bind<T>(_ binding: String, struct: T) throws {
        try withUnsafePointer(to: `struct`) { ptr in
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
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Path was not parsed from arguments.", comment: "Non existing path failure reason")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Make sure path is correctly typed.", comment: "Non existing path recovery suggestion")
        }
    }
}

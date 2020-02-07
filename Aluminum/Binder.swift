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
        internal enum Value {
            case bytes(_ bytes: Data)
            case buffer(_ buffer: MTLBuffer, offset: Int)
            case custom(_ encodable: ComputePipelineStateEncodable)
        }
        
        struct Binding {
            let value: Value
            let indexPath: [Int]
        }
        
        
        private let parser: Parser

        private var bindings = [Parser.Argument: [Binding]]()
        
        internal init(parser: Parser) {
            self.parser = parser
        }
        
        open func bind(_ path: String, to buffer: MTLBuffer, offset: Int = 0) throws {
            try map(path, to: .buffer(buffer, offset: offset))
        }
        
        open func bind(_ path: String, bytes: UnsafeRawPointer, count: Int) throws {
            try map(path, to: .bytes(Data(bytes: bytes, count: count)))
        }
        
        open func bind(_ path: String, to encodable: ComputePipelineStateEncodable) throws {
            try map(path, to: .custom(encodable))
        }
        
        private func map(_ path: String, to value: Value) throws {
            let item = try parser.item(for: path)
                                    
            if bindings[item.argument] != nil {
                bindings[item.argument]!.append(Binding(value: value, indexPath: item.indexPath))
            } else {
                bindings[item.argument] = [Binding(value: value, indexPath: item.indexPath)]
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
    func bindings(for argument: Parser.Argument) -> [Binding] {
        return bindings[argument] ?? []
    }
}

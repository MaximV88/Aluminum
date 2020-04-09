//
//  ArgumentRootEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class ArgumentRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument

    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    private weak var argumentBuffer: MTLBuffer!
    
    init(encoding: Parser.Encoding,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case let .argument(argument) = encoding.dataType else {
            fatalError("ArgumentRootEncoder expects an argument path that starts with an argument.")
        }

        self.encoding = encoding
        self.argument = argument
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension ArgumentRootEncoder: RootEncoder {
    func encode(_ buffer: MTLBuffer, offset: Int) {
        computeCommandEncoder.setBuffer(buffer, offset: offset, index: argument.index)
    }

    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        computeCommandEncoder.setBytes(bytes, length: count, index: argument.index)
    }
    
    func encode(_ sampler: MTLSamplerState, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isSamplerArgument, .invalidSamplerPath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        computeCommandEncoder.setSamplerStates([sampler], range: index ..< index + 1)
    }

    func encode(_ samplers: [MTLSamplerState], to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isSamplerArgument, .invalidSamplerPath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        computeCommandEncoder.setSamplerStates(samplers, range: index ..< index + samplers.count)
    }

}

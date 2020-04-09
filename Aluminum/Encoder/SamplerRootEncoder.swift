//
//  SamplerRootEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class SamplerRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    
    init(encoding: Parser.Encoding,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case let .samplerArgument(argument) = encoding.dataType else {
            fatalError("SamplerRootEncoder expects an argument path that starts with an argument texture.")
        }
        
        self.encoding = encoding
        self.argument = argument
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension SamplerRootEncoder: RootEncoder {
    func encode(_ sampler: MTLSamplerState) {
        assert(argument.arrayLength == 1, .requiresArrayReference)
        computeCommandEncoder.setSamplerState(sampler, index: argument.index)
    }

    func encode(_ samplers: [MTLSamplerState]) {
        assert(argument.arrayLength >= samplers.count, .arrayOutOfBounds(argument.arrayLength))
        
        let index = argument.index
        computeCommandEncoder.setSamplerStates(samplers, range: index ..< index + samplers.count)
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


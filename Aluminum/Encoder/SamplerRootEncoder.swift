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
    private let metalEncoder: MetalEncoder
    
    init(encoding: Parser.Encoding,
         metalEncoder: MetalEncoder)
    {
        guard case let .samplerArgument(argument) = encoding.dataType else {
            fatalError("SamplerRootEncoder expects an argument path that starts with an argument texture.")
        }
        
        self.encoding = encoding
        self.argument = argument
        self.metalEncoder = metalEncoder
    }
}

extension SamplerRootEncoder: RootEncoder {
    func encode(_ sampler: MTLSamplerState) {
        assert(argument.arrayLength == 1, .requiresArrayReference)
        metalEncoder.encode(sampler, to: argument.index)
    }
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float) {
        assert(argument.arrayLength == 1, .requiresArrayReference)
        metalEncoder.encode(sampler,
                            lodMinClamp: lodMinClamp,
                            lodMaxClamp: lodMaxClamp,
                            to: argument.index)
    }

    func encode(_ samplers: [MTLSamplerState]) {
        assert(argument.arrayLength >= samplers.count, .arrayOutOfBounds(argument.arrayLength))
        
        let index = argument.index
        metalEncoder.encode(samplers, to: index ..< index + samplers.count)
    }
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float]) {
        assert(argument.arrayLength >= samplers.count, .arrayOutOfBounds(argument.arrayLength))
        
        let index = argument.index
        metalEncoder.encode(samplers,
                            lodMinClamps: lodMinClamps,
                            lodMaxClamps: lodMaxClamps,
                            to: index ..< index + samplers.count)
    }
    
    func encode(_ sampler: MTLSamplerState, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isSamplerArgument, .invalidSamplerPath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        metalEncoder.encode([sampler], to: index ..< index + 1)
    }

    func encode(_ samplers: [MTLSamplerState], to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isSamplerArgument, .invalidSamplerPath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        metalEncoder.encode(samplers, to: index ..< index + samplers.count)
    }
}


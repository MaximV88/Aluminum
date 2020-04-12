//
//  EncoderGroupFactory.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 12/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal struct EncoderGroupFactory {
    private let argumentNameIndices: [String: Int]

    private let bufferCount: Int
    private let samplerCount: Int
    private let textureCount: Int

    init(arguments: [MTLArgument]) {
        var bufferCount = 0
        var samplerCount = 0
        var textureCount = 0
        var argumentNameIndices = [String: Int]()

        arguments.forEach {
            switch $0.type {
            case .buffer: bufferCount += $0.arrayLength // always 1 per argument
            case .sampler: samplerCount += $0.arrayLength
            case .texture: textureCount += $0.arrayLength
            default: break
            }
            
            argumentNameIndices[$0.name] = $0.index
        }
        
        self.bufferCount = bufferCount
        self.samplerCount = samplerCount
        self.textureCount = textureCount
        
        self.argumentNameIndices = argumentNameIndices
    }
    
    func makeEncoderGroup(function: MTLFunction, parser: Parser) -> EncoderGroup {
        return EncoderGroup(function: function,
                            parser: parser,
                            bufferCount: bufferCount,
                            samplerCount: samplerCount,
                            textureCount: textureCount,
                            argumentNameIndices: argumentNameIndices)
    }
}

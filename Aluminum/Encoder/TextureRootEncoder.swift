//
//  TextureRootEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class TextureRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    
    init(encoding: Parser.Encoding,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case let .textureArgument(argument) = encoding.dataType else {
            fatalError("TextureRootEncoder expects an argument path that starts with an argument texture.")
        }
        
        self.encoding = encoding
        self.argument = argument
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension TextureRootEncoder: RootEncoder {
    func encode(_ texture: MTLTexture) {
        assert(argument.arrayLength == 1, .requiresArrayReference)
        computeCommandEncoder.setTexture(texture, index: argument.index)
    }
    
    func encode(_ textures: [MTLTexture]) {
        assert(argument.arrayLength >= textures.count, .arrayOutOfBounds(argument.arrayLength))
        
        let index = argument.index
        computeCommandEncoder.setTextures(textures, range: index ..< index + textures.count)
    }
    
    func encode(_ texture: MTLTexture, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isTextureArgument, .invalidTexturePath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        computeCommandEncoder.setTextures([texture], range: index ..< index + 1)
    }
    
    func encode(_ textures: [MTLTexture], to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isTextureArgument, .invalidTexturePath(dataTypePath.last!))

        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        computeCommandEncoder.setTextures(textures, range: index ..< index + textures.count)
    }
}

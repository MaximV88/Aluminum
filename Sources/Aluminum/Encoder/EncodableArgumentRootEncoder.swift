//
//  EncodableArgumentRootEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class EncodableArgumentRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument

    private let metalEncoder: MetalEncoder
    private weak var argumentBuffer: MTLBuffer!
    
    private var bufferOffset: Int = 0
    private var didCopyBytes = false

    init(encoding: Parser.Encoding,
         metalEncoder: MetalEncoder)
    {
        guard case let .encodableArgument(argument) = encoding.dataType else {
            fatalError("EncodableArgumentRootEncoder expects an argument path that starts with an argument.")
        }

        self.encoding = encoding
        self.argument = argument
        self.metalEncoder = metalEncoder
    }
}

extension EncodableArgumentRootEncoder: RootEncoder {
    var encodedLength: Int {
        return argument.bufferDataSize
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        precondition(argumentBuffer.length - offset >= encodedLength, .invalidArgumentBuffer)
        
        self.argumentBuffer = argumentBuffer
        self.bufferOffset = offset
        
        metalEncoder.encode(argumentBuffer, offset: offset, to: argument.index)
    }

    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        if let argumentBuffer = argumentBuffer {
            let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
            let source = bytes.assumingMemoryBound(to: UInt8.self)

            for i in 0 ..< count {
                destination[bufferOffset + i] = source[i]
            }
        } else {
            metalEncoder.encode(bytes, count: count, to: argument.index)
            didCopyBytes = true
        }
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        precondition(!didCopyBytes, .overridesSingleUseData)
        precondition(argumentBuffer != nil, .noArgumentBuffer)
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        precondition(dataTypePath.last!.isBytes, .invalidBytesPath(dataTypePath.last!))

        let pathOffset = queryOffset(for: path, dataTypePath: dataTypePath[1...])
        let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[bufferOffset + pathOffset + i] = source[i]
        }
    }
}

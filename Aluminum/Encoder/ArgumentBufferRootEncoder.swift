//
//  ArgumentBufferRootEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class ArgumentBufferRootEncoder {
    private let encoding: Parser.Encoding
    private let encoderIndex: Int
    
    private let pointer: MTLPointerType
    private let argumentEncoder: MTLArgumentEncoder
    private let parentArgumentEncoder: MTLArgumentEncoder?
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!

    private var hasArgumentBuffer: Bool = false

    init(encoding: Parser.Encoding,
         encoderIndex: Int,
         argumentEncoder: MTLArgumentEncoder,
         parentArgumentEncoder: MTLArgumentEncoder?,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        let pointer: MTLPointerType
        switch encoding.dataType {
        case let .argumentBuffer(p): pointer = p
        case let .argumentContainingArgumentBuffer(_, p): pointer = p
        default: fatalError("Invalid instantiation of encoder per encoding path type.")
        }
        
        self.encoding = encoding
        self.encoderIndex = encoderIndex
        self.pointer = pointer
        self.argumentEncoder = argumentEncoder
        self.parentArgumentEncoder = parentArgumentEncoder
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension ArgumentBufferRootEncoder: RootEncoder {
    var encodedLength: Int {
        return argumentEncoder.encodedLength
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        assert(argumentBuffer.length - offset >= encodedLength, .invalidArgumentBuffer)

        hasArgumentBuffer = true
        argumentEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
        
        if let parentArgumentEncoder = parentArgumentEncoder {
            parentArgumentEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
            computeCommandEncoder.useResource(argumentBuffer, usage: pointer.access.usage)
        } else {
            computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int) {
        fatalError(.requiresPathReference)
    }

    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        fatalError(.noArgumentBufferSupportForSingleUseData)
    }
    
    func encode(_ texture: MTLTexture) {
        fatalError(.requiresPathReference)
    }
    
    func encode(_ texture: MTLTexture, to path: Path) {
        validateArgumentBuffer()
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isTexture, .invalidTexturePath(dataTypePath.last!))

        let index = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        argumentEncoder.setTexture(texture, index: index)
    }
    
    func encode(_ textures: [MTLTexture], to path: Path) {
        validateArgumentBuffer()
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isTexture, .invalidTexturePath(dataTypePath.last!))

        let index = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        argumentEncoder.setTextures(textures, range: index ..< index + textures.count)

    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        validateArgumentBuffer()
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isBytes, .invalidBytesPath(dataTypePath.last!))
        
        let bytesIndex = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        let destination = argumentEncoder.constantData(at: bytesIndex).assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[i] = source[i]
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        validateArgumentBuffer()

        let dataTypePath = encoding.localDataTypePath(for: path)
        
        switch dataTypePath.last! {
        case let .buffer(p): fallthrough
        case let .encodableBuffer(p):

            let pointerIndex = queryIndex(for: path, dataTypePath: dataTypePath[1...])
            argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
            computeCommandEncoder.useResource(buffer, usage: p.access.usage)

        default: fatalError(.invalidBufferPath(dataTypePath.last!))
        }
    }
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to path: Path) {
        validateArgumentBuffer()

        let dataTypePath = encoding.localDataTypePath(for: path)
        
        switch dataTypePath.last! {
        case let .buffer(p): fallthrough
        case let .encodableBuffer(p):

            let pointerIndex = queryIndex(for: path, dataTypePath: dataTypePath[1...])
            argumentEncoder.setBuffers(buffers, offsets: offsets, range: pointerIndex ..< pointerIndex + buffers.count)
            computeCommandEncoder.useResources(buffers, usage: p.access.usage)

        default: fatalError(.invalidBufferPath(dataTypePath.last!))
        }
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        
        guard case let .encodableBuffer(p) = childEncoding.dataType else {
            fatalError(.invalidEncodableBufferPath(childEncoding.dataType))
        }
        
        assert(buffer.length - offset >= p.dataSize, .invalidBuffer)

        let pointerIndex = queryIndex(for: path, dataTypePath: encoding.localDataTypePath(to: childEncoding)[1...])
        argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
        computeCommandEncoder.useResource(buffer, usage: p.access.usage)
        
        encoderClosure(EncodableBufferEncoder(encoding: childEncoding,
                                              encodableBuffer: buffer,
                                              offset: offset))
    }
    
    func encode(_ sampler: MTLSamplerState, to path: Path) {
        validateArgumentBuffer()

        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isSampler, .invalidSamplerPath(dataTypePath.last!))

        let index = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        argumentEncoder.setSamplerState(sampler, index: index)
    }

    func encode(_ samplers: [MTLSamplerState], to path: Path) {
        validateArgumentBuffer()

        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isSampler, .invalidSamplerPath(dataTypePath.last!))

        let index = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        argumentEncoder.setSamplerStates(samplers, range: index ..< index + samplers.count)
    }
    
    func childEncoder(for path: Path) -> ArgumentBufferEncoder {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, dataTypePath: encoding.localDataTypePath(to: childEncoding)[1...])
        
        return ArgumentBufferRootEncoder(encoding: childEncoding,
                                         encoderIndex: index,
                                         argumentEncoder: argumentEncoder.makeArgumentEncoderForBuffer(atIndex: index)!,
                                         parentArgumentEncoder: argumentEncoder,
                                         computeCommandEncoder: computeCommandEncoder)
    }
}

private extension ArgumentBufferRootEncoder {
    func validateArgumentBuffer() {
        assert(hasArgumentBuffer, .noArgumentBuffer)
    }
}

private extension MTLArgumentAccess {
    var usage: MTLResourceUsage {
        switch self {
        case .readOnly: return .read
        case .writeOnly: return .write
        case .readWrite: return [.read, .write]
        default: fatalError("Unknown usage.")
        }
    }
}

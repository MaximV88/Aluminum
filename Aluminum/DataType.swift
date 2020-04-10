//
//  DataType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum DataType: Equatable {
    case argument(MTLArgument)
    case argumentContainingArgumentBuffer(MTLArgument, MTLPointerType)
    case textureArgument(MTLArgument)
    case samplerArgument(MTLArgument)
    case encodableArgument(MTLArgument)
    case argumentBuffer(MTLPointerType)
    case structMember(MTLStructMember)
    case array(MTLArrayType)
    case buffer(MTLPointerType)
    case encodableBuffer(MTLPointerType)
    case metalArray(MTLArrayType, MTLStructMember)
    case atomicVariable(MTLStructMember)
}

private protocol DataTypeContext {
    var currentMetalType: MetalType { get }
    var pendingMetalType: MetalType? { get }
    var lastDataType: DataType? { get }
    
    @discardableResult
    func nextMetalType() -> MetalType?
}

// MARK: - DataTypeRecognizer

private protocol DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType?
}


private struct ArgumentRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case .buffer = a.type,
            case let .pointer(p) = context.nextMetalType(),
            !p.elementIsArgumentBuffer,
            p.elementType != .struct
            else
        {
            return nil
        }
        
        return .argument(a)
    }
}

private struct EncodableArgumentRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case .buffer = a.type,
            case let .pointer(p) = context.nextMetalType(),
            !p.elementIsArgumentBuffer,
            case .struct = context.pendingMetalType
            else
        {
            return nil
        }
        
        return .encodableArgument(a)
    }
}

private struct ArgumentContainingArgumentBufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case .buffer = a.type,
            case let .pointer(p) = context.nextMetalType(),
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentContainingArgumentBuffer(a, p)
    }
}

private struct TextureArgumentRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case .texture = a.type
            else
        {
            return nil
        }
        
        return .textureArgument(a)
    }
}

private struct SamplerArgumentRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case .sampler = a.type
            else
        {
            return nil
        }
        
        return .samplerArgument(a)
    }
}

private struct ArgumentBufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .pointer(p) = context.currentMetalType,
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentBuffer(p)
    }
}

private struct StructMemberRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType()
            else
        {
            return nil
        }

        return .structMember(s)
    }
}

private struct ArrayRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard case .array(let a) = context.currentMetalType else {
            return nil
        }
                
        return .array(a)
    }
}

private struct BufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .pointer(p) = context.currentMetalType,
            !p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .buffer(p)
    }
}

private struct EncodableBufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard case let .pointer(p) = context.currentMetalType,
            !p.elementIsArgumentBuffer,
            case .struct = context.pendingMetalType
            else
        {
            return nil
        }
        
        return .encodableBuffer(p)
    }
}


private struct MetalArrayRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            s.dataType == .array,
            s.name == "__elems",
            case .array(let a) = context.nextMetalType()
            else
        {
            return nil
        }
                
        return .metalArray(a, s)
    }
}

private struct AtomicVariableRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            s.name == "__s"
            else
        {
            return nil
        }
        
        return .atomicVariable(s)
    }
}

private class IteratorDataTypeContext<MetalTypeArray: RandomAccessCollection>
where MetalTypeArray.Element == MetalType, MetalTypeArray.Index == Int {
    fileprivate var index: Int
    fileprivate var lastDataType: DataType?
    fileprivate var temporaryIndex = 0
    private let metalTypePath: MetalTypeArray
        
    var isFinished: Bool {
        index >= metalTypePath.endIndex
    }
    
    init(metalTypePath: MetalTypeArray) {
        self.metalTypePath = metalTypePath
        self.index = metalTypePath.startIndex
    }
    
    func saveState() {
        temporaryIndex = index
    }
    
    func loadState() {
        index = temporaryIndex
    }
    
    func advance() {
        index += 1
    }
}

extension IteratorDataTypeContext: DataTypeContext {
    var currentMetalType: MetalType {
        metalTypePath[index]
    }
    
    var pendingMetalType: MetalType? {
        guard index < metalTypePath.endIndex - 1 else {
            return nil
        }

        return metalTypePath[index + 1]
    }
    
    func nextMetalType() -> MetalType? {
        guard index < metalTypePath.endIndex - 1 else {
            return nil
        }
        
        index += 1
        return metalTypePath[index]
    }
}

internal struct DataTypeIterator<MetalTypeArray: RandomAccessCollection>: IteratorProtocol
where MetalTypeArray.Element == MetalType, MetalTypeArray.Index == Int {
    typealias Element = DataType
    
    private let context: IteratorDataTypeContext<MetalTypeArray>
    
    private let recognizers: [DataTypeRecognizer] = [
        MetalArrayRecognizer(),
        AtomicVariableRecognizer(),
        ArgumentContainingArgumentBufferRecognizer(),
        EncodableArgumentRecognizer(),
        ArgumentRecognizer(),
        TextureArgumentRecognizer(),
        SamplerArgumentRecognizer(),
        StructMemberRecognizer(),
        EncodableBufferRecognizer(),
        BufferRecognizer(),
        ArrayRecognizer(),
        ArgumentBufferRecognizer()
    ]
    
    var isFinished: Bool {
        return context.isFinished
    }
        
    init(metalTypePath: MetalTypeArray) {
        self.context = IteratorDataTypeContext(metalTypePath: metalTypePath)
    }
    
    mutating func next() -> Self.Element? {
        while !context.isFinished {
            context.saveState()
            var current: DataType!

            for r in recognizers {
                if let dataType = r.recognize(context) {
                    context.lastDataType = dataType
                    current = dataType
                    break
                } else {
                    context.loadState()
                }
            }

            assert(current != nil, "Missing DataTypeRecognizer, unable to handle given MetalType path segment.")
            context.advance()
            
            return current
        }
        
        return nil
    }
}

// required for comparison without associated value
internal extension DataType {
    var isArgument: Bool {
        if case .argument = self {
            return true
        }
        return false
    }
    
    var isArgumentContainingArgumentBuffer: Bool {
        if case .argumentContainingArgumentBuffer = self {
            return true
        }
        return false
    }
    
    var isTextureArgument: Bool {
        if case .textureArgument = self {
            return true
        }
        return false
    }
    
    var isSamplerArgument: Bool {
        if case .samplerArgument = self {
            return true
        }
        return false
    }
    
    var isArgumentBuffer: Bool {
         if case .argumentBuffer = self {
             return true
         }
         return false
     }
    
    var isStructMember: Bool {
        if case .structMember = self {
            return true
        }
        return false
    }
    
    var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }
        
    var isBuffer: Bool {
        if case .buffer = self {
            return true
        }
        return false
    }

    var isEncodableBuffer: Bool {
        if case .encodableBuffer = self {
            return true
        }
        return false
    }
    
    var isMetalArray: Bool {
        if case .metalArray = self {
            return true
        }
        return false
    }
    
    var isAtomicVariable: Bool {
        if case .atomicVariable = self {
            return true
        }
        return false
    }
}

extension DataType {
    var isBytes: Bool {
        let dataType: MTLDataType
        switch self {
        case .array(let a), .metalArray(let a, _): dataType = a.elementType
        case .atomicVariable(let s): dataType = s.dataType
        case .structMember(let s): dataType = s.dataType
        default: return false
        }
        
        switch dataType {
        case .pointer, .texture, .sampler, .indirectCommandBuffer: return false
        default: return true
        }
    }
    
    var isTexture: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .texture
        case .atomicVariable(let s): return s.dataType == .texture
        case .structMember(let s): return s.dataType == .texture
        default: return false
        }
    }
    
    var isSampler: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .sampler
        case .atomicVariable(let s): return s.dataType == .sampler
        case .structMember(let s): return s.dataType == .sampler
        default: return false
        }
    }

    var isRenderPipelineState: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .renderPipeline
        case .atomicVariable(let s): return s.dataType == .renderPipeline
        case .structMember(let s): return s.dataType == .renderPipeline
        default: return false
        }
    }

    var isIndirectCommandBuffer: Bool {
        switch self {
        case .array(let a), .metalArray(let a, _): return a.elementType == .indirectCommandBuffer
        case .atomicVariable(let s): return s.dataType == .indirectCommandBuffer
        case .structMember(let s): return s.dataType == .indirectCommandBuffer
        default: return false
        }
    }
}

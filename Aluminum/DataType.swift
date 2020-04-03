//
//  DataType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum DataType: Equatable {
    internal enum BytesType: Equatable {
        case regular
        case atomic
        case array(MTLArrayType)
        case metalArray(MTLArrayType)
    }
    
    case argument(MTLArgument)
    case bytes(BytesType, MTLStructMember)
    case bytesContainer(MTLStructMember)
    case buffer(MTLPointerType, MTLStructMember)
    case argumentBuffer(MTLPointerType, MTLStructMember)
    case encodableBuffer(MTLPointerType, MTLStructType, MTLStructMember)
    case argumentContainingArgumentBuffer(MTLArgument, MTLPointerType)
}

// required for comparison without associated value
internal extension DataType {
    var isArgument: Bool {
        if case .argument = self {
            return true
        }
        return false
    }
    
    var isBytes: Bool {
        if case .bytes = self {
            return true
        }
        return false
    }
    
    var isBytesContainer: Bool {
        if case .bytesContainer = self {
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

    var isArgumentBuffer: Bool {
        if case .argumentBuffer = self {
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
    
    var isArgumentContainingArgumentBuffer: Bool {
        if case .argumentContainingArgumentBuffer = self {
            return true
        }
        return false
    }
}


private protocol DataTypeContext {
    var currentMetalType: MetalType { get }
    var pendingMetalType: MetalType? { get }
    var lastDataType: DataType? { get }
    
    @discardableResult
    func nextMetalType() -> MetalType?
}

private protocol DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType?
}

private struct ArrayBytesRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            s.dataType == .array,
            case .array(let a) = context.nextMetalType()
            else
        {
            return nil
        }
                
        return .bytes(s.name == "__elems" ? .metalArray(a) : .array(a), s)
    }
}

private struct AtomicVariableBytesRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            s.name == "__s"
            else
        {
            return nil
        }
        
        return .bytes(.atomic, s)
    }
}

private struct ArgumentRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case let .pointer(p) = context.nextMetalType(),
            !p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argument(a)
    }
}

private struct BytesContainerRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            case .struct = context.pendingMetalType
            else
        {
            return nil
        }
        
        return .bytesContainer(s)
    }
}

private struct BytesRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(.regular, s)
    }
}

private struct EncodableBytesRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        
        // encodable bytes are in encodableBuffer
        guard
            case .encodableBuffer = context.lastDataType,
            case let .structMember(s) = context.currentMetalType,
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(.regular, s)
    }
}

private struct EncodableBufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            case let .pointer(p) = context.nextMetalType(),
            !p.elementIsArgumentBuffer,
            case let .struct(st) = context.pendingMetalType
            else
        {
            return nil
        }
        
        return .encodableBuffer(p, st, s)
    }
}

private struct BufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            case let .pointer(p) = context.nextMetalType(),
            !p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .buffer(p, s)
    }
}

private struct ArgumentBufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case .struct = context.currentMetalType,
            case let .structMember(s) = context.nextMetalType(),
            case let .pointer(p) = context.nextMetalType(),
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentBuffer(p, s)
    }
}

private struct ArgumentContainingArgumentBufferRecognizer: DataTypeRecognizer {
    func recognize(_ context: DataTypeContext) -> DataType? {
        guard
            case let .argument(a) = context.currentMetalType,
            case let .pointer(p) = context.nextMetalType(),
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentContainingArgumentBuffer(a, p)
    }
}

private class IteratorDataTypeContext<MetalTypeArray: RandomAccessCollection>
where MetalTypeArray.Element == MetalType, MetalTypeArray.Index == Int {
    fileprivate var index: Int
    fileprivate var lastDataType: DataType?
    fileprivate var temporaryIndex = 0
    private let metalTypePath: MetalTypeArray
        
    var isFinished: Bool {
        index >= metalTypePath.endIndex - 1
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
        ArrayBytesRecognizer(),
        AtomicVariableBytesRecognizer(),
        ArgumentContainingArgumentBufferRecognizer(),
        ArgumentRecognizer(),
        BytesContainerRecognizer(),
        BytesRecognizer(),
        EncodableBytesRecognizer(),
        EncodableBufferRecognizer(),
        BufferRecognizer(),
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

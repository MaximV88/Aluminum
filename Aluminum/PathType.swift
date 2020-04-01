//
//  PathType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal enum BytesType {
    case regular
    case atomic
    case metalArray
}

internal enum PathType {
    case argument(MTLArgument)
    case bytes(BytesType, MTLStructMember)
    case buffer(MTLPointerType, MTLStructMember)
    case argumentBuffer(MTLPointerType, MTLStructMember)
    case encodableBuffer(MTLPointerType, MTLStructType, MTLStructMember)
    case argumentContainingArgumentBuffer(MTLArgument, MTLPointerType)
}

// required for comparison without associated value
internal extension PathType {
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


private protocol PathTypeContext {
    var currentArgument: Argument { get }
    var lastPathType: PathType? { get }
    
    @discardableResult
    func nextArgument() -> Argument?
}

private protocol PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType?
}

private struct BytesFromMetalArrayRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case .struct = context.currentArgument,
            case let .structMember(s) = context.nextArgument(),
            s.dataType == .array
            else
        {
            return nil
        }
        
        // skip array
        guard case .array = context.nextArgument() else {
            return nil
        }
        
        return .bytes(.metalArray, s)
    }
}

private struct BytesFromAtomicVariableRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case let .pointer(p) = context.currentArgument, // TODO: check if applicable because in root
            !p.elementIsArgumentBuffer,
            case .struct = context.nextArgument(),
            case let .structMember(s) = context.nextArgument(),
            s.name == "__s"
            else
        {
            return nil
        }
        
        return .bytes(.atomic, s)
    }
}

private struct ArgumentRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard case let .argument(a) = context.currentArgument else {
            return nil
        }
        
        return .argument(a)
    }
}

private struct BytesRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case .struct = context.currentArgument,
            case let .structMember(s) = context.nextArgument(),
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(.regular, s)
    }
}

private struct EncodableBytesRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        
        // encodable bytes are in encodableBuffer
        guard
            case .encodableBuffer = context.lastPathType,
            case let .structMember(s) = context.currentArgument,
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(.regular, s)
    }
}

private struct EncodableBufferRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case .struct = context.currentArgument,
            case let .structMember(s) = context.nextArgument(),
            case let .pointer(p) = context.nextArgument(),
            !p.elementIsArgumentBuffer,
            case let .struct(st) = context.nextArgument()
            else
        {
            return nil
        }
        
        return .encodableBuffer(p, st, s)
    }
}

private struct BufferRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case .struct = context.currentArgument,
            case let .structMember(s) = context.nextArgument(),
            case let .pointer(p) = context.nextArgument(),
            !p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .buffer(p, s)
    }
}

private struct ArgumentBufferRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case .struct = context.currentArgument,
            case let .structMember(s) = context.nextArgument(),
            case let .pointer(p) = context.nextArgument(),
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentBuffer(p, s)
    }
}

private struct ArgumentContainingArgumentBufferRecognizer: PathTypeRecognizer {
    func recognize(_ context: PathTypeContext) -> PathType? {
        guard
            case let .argument(a) = context.currentArgument,
            case let .pointer(p) = context.nextArgument(),
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentContainingArgumentBuffer(a, p)
    }

}

private class IteratorPathTypeContext<ArgumentArray: RandomAccessCollection>
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int {
    fileprivate var index: Int
    fileprivate var lastPathType: PathType?
    fileprivate var temporaryIndex = 0
    private let argumentPath: ArgumentArray
        
    var isFinished: Bool {
        index >= argumentPath.endIndex - 1
    }
    
    init(argumentPath: ArgumentArray) {
        self.argumentPath = argumentPath
        self.index = argumentPath.startIndex
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

extension IteratorPathTypeContext: PathTypeContext {
    var currentArgument: Argument {
        argumentPath[index]
    }
    
    func nextArgument() -> Argument? {
        guard index < argumentPath.endIndex - 1 else {
            return nil
        }
        
        index += 1
        return argumentPath[index]
    }
}

internal struct PathTypeIterator<ArgumentArray: RandomAccessCollection>: IteratorProtocol
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int {
    typealias Element = PathType
    
    private let context: IteratorPathTypeContext<ArgumentArray>
    
    private let recognizers: [PathTypeRecognizer] = [
        BytesFromMetalArrayRecognizer(),
        BytesFromAtomicVariableRecognizer(),
        ArgumentContainingArgumentBufferRecognizer(),
        ArgumentRecognizer(),
        BytesRecognizer(),
        EncodableBytesRecognizer(),
        EncodableBufferRecognizer(),
        BufferRecognizer(),
        ArgumentBufferRecognizer()
    ]
    
    var isFinished: Bool {
        return context.isFinished
    }
    
    var lastArgumentIndex: Int {
        return context.temporaryIndex
    }
    
    var argumentIndex: Int {
        return context.index
    }
    
    init(argumentPath: ArgumentArray) {
        self.context = IteratorPathTypeContext(argumentPath: argumentPath)
    }
    
    mutating func next() -> Self.Element? {
        while !context.isFinished {
            context.saveState()
            var current: PathType!

            for r in recognizers {
                if let pathType = r.recognize(context) {
                    context.lastPathType = pathType
                    current = pathType
                    break
                } else {
                    context.loadState()
                }
            }

            assert(current != nil, "Missing PathRule, unable to handle given argument path segment.")
            context.advance()
            
            return current
        }
        
        return nil
    }
}

internal func lastPathType<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray
) -> PathType
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    assert(!argumentPath.isEmpty)

    var iterator = PathTypeIterator(argumentPath: argumentPath)
    var result = iterator.next()
    
    // get to last item
    while !iterator.isFinished {
        result = iterator.next()!
    }
        
    return result!
}

internal func firstPathType<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray
) -> PathType
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    assert(!argumentPath.isEmpty)

    var iterator = PathTypeIterator(argumentPath: argumentPath)
    return iterator.next()!
}

internal func pathTypes<ArgumentArray: RandomAccessCollection>(
    from argumentPath: ArgumentArray
) -> [PathType]
    where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    guard !argumentPath.isEmpty else {
        return []
    }
    
    var iterator = PathTypeIterator(argumentPath: argumentPath)
    var path = [PathType]()
    
    // get to last item
    while !iterator.isFinished {
        if let value = iterator.next() {
            path.append(value)
        }
     }
      
    return path
}

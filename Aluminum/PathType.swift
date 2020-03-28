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
    case bytes(MTLStructMember, BytesType)
    case buffer(MTLPointerType, MTLStructMember)
    case argumentBuffer(MTLPointerType)
    case encodableBuffer(MTLPointerType, MTLStructType)
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


private protocol PathInteractor {
    var currentArgument: Argument { get }
    var lastPathType: PathType? { get }
    
    @discardableResult
    func nextArgument() -> Argument?
}

private protocol PathRule {
    func apply(_ interactor: PathInteractor) -> PathType?
}

private struct BytesFromMetalArrayPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case .struct = interactor.currentArgument,
            case let .structMember(s) = interactor.nextArgument(),
            s.dataType == .array
            else
        {
            return nil
        }
        
        // skip array
        guard case .array = interactor.nextArgument() else {
            return nil
        }
        
        return .bytes(s, .metalArray)
    }
}

private struct BytesFromAtomicVariablePathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case let .pointer(p) = interactor.currentArgument, // TODO: check if applicable because in root
            !p.elementIsArgumentBuffer,
            case .struct = interactor.nextArgument(),
            case let .structMember(s) = interactor.nextArgument(),
            s.name == "__s"
            else
        {
            return nil
        }
        
        return .bytes(s, .atomic)
    }
}

private struct ArgumentPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard case let .argument(a) = interactor.currentArgument else {
            return nil
        }
        
        return .argument(a)
    }
}

private struct BytesPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case .struct = interactor.currentArgument,
            case let .structMember(s) = interactor.nextArgument(),
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(s, .regular)
    }
}

private struct EncodableBytesPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        
        // encodable bytes are in encodableBuffer
        guard
            case .encodableBuffer = interactor.lastPathType,
            case let .structMember(s) = interactor.currentArgument,
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(s, .regular)
    }
}

private struct EncodableBufferPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case let .pointer(p) = interactor.currentArgument,
            !p.elementIsArgumentBuffer,
            case let .struct(s) = interactor.nextArgument()
            else
        {
            return nil
        }
        
        return .encodableBuffer(p, s)
    }
}

private struct BufferPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case let .structMember(s) = interactor.currentArgument,
            case let .pointer(p) = interactor.nextArgument(),
            !p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .buffer(p, s)
    }
}

private struct ArgumentBufferPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case let .pointer(p) = interactor.currentArgument,
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentBuffer(p)
    }
}

private struct ArgumentContainingArgumentBufferPathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case let .argument(a) = interactor.currentArgument,
            case let .pointer(p) = interactor.nextArgument(),
            p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .argumentContainingArgumentBuffer(a, p)
    }

}

private class PathTypeContext<ArgumentArray: RandomAccessCollection>
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int {
    fileprivate var index = 0
    fileprivate var lastPathType: PathType?
    private var temporaryIndex = 0
    private let argumentPath: ArgumentArray
        
    var isFinished: Bool {
        index >= argumentPath.count
    }
    
    init(argumentPath: ArgumentArray) {
        self.argumentPath = argumentPath
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

extension PathTypeContext: PathInteractor {
    var currentArgument: Argument {
        argumentPath[argumentPath.startIndex + index]
    }
    
    func nextArgument() -> Argument? {
        guard index < argumentPath.count - 1 else {
            return nil
        }
        
        index += 1
        return argumentPath[argumentPath.startIndex + index]
    }
}

internal struct PathTypeIterator<ArgumentArray: RandomAccessCollection>: IteratorProtocol
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int {
    typealias Element = PathType
    
    private let context: PathTypeContext<ArgumentArray>
    
    private let pathRules: [PathRule] = [
        BytesFromMetalArrayPathRule(),
        BytesFromAtomicVariablePathRule(),
        ArgumentContainingArgumentBufferPathRule(),
        ArgumentPathRule(),
        BytesPathRule(),
        EncodableBytesPathRule(),
        EncodableBufferPathRule(),
        BufferPathRule(),
        ArgumentBufferPathRule()
    ]
    
    var isFinished: Bool {
        return context.isFinished
    }
    
    var argumentIndex: Int {
        return context.index
    }
    
    init(argumentPath: ArgumentArray) {
        self.context = PathTypeContext(argumentPath: argumentPath)
    }
    
    mutating func next() -> Self.Element? {
        while !context.isFinished {
            context.saveState()
            var current: PathType!

            for rule in pathRules {
                if let pathType = rule.apply(context) {
                    context.lastPathType = pathType
                    current = pathType
                    break
                } else {
                    context.loadState()
                }
            }
            
            print(current == nil)
            context.advance()
            
            if current != nil {
                return current
            }
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
    for argumentPath: ArgumentArray
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

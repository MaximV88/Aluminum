//
//  PathType.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal

internal enum SimplePathType {
    case argument
    case bytes
    case buffer
    case argumentBuffer
    case encodableBuffer
}

internal enum PathType {
    case argument(MTLArgument)
    case bytes(MTLStructMember)
    case buffer(MTLPointerType)
    case argumentBuffer(MTLPointerType)
    case encodableBuffer(MTLPointerType, MTLStructType)
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
}


private protocol PathInteractor {
    var currentArgument: Argument { get }
    
    @discardableResult
    func nextArgument() -> Argument?
}

private protocol PathRule {
    func apply(_ interactor: PathInteractor) -> PathType?
}

private class PathTypeContext<ArgumentArray: RandomAccessCollection>
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int {
    private var index = 0
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
        
        // skip 'array'
        guard case .array = interactor.nextArgument() else {
            return nil
        }
        
        return .bytes(s)
    }
}

private struct BytesFromAtomicVariablePathRule: PathRule {
    func apply(_ interactor: PathInteractor) -> PathType? {
        guard
            case .struct = interactor.currentArgument,
            case let .structMember(s) = interactor.nextArgument(),
            s.name == "__s"
            else
        {
            return nil
        }
        
        return .bytes(s)
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
            case let .structMember(s) = interactor.currentArgument,
            s.dataType != .pointer
            else
        {
            return nil
        }
        
        return .bytes(s)
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
            case let .pointer(p) = interactor.currentArgument,
            !p.elementIsArgumentBuffer
            else
        {
            return nil
        }
        
        return .buffer(p)
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

private let pathRules: [PathRule] = [
    BytesFromMetalArrayPathRule(),
    BytesFromAtomicVariablePathRule(),
    ArgumentPathRule(),
    BytesPathRule(),
    EncodableBufferPathRule(),
    BufferPathRule(),
    ArgumentBufferPathRule()
]

private struct PathTypeIterator<ArgumentArray: RandomAccessCollection>: IteratorProtocol
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int {
    typealias Element = PathType
    
    private let context: PathTypeContext<ArgumentArray>
    
    init(argumentPath: ArgumentArray) {
        self.context = PathTypeContext(argumentPath: argumentPath)
    }
    
    mutating func next() -> Self.Element? {
        while !context.isFinished {
            context.saveState()
            var current: PathType!

            for rule in pathRules {
                if let pathType = rule.apply(context) {
                    current = pathType
                    break
                } else {
                    context.loadState()
                }
            }
            
            context.advance()
            
            if current != nil {
                return current
            }
        }
        
        return nil
    }
}

internal func findPathType<ArgumentArray: RandomAccessCollection>(
    _ pathType: SimplePathType,
    for argumentPath: ArgumentArray
) -> PathType?
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    assert(!argumentPath.isEmpty)

    var iterator = PathTypeIterator(argumentPath: argumentPath)
    var result = iterator.next()
    
    // comapre with each item
    while result != nil {
        if result! == pathType {
            return result
        }
        result = iterator.next()
    }

    return nil
}

// find last PathType on given path
internal func queryPathType<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray
) -> PathType
where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    assert(!argumentPath.isEmpty)

    var iterator = PathTypeIterator(argumentPath: argumentPath)
    var result = iterator.next()
    
    // get to last item
    while result != nil {
        guard let value = iterator.next() else {
            break
        }
        result = value
    }
        
    assert(result != nil, "No rules were applied to argument path.")
    return result!
}

private func == (lhs: SimplePathType, rhs: PathType) -> Bool {
    return rhs == lhs
}

private func == (lhs: PathType, rhs: SimplePathType) -> Bool {
    switch (lhs, rhs) {
    case (.argument, .argument): return true
    case (.bytes, .bytes): return true
    case (.buffer, .buffer): return true
    case (.argumentBuffer, .argumentBuffer): return true
    case (.encodableBuffer, .encodableBuffer): return true
    default: return false
    }
}

//
//  Parser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal
// TODO: convert parsing to PathType mapping

internal class Parser {
    enum ParseType: Hashable {
        case named(String)
        case indexed
    }
    
    fileprivate typealias ParsePath = [ParseType]
        
    class Encoding {
        
        // remove and replace with direct expect child type from Encoder
        /// Valid path types that an encoder can have
        private static let validPathTypes: [SimplePathType] = [
            .argument,
            .argumentBuffer,
            .argumentContainingArgumentBuffer,
            .encodableBuffer
        ]

        
        let argumentPath: [Argument] // arguments from encoding root only
        
        var localArgumentPath: [Argument] {
            Array(argumentPath[argumentPathIndex...])
        }
        
        let pathType: PathType
                
        private let parsePath: [ParseType]
        private let parser: Parser
        private let argumentPathIndex: Int
        
        fileprivate init(argumentPath: [Argument],
                         parsePath: ParsePath,
                         parser: Parser,
                         argumentPathIndex: Int)
        {
            self.argumentPath = argumentPath
            self.parsePath = parsePath
            self.parser = parser
            self.argumentPathIndex = argumentPathIndex
            
            self.pathType = uniquePathType(from: argumentPath[argumentPathIndex...],
                                           for: Encoding.validPathTypes)
        }
        
        func childEncoding(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let argumentPath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }
                                    
            return Encoding(argumentPath: argumentPath,
                            parsePath: parsePath,
                            parser: parser,
                            argumentPathIndex: self.argumentPath.count)
        }
        
        func argumentPath(for localPath: Path) -> [Argument] {
            guard let argumentPath = parser.mapping[parsePath + localPath.parsePath] else {
                fatalError(.nonExistingPath)
            }

            // need validate by checking first encodable, then validating there are only 3 types,
            // where in case of encodableBuffer it needs to be last
            // still coupled if definition is inside this class
//            assert(containsOnlyPathTypes(from: argumentPath[argumentPathIndex...],
//                                         for: [.buffer, .bytes, .encodableBuffer]))

            return argumentPath
        }
        
        func localArgumentPath(for localPath: Path) -> [Argument] {
            return Array(argumentPath(for: localPath)[self.argumentPath.count...])
        }
    }
    
    
    fileprivate var mapping = [[ParseType]: [Argument]]()

    init(arguments: [MTLArgument]) {
        arguments.forEach {
            parseArgument($0)
        }
    }
        
    func encoding(for argument: String) -> Encoding {
        let parsePath: [ParseType] = [.named(argument)]
        guard let argumentPath = mapping[parsePath] else {
            fatalError(.unknownArgument(argument))
        }
                
        return Encoding(argumentPath: argumentPath,
                        parsePath: parsePath,
                        parser: self,
                        argumentPathIndex: 0)
    }
}

private extension Parser {
    func parseArgument(_ argument: MTLArgument) {
        traverseToLeaf([.argument(argument)])
    }
    
    func traverseToLeaf(_ argumentPath: [Argument]) {
        guard !argumentPath.last!.children().isEmpty else {
            // reached leaf
            processFromLeaf(argumentPath)
            return
        }
        
        for child in argumentPath.last!.children() {
            traverseToLeaf(argumentPath + [child])
        }
    }
    
    func processFromLeaf(_ argumentPath: [Argument]) {
        assert(!argumentPath.isEmpty)
        
        var iterator = PathTypeIterator(argumentPath: argumentPath)
        var aggragatePath = [ParseType]()
        
        while !iterator.isFinished {
            let result = iterator.next()!
            if let type = Parser.parseType(from: result) {
                aggragatePath.append(type)
            }
            
            // arguments assigned by path type processable chunks
            mapping[aggragatePath] = Array(argumentPath[...(iterator.argumentIndex - 1)])
        }
    }
    
    static func parseType(from pathType: PathType) -> ParseType? {
        switch pathType {
        case .argument(let a): return .named(a.name)
        case .argumentContainingArgumentBuffer(let a, _): return .named(a.name)
        case .bytes(_, let s) where s.dataType == .array: return .indexed // contains metalArray
        case .bytes(let t, let s) where t == .regular: return .named(s.name) // dont name metalArray, atomic
        case .buffer(_, let s): return .named(s.name)
        case .argumentBuffer(_, let s): return .named(s.name)
        case .encodableBuffer(_, _, let s): return .named(s.name)
        default: return nil
        }
    }
}

private extension Path {
    var parsePath: Parser.ParsePath {
        assert(!isEmpty)

        return compactMap {
            switch $0 {
            case .argument(let a): return .named(a)
            case .index: return .indexed
            }
        }
    }
}


private enum SimplePathType: CaseIterable {
    case argument
    case bytes
    case buffer
    case argumentBuffer
    case encodableBuffer
    case argumentContainingArgumentBuffer
}

// coupling of path definition to encoder from non related code
private func uniquePathType<ArgumentArray: RandomAccessCollection>(
    from argumentPath: ArgumentArray,
    for types: [SimplePathType]
) -> PathType
    where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    let path = pathTypes(from: argumentPath)
    assert(!path.isEmpty, .invalidEncoderPath) // TODO: check input on empty path
    
    var candidate: PathType!
    
    for type in types {
        let filtered = path.filter({ $0.simplified == type })
        assert(filtered.count <= 1, .invalidEncoderPath)
        
        if !filtered.isEmpty {
            assert(candidate == nil, .invalidEncoderPath)
            candidate = filtered.first!
        }
    }
    
    return candidate
}

private func containsOnlyPathTypes<ArgumentArray: RandomAccessCollection>(
    from argumentPath: ArgumentArray,
    for types: [SimplePathType]
) -> Bool
    where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    let path = pathTypes(from: argumentPath)
    assert(!path.isEmpty)

    for item in path {
        if !types.contains(item.simplified) {
            return false
        }
    }
    
    return true
}

private extension PathType {
    var simplified: SimplePathType {
        switch self {
        case .argument: return .argument
        case .bytes: return .bytes
        case .buffer: return .buffer
        case .argumentBuffer: return .argumentBuffer
        case .encodableBuffer: return .encodableBuffer
        case .argumentContainingArgumentBuffer: return .argumentContainingArgumentBuffer
        }
    }
}

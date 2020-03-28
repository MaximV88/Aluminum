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
            assert(validatePathLocality(for: argumentPath[argumentPathIndex...],
                                        allowedFirstPathTypes: [.argument, .argumentBuffer, .argumentContainingArgumentBuffer, .encodableBuffer],
                                        allowedPathTypes: [.buffer, .bytes],
                                        allowedLastPathTypes: [.buffer, .bytes, .encodableBuffer])) // bad implementation - allows for non related

            self.argumentPath = argumentPath
            self.parsePath = parsePath
            self.parser = parser
            self.argumentPathIndex = argumentPathIndex
            self.pathType = firstPathType(for: argumentPath[argumentPathIndex...])
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

            assert(validatePathLocality(for: argumentPath[argumentPathIndex...],
                                        allowedFirstPathTypes: [.argument, .argumentBuffer, .argumentContainingArgumentBuffer],
                                        allowedPathTypes: [.buffer, .bytes],
                                        allowedLastPathTypes: [.buffer, .bytes, .encodableBuffer]))

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
        // dont name metalArray, atomic
        switch pathType {
        case .argument(let a): return .named(a.name)
        case .argumentContainingArgumentBuffer(let a, _): return .named(a.name)
        case .bytes(let s, _) where s.dataType == .array: return .indexed
        case .bytes(let s, let t) where t == .regular: return .named(s.name)
        case .buffer(_, let t): return .named(t.name)
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


internal enum SimplePathType: CaseIterable {
    case argument
    case bytes
    case buffer
    case argumentBuffer
    case encodableBuffer
    case argumentContainingArgumentBuffer
}

// coupling of path definition to encoder from non related code
internal func validatePathLocality<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray,
    allowedFirstPathTypes: [SimplePathType],
    allowedPathTypes: [SimplePathType],
    allowedLastPathTypes: [SimplePathType] = []
) -> Bool
    where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    let path = pathTypes(for: argumentPath)
    assert(!path.isEmpty)
    
    if path.count >= 1 {
        if !allowedFirstPathTypes.contains(path[0].simplified) {
            assertionFailure(.invalidEncoderPath)
        }
    }
    
    if path.count >= 2 {
        if !allowedLastPathTypes.contains(path[path.count - 1].simplified) {
            assertionFailure(.invalidEncoderPath)
        }
    }
    
    if path.count >= 3 {
        for pathType in path[1...path.count - 2] {
            if !allowedPathTypes.contains(pathType.simplified) {
                assertionFailure(.invalidEncoderPath)
            }
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

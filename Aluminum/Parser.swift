//
//  Parser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class Parser {
    enum ParseType: Hashable {
        case named(String)
        case indexed
    }
    
    fileprivate typealias ParsePath = [ParseType]
        
    class Encoding {
        
        let argumentPath: [Argument]
        let pathType: PathType
                
        private let parsePath: [ParseType]
        private let parser: Parser
        private let pathTypeStartIndex: Int
        private let pathTypeEndingIndex: Int
        
        fileprivate init(argumentPath: [Argument],
                         parsePath: ParsePath,
                         pathType: PathType,
                         parser: Parser,
                         pathTypeStartIndex: Int,
                         pathTypeEndingIndex: Int)
        {
            assert(validateEncodablePath(from: argumentPath[pathTypeStartIndex...]), .invalidEncoderPath)

            self.argumentPath = argumentPath
            self.parsePath = parsePath
            self.pathType = pathType
            self.parser = parser
            self.pathTypeStartIndex = pathTypeStartIndex
            self.pathTypeEndingIndex = pathTypeEndingIndex
        }
        
        func childEncoding(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let argumentPath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }
            
            var iterator = PathTypeIterator(argumentPath: argumentPath[self.argumentPath.count...])
            while !iterator.isFinished {
                let pathType = iterator.next()!
                if case .bytes = pathType {
                    continue
                }
                                
                return Encoding(argumentPath: argumentPath,
                                parsePath: parsePath,
                                pathType: pathType,
                                parser: parser,
                                pathTypeStartIndex: iterator.lastArgumentIndex,
                                pathTypeEndingIndex: iterator.argumentIndex)
            }
            
            fatalError(.invalidEncoderPath) // TODO: path is filled with bytes 
        }
                
        func localArgumentPath(for localPath: Path, rootInclusive: Bool) -> [Argument] {
            guard let argumentPath = parser.mapping[parsePath + localPath.parsePath] else {
                fatalError(.nonExistingPath)
            }

            assert(validateEncodablePath(from: argumentPath[pathTypeEndingIndex...]), .invalidEncoderPath)
            return Array(argumentPath[(rootInclusive ? pathTypeStartIndex : pathTypeEndingIndex)...])
        }
        
        func localArgumentPath(to childEncoder: Encoding) -> [Argument] {
            // validate encoders share same path
            assert(childEncoder.argumentPath[0...(argumentPath.count - 1)] == argumentPath[...])
            return Array(childEncoder.argumentPath[pathTypeEndingIndex...(childEncoder.pathTypeEndingIndex - 1)])
        }
    }
    
    struct Data {
        let argumentPath: [Argument]
        let typePath: [PathType]
    }
    
    fileprivate var mapping = [[ParseType]: [Argument]]() // replace with path type

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
                
        var iterator = PathTypeIterator(argumentPath: argumentPath)

        return Encoding(argumentPath: argumentPath,
                        parsePath: parsePath,
                        pathType: iterator.next()!,
                        parser: self,
                        pathTypeStartIndex: 0,
                        pathTypeEndingIndex: iterator.argumentIndex)
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

private func validateEncodablePath<ArgumentArray: RandomAccessCollection>(
    from argumentPath: ArgumentArray
) -> Bool
    where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    let path = pathTypes(from: argumentPath)
    assert(!path.isEmpty)
    
    var encounteredEncodable = false

    for item in path {
        if !item.isBytes {
            guard !encounteredEncodable else {
                return false
            }
            
            encounteredEncodable = true
        }
    }
    
    return true
}

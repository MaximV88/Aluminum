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
                                        allowedPathTypes: [.buffer, .bytes]))

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
                                        allowedPathTypes: [.buffer, .bytes]))

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
        parseArgumentPath([.argument(argument)])
    }
    
    func parseArgumentPath(_ argumentPath: [Argument], from path: ParsePath = []) {
        let type = Parser.parseType(for: argumentPath.last!)
        let currentPath = type != nil ? path + [type!] : path
        
        // children should override parent's mapping, assign before recursion
        mapping[currentPath] = argumentPath
        
        for child in argumentPath.last!.children() {
            parseArgumentPath(argumentPath + [child], from: currentPath)
        }
    }
    
    static func parseType(for argument: Argument) -> ParseType? {
        switch argument {
        case .argument(let a): return .named(a.name)
        case .structMember(let s) where s.dataType != .array && s.name != "__s":
            return .named(s.name) // redundant '__s' naming
        case .array: return .indexed
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

internal func validatePathLocality<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray,
    allowedPathTypes: [SimplePathType]
) -> Bool
    where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
{
    let test = pathTypes(for: argumentPath)[1...]
    for pathType in test {
        if !allowedPathTypes.contains(pathType.simplified) {
            assertionFailure(.invalidEncoderPath)
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

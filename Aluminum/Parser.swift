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
                         argumentPathIndex: Int,
                         pathType: PathType)
        {
            self.argumentPath = argumentPath
            self.parsePath = parsePath
            self.parser = parser
            self.argumentPathIndex = argumentPathIndex
            self.pathType = pathType
        }
        
        func childArgumentEncoding(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let argumentPath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }
            
            assert(validatePathLocality(for: argumentPath[self.argumentPath.count...],
                                        localPath: localPath,
                                        containsEncoder: true))
            
            let pathType = firstPathType(for: argumentPath[self.argumentPath.count...])
            assert(pathType.isArgumentBuffer, .invalidChildEncoderPath(pathType))
            
            return Encoding(argumentPath: argumentPath,
                            parsePath: parsePath,
                            parser: parser,
                            argumentPathIndex: self.argumentPath.count,
                            pathType: pathType)
        }
        
        func childBytesEncoder(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let argumentPath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }

            assert(validatePathLocality(for: argumentPath[self.argumentPath.count...],
                                        localPath: localPath,
                                        containsEncoder: false))
            
            let pathType = firstPathType(for: argumentPath[self.argumentPath.count...])
            assert(pathType.isBytes, .invalidChildEncoderPath(pathType))

            return Encoding(argumentPath: argumentPath,
                            parsePath: parsePath,
                            parser: parser,
                            argumentPathIndex: self.argumentPath.count,
                            pathType: pathType)
        }
        
        func argumentPath(for localPath: Path) -> [Argument] {
            guard let argumentPath = parser.mapping[parsePath + localPath.parsePath] else {
                fatalError(.nonExistingPath)
            }

            assert(validatePathLocality(for: argumentPath[self.argumentPath.count...],
                                        localPath: localPath,
                                        containsEncoder: false))
            
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
        
        let pathType = firstPathType(for: argumentPath)
        assert(pathType.isArgument || pathType.isArgumentContainingArgumentBuffer)
        
        return Encoding(argumentPath: argumentPath,
                        parsePath: parsePath,
                        parser: self,
                        argumentPathIndex: 0,
                        pathType: pathType)
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
        case .structMember(let s) where s.dataType != .array: return .named(s.name) // redundant '__elem' naming, case handled by array
        case .array: return .indexed
        default: return nil
        }
    }
}

// TODO: refactor with rules - innacurate for non last pointers (i.e. encoder cant have a non coding pointer after a pointer or vice-a-versa
private func validatePathLocality<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray,
    localPath: Path,
    containsEncoder: Bool
) -> Bool
    where ArgumentArray.Element == Argument
{
    assert(!argumentPath.isEmpty)
    var pathIndex: Int = 0
    var expectedEncoders = (containsEncoder ? 1 : 0)

    for item in argumentPath {
        switch item {
        case .array:
            pathIndex += 1
        case .structMember(let s):
            // ignore array struct as argument since they are not part of path
            if s.dataType != .array {
                pathIndex += 1
            }
        case .pointer(let p) where p.elementIsArgumentBuffer:
            if expectedEncoders < 0 {
                assertionFailure(.invalidEncoderPath(pathIndex))
            }
            expectedEncoders -= 1
        case .argument:
            fatalError("Logical error in parser.")
        default: break
        }
    }

    assert(expectedEncoders == 0)
    return true
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

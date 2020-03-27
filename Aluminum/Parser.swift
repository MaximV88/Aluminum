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
        enum EncodingType {
            case argument(MTLArgument)
            case argumentBuffer(MTLPointerType)
            case argumentContainingArgumentBuffer(MTLArgument, MTLPointerType)
        }
        
        let argumentPath: [Argument] // arguments from encoding root only
        var localArgumentPath: [Argument] {
            Array(argumentPath[argumentPathIndex...])
        }
        let encodingType: EncodingType
        
                
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
            self.encodingType = Parser.Encoding.encodingType(for: argumentPath[argumentPathIndex...])
        }
        
        func childEncoding(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let argumentPath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }

            assert(validatePathLocality(for: argumentPath[self.argumentPath.count...],
                                        localPath: localPath,
                                        containsEncoder: true))

            return Encoding(argumentPath: argumentPath,
                            parsePath: parsePath,
                            parser: parser,
                            argumentPathIndex: self.argumentPath.count)
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
        
        return Encoding(argumentPath: argumentPath,
                        parsePath: parsePath,
                        parser: self,
                        argumentPathIndex: 0)
    }
}

// TODO: refactor with rules
private extension Parser.Encoding {
    static func encodingType<ArgumentArray: RandomAccessCollection>(for
        argumentPath: ArgumentArray
    ) -> EncodingType
        where ArgumentArray.Element == Argument, ArgumentArray.Index == Int
    {
        assert(!argumentPath.isEmpty)
        
        var type: EncodingType?
        switch argumentPath.first! {
        case .argument(let a): type = .argument(a)
        case .pointer(let p) where p.elementIsArgumentBuffer: type = .argumentBuffer(p)
        default: type = nil
        }
        
        if case let .argument(argument) = type,
            argumentPath.count > 1,
            case let .pointer(pointer) = argumentPath[1],
            pointer.elementIsArgumentBuffer
        {
            return .argumentContainingArgumentBuffer(argument, pointer)
        }
        
        if let type = type {
            return type
        }

        guard let argumentEncoder = argumentPath.first(where: {
            switch $0 {
            case .pointer(let p) where p.elementIsArgumentBuffer: return true
            default: return false
            }
        }) else {
            // TODO: fix
            fatalError("fix readability with rules")
        }
        
        guard case let .pointer(p) = argumentEncoder else {
            fatalError("Illogical")
        }
        
        return .argumentBuffer(p)
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

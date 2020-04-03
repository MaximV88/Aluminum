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
        
        let dataTypePath: [DataType]
        
        var dataType: DataType {
            return dataTypePath[startIndex]
        }
        
        private let parsePath: [ParseType]
        private let parser: Parser
        private let startIndex: Int
        
        fileprivate init(dataTypePath: [DataType],
                         parsePath: ParsePath,
                         parser: Parser,
                         startIndex: Int)
        {
            assert(validateEncodablePath(from: dataTypePath[startIndex...]), .invalidEncoderPath)

            self.dataTypePath = dataTypePath
            self.parsePath = parsePath
            self.parser = parser
            self.startIndex = startIndex
        }
        
        func childEncoding(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let dataTypePath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }
            
            for (index, dataType) in dataTypePath[(startIndex + 1)...].enumerated() {
                if case .bytes = dataType { continue }
                if case .bytesContainer = dataType { continue }
                
                return Encoding(dataTypePath: dataTypePath,
                                parsePath: parsePath,
                                parser: parser,
                                startIndex: index + 1)
            }
                        
            fatalError(.invalidChildEncoderPath) // TODO: path is filled with bytes 
        }
                
        func localDataTypePath(for localPath: Path) -> [DataType] {
            guard let dataTypePath = parser.mapping[parsePath + localPath.parsePath] else {
                fatalError(.nonExistingPath)
            }

            assert(validateEncodablePath(from: dataTypePath[(startIndex + 1)...]), .invalidEncoderPath)
            return Array(dataTypePath[startIndex...])
        }
        
        func localDataTypePath(to childEncoder: Encoding) -> [DataType] {
            // validate encoders share same path
            assert(childEncoder.dataTypePath[0...(dataTypePath.count - 1)] == dataTypePath[...])
            return Array(childEncoder.dataTypePath[startIndex...childEncoder.startIndex])
        }
    }
    

    fileprivate var mapping = [[ParseType]: [DataType]]() // replace with path type

    init(arguments: [MTLArgument]) {
        arguments.forEach {
            parseArgument($0)
        }
    }
        
    func encoding(for argument: String) -> Encoding {
        let parsePath: [ParseType] = [.named(argument)]
        guard let dataTypePath = mapping[parsePath] else {
            fatalError(.unknownArgument(argument))
        }
                
        return Encoding(dataTypePath: dataTypePath,
                        parsePath: parsePath,
                        parser: self,
                        startIndex: 0)
    }
}

private extension Parser {
    func parseArgument(_ argument: MTLArgument) {
        traverseToLeaf([.argument(argument)])
    }
    
    func traverseToLeaf(_ metalTypePath: [MetalType]) {
        guard !metalTypePath.last!.children().isEmpty else {
            // reached leaf
            processFromLeaf(metalTypePath)
            return
        }
        
        for child in metalTypePath.last!.children() {
            traverseToLeaf(metalTypePath + [child])
        }
    }
    
    func processFromLeaf(_ metalTypePath: [MetalType]) {
        assert(!metalTypePath.isEmpty)
        
        var iterator = DataTypeIterator(metalTypePath: metalTypePath)
        var aggragateParsePath = [ParseType]()
        var aggragateDataTypePath = [DataType]()
        
        while !iterator.isFinished {
            let result = iterator.next()!
             aggragateDataTypePath.append(result)
            
            let types = Parser.parseTypes(from: result)
            aggragateParsePath.append(contentsOf: types)
            
            // arguments assigned by path type processable chunks
            mapping[aggragateParsePath] = aggragateDataTypePath
        }
    }
    
    static func parseTypes(from pathType: DataType) -> [ParseType] {
        switch pathType {
        case .argument(let a): fallthrough
        case .argumentContainingArgumentBuffer(let a, _): return [.named(a.name)]
        case .bytesContainer(let s): return [.named(s.name)]
        case .bytes(let t, let s) :
            switch t {
            case .regular: return [.named(s.name)]
            case .atomic: return []
            case .array: return [.named(s.name), .indexed]
            case .metalArray: return[.indexed]
            }
        case .buffer(_, let s): return [.named(s.name)]
        case .argumentBuffer(_, let s): return [.named(s.name)]
        case .encodableBuffer(_, _, let s): return [.named(s.name)]
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

private func validateEncodablePath<DataTypeArray: RandomAccessCollection>(
    from path: DataTypeArray
) -> Bool
    where DataTypeArray.Element == DataType, DataTypeArray.Index == Int
{
    assert(!path.isEmpty)
    
    var encounteredEncodable = false

    for item in path {
        if !(item.isBytes || item.isBytesContainer) {
            guard !encounteredEncodable else {
                return false
            }
            
            encounteredEncodable = true
        }
    }
    
    return true
}

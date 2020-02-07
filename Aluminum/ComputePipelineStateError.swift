//
//  ComputePipelineStateError.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 03/02/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation


public enum ComputePipelineStateError: Error {
    case noPathFound
    case invalidIndexSize
    case invalidIndexFormat
}

extension ComputePipelineStateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Path doesnt exist.", comment: "Non existing path error")
        case .invalidIndexSize: return NSLocalizedString("Invalid syntax.", comment: "Invalid syntax error")
        case .invalidIndexFormat: return NSLocalizedString("Invalid syntax.", comment: "Invalid syntax error")
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Path was not parsed from arguments.", comment: "Non existing path failure reason")
        case .invalidIndexSize: return NSLocalizedString("Invalid syntax.", comment: "Invalid syntax error")
        case .invalidIndexFormat: return NSLocalizedString("Syntax does not match arguments.", comment: "Invalid syntax failure reason")
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noPathFound: return NSLocalizedString("Make sure path is correctly typed.", comment: "Non existing path recovery suggestion")
        case .invalidIndexSize: return NSLocalizedString("Invalid syntax.", comment: "Invalid syntax error")
        case .invalidIndexFormat: return NSLocalizedString("Check syntax.", comment: "Invalid syntax recovery suggestion")
        }
    }
}


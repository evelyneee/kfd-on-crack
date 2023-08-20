//
//  StringError.swift
//  libjailbreak
//
//  Created by Serena on 20/08/2023.
//  

import Foundation

/// A generic error described only by it's string.
public struct StringError: Error, LocalizedError {
    public let description: String
    
    public init(_ description: String) {
        self.description = description
    }
    
    public var errorDescription: String? { description }
}

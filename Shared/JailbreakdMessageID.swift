//
//  JailbreakdMessageID.swift
//  kfd
//
//  Created by Serena on 13/08/2023.
//  

import Foundation

@objc
enum JailbreakdMessageID: Int64 {
    /// Process the binary that jbd is given.
    case processBinary
    
    /// Initialize with a given kfd.
    case initializeKfd
    
#if DEBUG
    /// Hello World reply/receive.
    case helloWorld
#endif
}

//
//  JailbreakdError.swift
//  kfd
//
//  Created by Serena on 12/08/2023.
//  

import Foundation

// Error codes to be used with NSError in JailbreakdServer
enum JailbreakdErrorCode: Int {
    case noError
    case failedToDisableJetsam
    case notRunningAsRoot
    case bootstrapCheckinFailed
}

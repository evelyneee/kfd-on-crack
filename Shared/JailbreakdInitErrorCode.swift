//
//  JailbreakdInitErrorCode.swift
//  kfd
//
//  Created by Serena on 12/08/2023.
//  

import Foundation

// Error codes to be used with NSError in JailbreakdServer when initializing Jailbreakd
enum JailbreakdInitErrorCode: Int {
    case noError
    case failedToDisableJetsam
    case notRunningAsRoot
    case bootstrapCheckinFailed
    case bootstrapCheckinFailedSystemWide
}

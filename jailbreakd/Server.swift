//
//  Server.swift
//  jailbreakd
//
//  Created by Serena on 12/08/2023.
//  

import Foundation

@objc
class JailbreakdServer: NSObject {
    
    static private func _makeError(errorCode: JailbreakdErrorCode, description: String) -> NSError {
        return NSError(domain: "com.serena.jailbreakd.daemon", code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    // We return the error enum number instead of throwing
    // so that the actual main in the objc file can get the rawvalue and return it
    static private func mainImpl() throws {
        NSLog("Maruki Jailbreakd reporting in.")
        
        guard getuid() == 0 else {
            NSLog("getuid didn't return 0 somehow??? no root?")
            
            throw _makeError(errorCode: .notRunningAsRoot, description: "Not running as root")
        }
        
        
        if setJetsamEnabled(false) < 0 {
            NSLog("Failed to set jetsam status??")
        } else {
            NSLog("Set jetsam status successfully")
        }
        
        var checkinMachPort: mach_port_t = 0
        // For processes to look us up
        let kr = bootstrap_check_in(bootstrap_port, "com.serena.jailbreakd", &checkinMachPort)
        guard kr == KERN_SUCCESS else {
            throw _makeError(errorCode: .bootstrapCheckinFailed,
                             description: "Failed to bootstrap checkin for com.serena.jailbreakd, cause: \(String(cString: mach_error_string(kr)))")
        }
        
        let source = DispatchSource.makeMachReceiveSource(port: checkinMachPort, queue: .main)
        
        source.setEventHandler {
            let lMachPort = source.handle
            didReceiveMessage(fromPort: lMachPort)
        }
        
        source.resume()
        
        NSLog("Got here!")
        
        dispatchMain()
        
        //return .noError
    }
    
    @objc
    static public func main() throws {
        try mainImpl()
    }
}

extension JailbreakdServer {
    static func didReceiveMessage(fromPort port: mach_port_t) {
        NSLog("Recieved message!!")
        
        NSLog("handle message?")
        
//        var message: xpc_object_t? = nil
//        xpc_pipe_receive(port, &message)
        
    }
}

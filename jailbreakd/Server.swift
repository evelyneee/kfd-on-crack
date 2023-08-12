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
        return NSError(domain: "com.serena.jailbreakd.daemon",
                       code: errorCode.rawValue,
                       userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    static var _logfile = {
        let logFilePath = "/var/jb/.basebin_curr_log"
        
        return fopen(logFilePath, "a")
    }()
    
    
    static func log(_ string: String) {
        if let _logfile {
            jbd_printf(string, _logfile)
        }
        
        NSLog(string)
    }
    
    static private func mainImpl() throws {
        log("Maruki Jailbreakd reporting in.")
        
        guard getuid() == 0 else {
            log("getuid didn't return 0 somehow??? no root?")
            
            throw _makeError(errorCode: .notRunningAsRoot, description: "Not running as root")
        }
        
        
        if setJetsamEnabled(false) < 0 {
            log("Failed to set jetsam status??")
        } else {
            log("Set jetsam status successfully")
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
        
        log("Got here!")
        
        dispatchMain()
        
        //return .noError
    }
    
    @objc(serverMainWithError:)
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

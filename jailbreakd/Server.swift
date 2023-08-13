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
        log("Recieved message!!")
        
        var message: xpc_object_t? = nil
        xpc_pipe_receive(port, &message)
        guard let message else {
            log("!!! JBD FATALERROR !!! MESSAGE NIL")
            return
        }
        
        guard xpc_object_is_dict(message) else { return }
        let reply = xpc_dictionary_create_reply(message)
        
        var audit = audit_token_t()
        xpc_dictionary_get_audit_token(message, &audit)
        
        let msgId = xpc_dictionary_get_int64(message, "id")
        guard let type = JailbreakdMessageID(rawValue: msgId) else { return }
        
        switch type {
        case .processBinary:
            guard let _filePathCstr = xpc_dictionary_get_string(message, "filePath") else { return }
            let filePath = String(cString: _filePathCstr)
            NSLog(filePath)
        }
    }
}

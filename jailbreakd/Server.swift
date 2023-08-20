//
//  Server.swift
//  jailbreakd
//
//  Created by Serena on 12/08/2023.
//  

import Foundation
import libjailbreak

@objc
class JailbreakdServer: NSObject {
    
    static private func _makeError(errorCode: JailbreakdInitErrorCode, description: String) -> NSError {
        return NSError(domain: "com.serena.jailbreakd.daemon",
                       code: .init(errorCode.rawValue),
                       userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    static var _logfile = {
        let logFilePath = "/var/jb/.basebin_curr_log"
        
        return fopen(logFilePath, "a")
    }()
    
    
    static func log(_ string: String, terminator: String = "\n") {
        if let _logfile {
            jbd_printf(string + terminator, _logfile)
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
            didReceiveMessage(fromPort: lMachPort, systemWide: false)
        }
        
        source.resume()
        
        log("initialized com.serena.jailbreakd")
        
        var machPortSystemWide: mach_port_t = 0
        let systemWideReturnStatus = bootstrap_check_in(bootstrap_port, "com.serena.jailbreakd.systemwide", &machPortSystemWide)
        guard systemWideReturnStatus == KERN_SUCCESS else {
            throw _makeError(errorCode: .bootstrapCheckinFailed, description: "Failed to bootstrap checkin for com.serena.jailbreakd.systemwide, cause: \(String(cString: mach_error_string(systemWideReturnStatus)))")
        }
        
        let sourceSystemWide = DispatchSource.makeMachReceiveSource(port: machPortSystemWide, queue: .main)
        sourceSystemWide.setEventHandler {
            let lMachPort = source.handle
            didReceiveMessage(fromPort: lMachPort, systemWide: true)
        }
        
        sourceSystemWide.resume()
        
        log("Initialized com.serena.jailbreakd.systemwide")
        
        dispatchMain()
    }
    
    @objc(initializeServerMainWithError:)
    static public func main() throws {
        try mainImpl()
    }
}

extension JailbreakdServer {
    static func didReceiveMessage(fromPort port: mach_port_t, systemWide: Bool) {
        log("Recieved message!!")
        
        var message: xpc_object_t? = nil
        xpc_pipe_receive(port, &message)
        guard let message else {
//            log("!!! JBD FATALERROR !!! MESSAGE NIL")
            return
        }
        
        guard xpc_object_is_dict(message) else { return }
        let reply = xpc_dictionary_create_reply(message)!
        
        var audit = audit_token_t()
        xpc_dictionary_get_audit_token(message, &audit)
        
        let msgId = xpc_dictionary_get_int64(message, "id")
        guard let type = JailbreakdMessageID(rawValue: msgId) else {
            log("Got here unfortunately")
            return
        }
        
        log("Type: \(type)")
        
        NSLog("uid:%d", getuid())
        
        switch type {
        case .processBinary:
            guard let _filePathCstr = xpc_dictionary_get_string(message, "filePath") else { return }
            let filePath = String(cString: _filePathCstr)
            log(filePath)
            processBinary(atPath: filePath)
            
            xpc_dictionary_set_bool(reply, "success", true) // make this dependant on whether or not processBinary throws once implemented
        case .krwBegin:
            krw_client = getRootPort()
            
            print("krw_port:", krw_client)
            xpc_dictionary_set_uint64(reply, "krw_port", UInt64(krw_client))
        case .krwReady:
            
            NSLog("krwready???")
            
            kernel_slide = xpc_dictionary_get_uint64(message, "slide")
            current_proc = xpc_dictionary_get_uint64(message, "proc")
            fake_client = xpc_dictionary_get_uint64(message, "fake_client")
            mach_vm_allocate_kernel_func = xpc_dictionary_get_uint64(message, "mach_vm_allocate_kernel_func")
            kalloc_scratchbuf = xpc_dictionary_get_uint64(message, "kalloc_scratchbuf")
            jbd_kernelmap = xpc_dictionary_get_uint64(message, "kernelmap")
            
            print(String(format: "slide: 0x%02llX, proc: 0x%02llX, fake_client: 0x%02llX, kalloc: 0x%02llX, scratch: 0x%02llX, map: 0x%02llX", kernel_slide, current_proc, fake_client, mach_vm_allocate_kernel_func, kalloc_scratchbuf, jbd_kernelmap))
            print(String(format: "0x%02llX", kernel_slide), String(format: "0x%02llX", current_proc))
            
            NSLog("test read from jbd \(String(format: "0x%02llX", kckr64(virt: kalloc_scratchbuf)))")
            kckw64(virt: kalloc_scratchbuf, what: 0x4141414156565656)
            NSLog("test read from jbd2 \(String(format: "0x%02llX", kckr64(virt: kalloc_scratchbuf)))")
            print("jbd kalloc:", jbd_kalloc(0x4000))
            break
        }
        
        xpc_pipe_routine_reply(reply)
    }
    
    static func processBinary(atPath path: String) {
        // put impl here soon
    }
}

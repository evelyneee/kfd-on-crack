//
//  Server.swift
//  jailbreakd
//
//  Created by Serena on 12/08/2023.
//  

import Foundation
import libjailbreak
import PatchfinderUtils
import SwiftMachO

@objc
class JailbreakdServer: NSObject {
    
    @objc
    static var kernel_proc: UInt64 = 0
    
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
        
        print(String(format: "pitc: 0x%02llX, br x6: 0x%02llX, ldr w0, [x2, x1]: 0x%02llX, str w1, [x2]: 0x%02llX", kpf?.pmap_image4_trust_caches ?? 0, kpf?.br_x6 ?? 0, kpf?.ldr_w0_x2_x1_ret ?? 0, kpf?.str_w1_x2_ret ?? 0))
        
        dispatchMain()
    }
    
    @objc(initializeServerMainWithError:)
    static public func main() throws {
        try mainImpl()
    }
    
    static var kpf = {
        
        if let alreadyDecompressed = getKernelcacheDecompressedPath(), let data = try? Data(contentsOf: URL(fileURLWithPath: alreadyDecompressed)) {
            let macho = try! MachO(fromData: data, okToLoadFAT: true)
            return KPF(kernel: macho)
        }
        
        if let kcache = getKernelcachePath(), let decompr = loadImg4Kernel(path: kcache) {
            let macho = try! MachO(fromData: decompr, okToLoadFAT: true)
            print(macho)
            
            if let decomprPath = getKernelcacheDecompressedPath() {
                try! decompr.write(to: URL(fileURLWithPath: decomprPath))
            }
            
            return KPF(kernel: macho)
        }
        
        return nil
    }()
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
            do {
                try processBinary(atPath: filePath)
                xpc_dictionary_set_bool(reply, "success", true)
            } catch {
                xpc_dictionary_set_bool(reply, "success", false)
                xpc_dictionary_set_string(reply, "error", error.localizedDescription)
            }
            
        case .krwBegin:
            krw_client = getRootPort()
            
            print("krw_port:", krw_client)
            
            if let br_x6 = kpf?.br_x6 {
                jailbreakd.kcall6_nox0_offset = br_x6
            } else {
                print("no br x6")
            }
            
            xpc_dictionary_set_uint64(reply, "krw_port", UInt64(krw_client))
        case .krwReady:
            
            NSLog("krwready???"); sleep(1);
            
            kernel_slide = xpc_dictionary_get_uint64(message, "slide")
            current_proc = xpc_dictionary_get_uint64(message, "proc")
            fake_client = xpc_dictionary_get_uint64(message, "fake_client")
            mach_vm_allocate_kernel_func = xpc_dictionary_get_uint64(message, "mach_vm_allocate_kernel_func")
            kalloc_scratchbuf = xpc_dictionary_get_uint64(message, "kalloc_scratchbuf")
            
            jbd_kernelmap = xpc_dictionary_get_uint64(message, "kernelmap")
            rk32_static_gadget = xpc_dictionary_get_uint64(message, "ldr_w0_x2_x1") - kernel_slide
            wk32_static_gadget = xpc_dictionary_get_uint64(message, "str_w1_x2") - kernel_slide
            kernel_proc = xpc_dictionary_get_uint64(message, "kernel_proc")
            
            let jbdTask = xpc_dictionary_get_uint64(message, "jbd_task")
            
            NSLog("jbdTask: \(jbdTask)")
            
            print(String(format: "slide: 0x%02llX, proc: 0x%02llX, fake_client: 0x%02llX, kalloc: 0x%02llX, scratch: 0x%02llX, map: 0x%02llX", kernel_slide, current_proc, fake_client, mach_vm_allocate_kernel_func, kalloc_scratchbuf, jbd_kernelmap))
            
            print(String(format: "0x%02llX", kernel_slide), String(format: "0x%02llX", current_proc))
            
            NSLog("test read from jbd \(String(format: "0x%02llX", kckr64(virt: kalloc_scratchbuf)))")
            kckw64(virt: kalloc_scratchbuf, what: 0x4141414156565656)
            NSLog("test read from jbd2 \(String(format: "0x%02llX", kckr64(virt: kalloc_scratchbuf)))"); sleep(1);
            print("jbd kalloc:", jbd_kalloc(0x4000))
            NSLog("jbd_dirty_kalloc: \(jbd_dirty_kalloc(0x4000))")
            
            allocate_new_tc_page(jbdTask);
            xpc_dictionary_set_bool(reply, "success", true)
            
        }
        
        xpc_pipe_routine_reply(reply)
    }
    
    /*
    static func processBinary(atPath path: String) throws {
        guard let machoFile = fopen((path as NSString).fileSystemRepresentation, "rb") else {
            throw StringError("Couldn't open \(path)")
        }
        
        defer { fclose(machoFile) }
        
        var isMacho: Bool = false
        var isLibrary: Bool = false
        machoGetInfo(machoFile, &isMacho, &isLibrary)
        
        guard isMacho else {
            throw StringError("NaM: Not-A-MachO")
        }
        
        let bestCandidate = machoFindBestArch(machoFile)
//        NSLog("bestCanidate: \(bestCandidate)")
//        guard bestCandidate > 0 else {
//            throw StringError("bestCanidate not beyond 0 :(")
//        }
        
        var nonTrustedCDHashes: [Data] = []
        
        let tcCheckBlock: (String?) -> Void = { depPath in
            NSLog(depPath.debugDescription)
            
            guard let depPath = depPath else { return }
            let depURL = URL(fileURLWithPath: depPath)
            var cdHash: NSData? = nil
            var isAdhocSigned: ObjCBool = false
            evaluateSignature(depURL, &cdHash, &isAdhocSigned)
            
            NSLog("is cdHash data nil for path \(path)? \(cdHash == nil ? "Yes" : "No")")
            NSLog("\(path) is Adhoc? \(isAdhocSigned.boolValue)")
            
            if let cdHash {
                NSLog("\(path) is in existing cdhash? \(isCdHashInTrustCache(cdHash as Data))")
                nonTrustedCDHashes.append(cdHash as Data)
            }
        }
        
        tcCheckBlock(path)
        
        let bestArch: UInt32 = UInt32(bestCandidate)
        machoEnumerateDependencies(machoFile, bestArch, path, tcCheckBlock)
        
        NSLog("nonTrustedCDHashes: \(nonTrustedCDHashes)")
        dynamicTrustCacheUploadCDHashesFromArray(nonTrustedCDHashes)
        
        for data in nonTrustedCDHashes {
            NSLog("After calling dynamicTrustCacheUploadCDHashesFromArray, is \(data) in amfi? (should be yes) \(isCdHashInTrustCache(data))")
        }
    }
    */
    
    static func processBinary(atPath path: String) throws {
        guard let machoFile = fopen((path as NSString).fileSystemRepresentation, "rb") else {
            throw StringError("Couldn't open \(path)")
        }
        defer { fclose(machoFile) }
        var isMacho: Bool = false
        var isLibrary: Bool = false
        machoGetInfo(machoFile, &isMacho, &isLibrary)
        guard isMacho else {
            throw StringError("NaM: Not-A-MachO")
        }
        
        let bestCandidate = machoFindBestArch(machoFile)
        var nonTrustedCDHashes: [Data] = []
        let tcCheckBlock: (String?) -> Void = { depPath in
            NSLog(depPath.debugDescription)
            
            guard let depPath = depPath else { return }
            let depURL = URL(fileURLWithPath: depPath)
            var cdHash: NSData? = nil
            var isAdhocSigned: ObjCBool = false
            evaluateSignature(depURL, &cdHash, &isAdhocSigned)
            
            NSLog("is cdHash data nil for path \(path)? \(cdHash == nil ? "Yes" : "No")")
            NSLog("\(path) is Adhoc? \(isAdhocSigned.boolValue)")
            
            if let cdHash {
                NSLog("cdHash size: \(cdHash.count)")
                nonTrustedCDHashes.append(cdHash as Data)
            }
        }
        
        tcCheckBlock(path)
        let bestArch: UInt32 = UInt32(bestCandidate)
        machoEnumerateDependencies(machoFile, bestArch, path, tcCheckBlock)
        NSLog("nonTrustedCDHashes: \(nonTrustedCDHashes)")
//        FileManager.default.createFile(atPath: "/var/jb/basebin/template.tc", contents: nil)
        var template_data = try Data(contentsOf: URL(fileURLWithPath: "/var/jb/basebin/template.tc"))
        template_data.replaceSubrange(0x14..<0x18, with: Data([UInt8(nonTrustedCDHashes.count), 0, 0, 0]))
        for cdhash in nonTrustedCDHashes {
            template_data.append(cdhash)
            template_data.append(Data([0, 2]))
        }
        
        NSLog("template_data: \(template_data)")
        // tcload
        try tcload(data: template_data)
    }
    
    static func tcload(data: Data) throws {
        guard data.count >= 0x18 else {
            throw StringError("Trust cache is too small!")
        }
        
        let vers = data.getGeneric(type: UInt32.self)
        guard vers == 1 else {
            throw StringError(String(format: "Trust cache has bad version (must be 1, is %u)!", vers))
        }
        let count = data.getGeneric(type: UInt32.self, offset: 0x14)
        guard data.count == 0x18 + (Int(count) * 22) else {
            throw StringError(String(format: "Trust cache has bad length (should be %p, is %p)!", 0x18 + (Int(count) * 22), data.count))
        }
        
        let pmap_image4_trust_caches: UInt64 = 0xFFFFFFF009740D80
        var mem: UInt64 = jbd_dirty_kalloc(0x1000)
        if mem == 0 {
            throw StringError("Failed to allocate kernel memory for TrustCache: \(mem)")
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
        kckw64(us, mem+0x10)
        let data2 = data
        let sz = kwritebuf_remote(tc, data2.withUnsafeBytes { $0.baseAddress! }, data2.count)
        NSLog("kwritebuf_remote size: \(sz)")
        let pitc = pmap_image4_trust_caches + kernel_slide
        print("kernel_slide: \(kernel_slide), pitc: \(pitc)")
//        let cur = kread64(kfd, pitc)
        let cur = kckr64(virt: pitc)
        guard cur != 0 else {
            throw StringError("Failed to read TrustCache head!")
        }
        
//        kwrite64(kfd, next, cur)
//        kwrite64(kfd, pitc, mem)
        kckw64(virt: next, what: cur)
        kckw64(virt: pitc, what: mem)
        print("loaded trustcache")
    }
}

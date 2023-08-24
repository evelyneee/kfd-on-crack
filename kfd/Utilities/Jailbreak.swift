//
//  Jailbreak.swift
//  kfd
//
//  Created by Serena on 11/08/2023.
//

import Foundation
import SwiftMachO
import SwiftUtils
import PatchfinderUtils
import libjailbreak

class Jailbreak {
    static let shared = Jailbreak()
    
    private init() {} // For not accidentally creating any other instances
        
    // istantiate in _makeKPF(), so if user tries to rejb (if possible) they don't have to generate this again
    var isCurrentlyPostExploit: Bool = false
        
    func _makeKPF() throws -> KPF {
        
        // First: try to see if there is a *decompressed* kernel cache
        // by default, on an unjailbroken device, there isn't one
        // However after jailbreaking for the first time, it'll be there
        
        // (Note: the reason we use try? here is because we don't want these
        // to be thrown to the user,
        // because in the end we can just try fallback to `__makeKPFByDecompressingExistingKernelCache`)
        if let alreadyDecompressed = getKernelcacheDecompressedPath(),
           let data = try? Data(contentsOf: URL(fileURLWithPath: alreadyDecompressed).deletingLastPathComponent().appendingPathComponent("kernelcachd")),
           let macho = try? MachO(fromData: data, okToLoadFAT: false),
           let kpf = KPF(kernel: macho) {
            print("successfully loaded decompressed KernelPatch from existing!")
            return kpf
        }
        
        print("couldn't load from existing, exists: \(FileManager.default.fileExists(atPath: getKernelcacheDecompressedPath()!))")
        
        // Existing decompressed kcache doens't exist, so, try to decompress the existing one
        let k = try __makeKPFByDecompressingExistingKernelCache()
        return k
    }
    
    // make KPF by decompressing the existing, non-compressed kernel cache
    func __makeKPFByDecompressingExistingKernelCache() throws -> KPF {
        print("Calling upon \(#function)")
        
        // Get path of *compressed* kcache
        guard let kcachePath = getKernelcachePath() else {
            // To do: copy getKernelcachePath into our own module
            // so we can modify it to be throwing and throw our own error
            throw StringError("Failed to get kernel cache path (most definitely because IOKit throwed an error in doing so)")
        }
        
        // Decompress
        guard let decompressed = loadImg4Kernel(path: kcachePath) else {
            throw StringError("Failed to decompress kernelcache at \(kcachePath) (How?)")
        }
        
        if isCurrentlyPostExploit, let decompr = getKernelcacheDecompressedPath() {
            // Don't throw error back at user
            do {
                try decompressed.write(to: URL(fileURLWithPath: decompr))
                print("wrote data!")
            } catch {
                print("data couldn't be written: \(error)")
            }
        }
        
        let macho = try MachO(fromData: decompressed, okToLoadFAT: true)
        
        guard let kpf = KPF(kernel: macho) else {
            throw StringError("Failed to instantiate KernelPatchFinder from KPF(kernel:) ")
        }
        
        return kpf
    }
    
    // TODO: replace label w jailbreak name once decided
    let queue = DispatchQueue(label: "com.serena.evelynee.jailbreakqueue")
    
    lazy var kpf: KPF = {
        if let decomp = try? Data(contentsOf: NSURL.fileURL(withPath: String(Bundle.main.bundleURL.appendingPathComponent("kc.img4").absoluteString.dropFirst(7)))) {
            let macho = try! MachO(fromData: decomp, okToLoadFAT: false)
            print(macho)
            return KPF(kernel: macho)!
        } else {
            return try! _makeKPF()
        }
    }()
    
    func _startImpl(puaf_pages: UInt64, puaf_method: UInt64, kread_method: UInt64, kwrite_method: UInt64) throws {
        let kfd = kopen_intermediate(puaf_pages, puaf_method, kread_method, kwrite_method)
        
        print("stage2!"); sleep(1);
        stage2(kfd)
        
        print(String(format: "0x%02llX", Jailbreak.shared.kpf.mach_vm_allocate_kernel!))
        
        mach_vm_allocate_kernel_func = Jailbreak.shared.kpf.mach_vm_allocate_kernel!
        
        print("test");sleep(1);
        
        let allocated = kalloc(0x4000)
        
        print(String(format: "kalloc test: %02llX", allocated));
                        
        isCurrentlyPostExploit = true
        
        //set_csflags(kfd, kfd_struct(kfd).pointee.info.kernel.current_proc)
        
        //print("syscall filter ret:", set_syscallfilter(kfd, kfd_struct(kfd).pointee.info.kernel.current_proc))
        
        print("make patchfinder")
                        
        try Bootstrapper.remountPrebootPartition(writable: true)
        print(try Bootstrapper.locateExistingFakeRoot())
        
        #if false
        print(String(format: "%02X", kckr32(virt: kfd_struct(kfd).pointee.info.kernel.current_proc + 0x10)), String(format: "%02llX", kckr64(virt: kfd_struct(kfd).pointee.info.kernel.current_proc + 0x10))); sleep(1);
        
        let backup = kckr32(virt: kfd_struct(kfd).pointee.info.kernel.current_proc + 0xC0)
        kckw32(virt: kfd_struct(kfd).pointee.info.kernel.current_proc + 0xC0, what: 4141)
        let new = kckr32(virt: kfd_struct(kfd).pointee.info.kernel.current_proc + 0xC0)
        kckw32(virt: kfd_struct(kfd).pointee.info.kernel.current_proc + 0xC0, what: backup)
        
        print(String(format: "backup: %02llX new: %02llX", backup, new)); sleep(1);
        
        print("done testing");sleep(1);

        #endif
        
        //print(kalloc_data(0x4000))
        
        print("set csflags"); sleep(1);
        
        print("strapped")
        
        FileManager.default.createFile(atPath: "/var/jb/.installed_ellejb", contents: Data("By the Mryiad truths".utf8))
        print("created /var/jb/.installed_ellejb")
        //                            print(try FileManager.default.contentsOfDirectory(atPath: "/private/preboot/"))
        //                            print(try FileManager.default.contentsOfDirectory(atPath: "/var/jb/"))
        try? FileManager.default.createDirectory(atPath: "/var/jb/basebin/", withIntermediateDirectories: false)
        try? FileManager.default.removeItem(atPath: "/var/jb/basebin/jailbreakd")
        try? FileManager.default.removeItem(atPath: "/var/jb/basebin/jailbreakd.tc")
        
        print("here")
        
        try? FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/jailbreakd"), toPath: "/var/jb/basebin/jailbreakd")
        try? FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/testexec"), toPath: "/var/jb/basebin/testexec")
        
        chmod("/var/jb/basebin/jailbreakd", 777)
        chmod("/var/jb/basebin/testexec", 777)
        
        try FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/jailbreakd.tc"), toPath: "/var/jb/basebin/jailbreakd.tc")
        print(try FileManager.default.contentsOfDirectory(atPath: "/var/jb/basebin/"))
        
        //                        print("data_external:", self.kpf?.kalloc_data_external)
        
        let tcURL = NSURL.fileURL(withPath: "/var/jb/basebin/jailbreakd.tc")
        guard FileManager.default.fileExists(atPath: "/var/jb/basebin/jailbreakd.tc") else { return }
        let data = try Data(contentsOf: tcURL)
        
        guard let pmap_image4_trust_caches = kpf.pmap_image4_trust_caches else {
            throw StringError("Failed to find offset for pmap_image4_trust_caches...")
        }
        
        try tcload(data, kfd: kfd, pmap_image4_trust_caches: pmap_image4_trust_caches)
        
        guard FileManager.default.fileExists(atPath: "/var/jb/basebin/jailbreakd") else {
            print("no jailbreakd????????????")
            return;
        }
        
        let ourPrebootPath = prebootPath(nil)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: ourPrebootPath), withIntermediateDirectories: true)
        print(ourPrebootPath)
        
        let jbdPID = try initializeJBD(withKFD: kfd)
        
        //handoffKernRw(jbdExec.pid, ourPrebootPath.appending("/basebin/jailbreakd"))
        
        
        bootInfo_setObject("kernelslide", kfd_struct(kfd).pointee.info.kernel.kernel_slide as NSNumber)
        bootInfo_setObject("pmap_image4_trust_caches", pmap_image4_trust_caches as NSNumber)
        
        // BEGIN KALLOC TESTS
        #if false
        if let pageTest = kalloc_once() {
            print(pageTest); sleep(1);
            
            _kwrite64(kfd, pageTest, 0x4141)
            let read = _kread64(kfd, pageTest)
            
            print("read:", read)
            
            if read == 0x4141 {
                print("SUCCESS ON KALLOC")
            }
        } else {
            print("failed kalloc")
        }
        #endif
        
        // BEGIN KRW HANDOFF
                
        let jbdProc = proc_of_pid(kfd, jbdPID)
        let jbdTask = _kread64(kfd, jbdProc + 0x10)
        NSLog("jbd_proc: \(jbdProc)")
        
        let dict2 = xpc_dictionary_create_empty()!
        xpc_dictionary_set_int64(dict2, "id", JailbreakdMessageID.krwBegin.rawValue)
        
        if let replyDict = sendJBDMessage(dict2) {
            print(String(cString: xpc_copy_description(replyDict)))
            
            getRoot(kfd, jbdProc)
            
            let krw_port: mach_port_t = UInt32(xpc_dictionary_get_uint64(replyDict, "krw_port"))

            print("jbdPID", jbdPID, "port", krw_port)
            
            print("jbdTask:", String(format: "0x%02llX", jbdTask))
            
            if let br_x6 = kpf.br_x6 {
                kcall6_nox0_offset = br_x6
            } else {
                print("no br x6")
            }
            
            let kreadFakeClient = init_kcall_remote(kfd, jbdTask, krw_port)
            kcall6_nox0_raw_init(kreadFakeClient)
                        
            let readyDict = xpc_dictionary_create_empty()!
            xpc_dictionary_set_int64(readyDict, "id", JailbreakdMessageID.krwReady.rawValue)
            
            xpc_dictionary_set_uint64(readyDict, "slide", kernel_slide);
            xpc_dictionary_set_uint64(readyDict, "proc", current_proc);
            xpc_dictionary_set_uint64(readyDict, "jbd_task", jbdTask)
            xpc_dictionary_set_uint64(readyDict, "fake_client", kreadFakeClient);
            xpc_dictionary_set_uint64(readyDict, "mach_vm_allocate_kernel_func", mach_vm_allocate_kernel_func);
            xpc_dictionary_set_uint64(readyDict, "kalloc_scratchbuf", kalloc_scratchbuf)
            xpc_dictionary_set_uint64(readyDict, "kernelmap", kfd_struct(kfd).pointee.info.kernel.kernel_map)
            xpc_dictionary_set_uint64(readyDict, "ldr_w0_x2_x1", ldr_w0_x2_x1)
            xpc_dictionary_set_uint64(readyDict, "str_w1_x2", str_w1_x2)
            xpc_dictionary_set_uint64(readyDict, "kernel_proc", kfd_struct(kfd).pointee.info.kernel.kernel_proc)
            xpc_dictionary_set_uint64(readyDict, "jbd_proc", jbdProc)
            
            if let replyDict = sendJBDMessage(readyDict) {
                print(String(cString: xpc_copy_description(replyDict)))
            } else {
                print("replyDict returned nil.")
            }
            
        } else {
            print("replyDict returned nil.")
        }
        
        do {
            let prepareMsg = xpc_dictionary_create_empty()!
            xpc_dictionary_set_int64(prepareMsg, "id", JailbreakdMessageID.processBinary.rawValue)
            xpc_dictionary_set_string(prepareMsg, "filePath", "/var/jb/basebin/testexec")
            let reply = sendJBDMessage(prepareMsg)!
            
            if xpc_dictionary_get_bool(reply, "success") {
                print("jbd success!")
            } else {
                print("jbd failed!")
                print("jbd error, error: \(String(cString: xpc_dictionary_get_string(reply, "error")!))")
            }
            
            let (_, pid) = try execCmd(args: ["/var/jb/basebin/testexec"], waitPid: true)
            print("spawned pid: \(pid)")
        } catch {
            print("spawn error: \(error)")
        }
    }
    
    func initializeJBD(withKFD kfd: u64) throws -> pid_t {
        let jbdPath = "/var/jb/basebin/jailbreakd"
        let (result, pid) = try execCmd(args: [jbdPath], waitPid: false, root: false)
        sleep(2)
        
        print("spawned jbd, doing handoff!")
        
//        handoffKernRw(jbdExec.pid, prebootPath("/basebin/jailbreakd"))
        
        sleep(1)
        
        return pid
    }
    
    func start(puaf_pages: UInt64, puaf_method: UInt64, kread_method: UInt64, kwrite_method: UInt64) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) -> Void in
            queue.async { [self] in
                do {
                    try self._startImpl(puaf_pages: puaf_pages, puaf_method: puaf_method, kread_method: kread_method, kwrite_method: kwrite_method)
                    cont.resume(returning: ())
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    func tcload(_ data: Data, kfd: u64, pmap_image4_trust_caches: UInt64) throws {
        // Make sure the trust cache is good
        guard data.count >= 0x18 else {
            return print("Trust cache is too small!")
        }
        
        let vers = data.getGeneric(type: UInt32.self)
        guard vers == 1 else {
            return print(String(format: "Trust cache has bad version (must be 1, is %u)!", vers))
        }
        
        let count = data.getGeneric(type: UInt32.self, offset: 0x14)
        guard data.count == 0x18 + (Int(count) * 22) else {
            return print(String(format: "Trust cache has bad length (should be %p, is %p)!", 0x18 + (Int(count) * 22), data.count))
        }
        
        print("so far it's good", String(format: "%02llX", pmap_image4_trust_caches)) // 0xFFFFFFF0078718C0
        
        var mem: UInt64 = kalloc(0x4000)
        if mem == 0 {
            return print("Failed to allocate kernel memory for TrustCache: \(mem)")
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
        
        print("writing in us:", us)
        
        _kwrite64(kfd, us, mem+0x10)
        
        print("writing in tc:", tc)
        
        var data = data
        hexdump(data.withUnsafeMutableBytes { $0.baseAddress! }, UInt32(data.count))
        
        kwritebuf(kfd, tc, data.withUnsafeBytes { $0.baseAddress! }, data.count)
        
        let pitc = pmap_image4_trust_caches + kfd_struct(kfd).pointee.info.kernel.kernel_slide
        
        let cur = _kread64(kfd, pitc)
        
        print("cur:", cur)
        
        // Read head
        guard cur != 0 else {
            return print("Failed to read TrustCache head!"); sleep(1)
        }
        
        // Write into our list entry
        
        _kwrite64(kfd, next, cur)
        
        print("wrote in cur", cur)
        
        // Replace head
        _kwrite64(kfd, pitc, mem)
        
        print("Successfully loaded TrustCache!")
    }
    
    
    func tcload_empty(kfd: u64, patchFinder: KPF) throws -> UInt64 {
        // Make sure the trust cache is good
        
        let pmap_image4_trust_caches: UInt64 = patchFinder.pmap_image4_trust_caches!
        print("so far it's good", String(format: "%02llX", pmap_image4_trust_caches)) // 0xFFFFFFF0078718C0
        
        var mem: UInt64 = dirty_kalloc(kfd, 0x1000)
        if mem == 0 {
            print("Failed to allocate kernel memory for TrustCache: \(mem)")
            return 0
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
        
        print("writing in us:", us); sleep(1)
        
        _kwrite64(kfd, us, mem+0x10)
        
        print("writing in tc:", tc); sleep(1)
        
        _kwrite32(kfd, tc, 0x1); // version
        kwritebuf(kfd, tc + 0x4, "blackbathingsuit", "blackbathingsuit".count + 1)
        _kwrite32(kfd, tc + 0x14, 22 * 100) // full page of entries
        
        let pitc = pmap_image4_trust_caches + kfd_struct(kfd).pointee.info.kernel.kernel_slide
        
        let cur = _kread64(kfd, pitc)
        
        print("cur:", cur); sleep(1)
        
        // Read head
        guard cur != 0 else {
            print("Failed to read TrustCache head!"); sleep(1)
            return 0
        }
        
        // Write into our list entry
        
        _kwrite64(kfd, next, cur)
        
        print("wrote in cur", cur); sleep(1)
        
        // Replace head
        _kwrite64(kfd, pitc, mem)
        
        print("Successfully loaded TrustCache!")
        return tc + 0x18
    }
    
    
    func tcaddpath(_ tc: UInt64, _ url: URL, kfd: u64) -> UInt64 {
        
        var data: NSData? = nil
        var adhoc: ObjCBool = false
        
        evaluateSignature(url, &data, &adhoc)
        
        print(data?.bytes, adhoc)
        
        if let data {
            var entry = trust_cache_entry1()
            
            memcpy(&entry, data.bytes, data.count)
            entry.hash_type = 0x2
            entry.flags = 0
            
            print(entry, entry.cdhash)
            
            withUnsafeBytes(of: &entry, { buf in
                if let ptr = buf.baseAddress {
                    kwritebuf(kfd, tc, ptr, 22)
                }
            })
            
            return tc + UInt64(MemoryLayout<trust_cache_entry1>.size)
        }
        
        return tc
    }
    
    // posixSpawnStatus depends on the waitPid argument passed
    // if waitPid
    func execCmd(args: [String], fileActions: posix_spawn_file_actions_t? = nil, waitPid: Bool, root: Bool = true) throws -> (posixSpawnStatus: Int32, pid: pid_t) {
        //var fileActions = fileActions
        
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        if root {
            posix_spawnattr_set_persona_np(&attr, 99, 1)
            posix_spawnattr_set_persona_uid_np(&attr, 0)
            posix_spawnattr_set_persona_gid_np(&attr, 0)
        }
        
        var pid: pid_t = 0
        var argv: [UnsafeMutablePointer<CChar>?] = []
        for arg in args {
            argv.append(strdup(arg))
        }
        
        setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/private/preboot/jb/sbin:/private/preboot/jb/bin:/private/preboot/jb/usr/sbin:/private/preboot/jb/usr/bin", 1)
        setenv("TERM", "xterm-256color", 1)
        
        // Please stop printing this evelyn
        // print(ProcessInfo.processInfo.environment)
        
        argv.append(nil)
        
        print("POSIX SPAWN TIME"); sleep(1);
        
        let result = posix_spawn(&pid, argv[0], nil, nil, &argv, environ)
        guard result == 0 else {
            if let err = strerror(result) {
                print("err:", String(cString: strerror(result)))
            } else {
                print("no err")
            }
            throw StringError("Failed to posix_spawn with \(args) (Errno \(result))")
        }
        
        print("spawned"); sleep(1);
        
        var status: Int32 = 0
        if waitPid {
            waitpid(pid, &status, 0)
            return (status, pid)
        }
        
        return (result, pid)
    }
}

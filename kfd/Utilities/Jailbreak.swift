//
//  Jailbreak.swift
//  kfd
//
//  Created by Serena on 11/08/2023.
//

import Foundation
import SwiftMachO

class Jailbreak {
    static let shared = Jailbreak()
    
    private init() {} // For not accidentally creating any other instances
    
    lazy var kpf = {
        if let decomp = try? Data(contentsOf: NSURL.fileURL(withPath: String(Bundle.main.bundleURL.appendingPathComponent("kc.img4").absoluteString.dropFirst(7)))) {
            print("decomp is valid")
            let macho = try! MachO(fromData: decomp, okToLoadFAT: false)
            print(macho)
            return KPF(kernel: macho)
        }
        
        return nil
    }()
    
    // TODO: replace label w jailbreak name once decided
    let queue = DispatchQueue(label: "com.serena.evelynee.jailbreakqueue")
    
    func _startImpl(puaf_pages: UInt64, puaf_method: UInt64, kread_method: UInt64, kwrite_method: UInt64) throws {
        let kfd = kopen_intermediate(puaf_pages, puaf_method, kread_method, kwrite_method)
        
        print("stage2!")
        stage2(kfd)
        //postExploited = true
        
        //set_csflags(kfd, kfd_struct(kfd).pointee.info.kernel.current_proc)
        
        //print("syscall filter ret:", set_syscallfilter(kfd, kfd_struct(kfd).pointee.info.kernel.current_proc))
        
        print("set csflags"); sleep(1);
        
        try Bootstrapper.remountPrebootPartition(writable: true)
        
        print("strapped")
        
        FileManager.default.createFile(atPath: "/var/jb/.installed_ellejb", contents: Data())
        print("created /var/jb/.installed_ellejb")
        //                            print(try FileManager.default.contentsOfDirectory(atPath: "/private/preboot/"))
        //                            print(try FileManager.default.contentsOfDirectory(atPath: "/var/jb/"))
        try? FileManager.default.createDirectory(atPath: "/var/jb/basebin/", withIntermediateDirectories: false)
        try? FileManager.default.removeItem(atPath: "/var/jb/basebin/jailbreakd")
        try? FileManager.default.removeItem(atPath: "/var/jb/basebin/jailbreakd.tc")
        
        print("here")
        
        try? FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/jailbreakd"), toPath: "/var/jb/basebin/jailbreakd")
        
        chmod("/var/jb/basebin/jailbreakd", 777)
        
        try FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/jailbreakd.tc"), toPath: "/var/jb/basebin/jailbreakd.tc")
        print(try FileManager.default.contentsOfDirectory(atPath: "/var/jb/basebin/"))
        
        //                        print("data_external:", self.kpf?.kalloc_data_external)
        
        let tcURL = NSURL.fileURL(withPath: "/var/jb/basebin/jailbreakd.tc")
        guard FileManager.default.fileExists(atPath: "/var/jb/basebin/jailbreakd.tc") else { return }
        let data = try! Data(contentsOf: tcURL)
        try! tcload(data, kfd: kfd)
        
        guard FileManager.default.fileExists(atPath: "/var/jb/basebin/jailbreakd") else {
            print("no jailbreakd????????????")
            return;
        }
        
        print("jbd execCmd: ", execCmd(args: ["/var/jb/basebin/jailbreakd"], kfd: kfd))
    }
    
    func start(puaf_pages: UInt64, puaf_method: UInt64, kread_method: UInt64, kwrite_method: UInt64) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) -> Void in
            self.queue.async { [self] in
                do {
                    try self._startImpl(puaf_pages: puaf_pages, puaf_method: puaf_method, kread_method: kread_method, kwrite_method: kwrite_method)
                    cont.resume(returning: ())
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    func tcload(_ data: Data, kfd: u64) throws {
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
        
        let pmap_image4_trust_caches: UInt64 = self.kpf!.pmap_image4_trust_caches!
        print("so far it's good", String(format: "%02llX", pmap_image4_trust_caches)) // 0xFFFFFFF0078718C0
        
        var mem: UInt64 = dirty_kalloc(kfd, 1024)
        if mem == 0 {
            return print("Failed to allocate kernel memory for TrustCache: \(mem)")
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
        
        print("writing in us:", us); sleep(1)
        
        kwrite64(kfd, us, mem+0x10)
        
        print("writing in tc:", tc); sleep(1)
        
        var data = data
        hexdump(data.withUnsafeMutableBytes { $0.baseAddress! }, UInt32(data.count))
        
        kwritebuf(kfd, tc, data.withUnsafeBytes { $0.baseAddress! }, data.count)
        
        let pitc = pmap_image4_trust_caches + kfd_struct(kfd).pointee.info.kernel.kernel_slide
        
        let cur = kread64(kfd, pitc)
        
        print("cur:", cur); sleep(1)
        
        // Read head
        guard cur != 0 else {
            return print("Failed to read TrustCache head!"); sleep(1)
        }
        
        // Write into our list entry
        
        kwrite64(kfd, next, cur)
        
        print("wrote in cur", cur); sleep(1)
        
        // Replace head
        kwrite64(kfd, pitc, mem)
        
        print("Successfully loaded TrustCache!")
        
    }
    
    
    func tcload_empty(kfd: u64) throws -> UInt64 {
        // Make sure the trust cache is good
        
        let pmap_image4_trust_caches: UInt64 = self.kpf!.pmap_image4_trust_caches!
        print("so far it's good", String(format: "%02llX", pmap_image4_trust_caches)) // 0xFFFFFFF0078718C0
        
        print(String(format: "%02llX", kalloc(kfd, 0x4000)))
        print(String(format: "%02llX", kalloc(kfd, 0x4000)))
        print(String(format: "%02llX", kalloc(kfd, 0x4000)))
        var mem: UInt64 = dirty_kalloc(kfd, 0x1000)
        if mem == 0 {
            print("Failed to allocate kernel memory for TrustCache: \(mem)")
            return 0
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
        
        print("writing in us:", us); sleep(1)
        
        kwrite64(kfd, us, mem+0x10)
        
        print("writing in tc:", tc); sleep(1)
        
        kwrite32(kfd, tc, 0x1); // version
        kwritebuf(kfd, tc + 0x4, "blackbathingsuit", "blackbathingsuit".count + 1)
        kwrite32(kfd, tc + 0x14, 22 * 100) // full page of entries
        
        let pitc = pmap_image4_trust_caches + kfd_struct(kfd).pointee.info.kernel.kernel_slide
        
        let cur = kread64(kfd, pitc)
        
        print("cur:", cur); sleep(1)
        
        // Read head
        guard cur != 0 else {
            print("Failed to read TrustCache head!"); sleep(1)
            return 0
        }
        
        // Write into our list entry
        
        kwrite64(kfd, next, cur)
        
        print("wrote in cur", cur); sleep(1)
        
        // Replace head
        kwrite64(kfd, pitc, mem)
        
        print("Successfully loaded TrustCache!")
        return tc + 0x18
    }
    
    
    func tcaddpath(_ tc: UInt64, _ url: URL, kfd: u64) -> UInt64 {
        
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
}

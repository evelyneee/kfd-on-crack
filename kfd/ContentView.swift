/*
 * Copyright (c) 2023 Félix Poulin-Bélanger. All rights reserved.
 */

import SwiftUI
import KernelPatchfinder
import SwiftMachO
import PatchfinderUtils

struct ContentView: View {
    @State private var kfd: UInt64 = 0

    private var puaf_pages_options = [16, 32, 64, 128, 256, 512, 1024, 2048]
    @State private var puaf_pages_index = 7
    @State private var puaf_pages = 0

    private var puaf_method_options = ["physpuppet", "smith"]
    @State private var puaf_method = 1

    private var kread_method_options = ["kqueue_workloop_ctl", "sem_open", "IOSurface"]
    @State private var kread_method = 2

    private var kwrite_method_options = ["dup", "sem_open", "IOSurface"]
    @State private var kwrite_method = 2

    @State var postExploited = false
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(selection: $puaf_pages_index, label: Text("puaf pages:")) {
                        ForEach(0 ..< puaf_pages_options.count, id: \.self) {
                            Text(String(self.puaf_pages_options[$0]))
                        }
                    }.disabled(kfd != 0)
                }
                Section {
                    Picker(selection: $puaf_method, label: Text("puaf method:")) {
                        ForEach(0 ..< puaf_method_options.count, id: \.self) {
                            Text(self.puaf_method_options[$0])
                        }
                    }.disabled(kfd != 0)
                }
                Section {
                    Picker(selection: $kread_method, label: Text("kread method:")) {
                        ForEach(0 ..< kread_method_options.count, id: \.self) {
                            Text(self.kread_method_options[$0])
                        }
                    }.disabled(kfd != 0)
                }
                Section {
                    Picker(selection: $kwrite_method, label: Text("kwrite method:")) {
                        ForEach(0 ..< kwrite_method_options.count, id: \.self) {
                            Text(self.kwrite_method_options[$0])
                        }
                    }.disabled(kfd != 0)
                }
                HStack {
                    Button("kopen") {
                        puaf_pages = puaf_pages_options[puaf_pages_index]
                        kfd = kopen_intermediate(UInt64(puaf_pages), UInt64(puaf_method), UInt64(kread_method), UInt64(kwrite_method))
                    }.disabled(kfd != 0).frame(minWidth: 0, maxWidth: .infinity)
                    Button("kclose") {
                        kclose_intermediate(kfd)
                        puaf_pages = 0
                        kfd = 0
                    }.disabled(kfd == 0).frame(minWidth: 0, maxWidth: .infinity)
                }
                if kfd != 0 {
                    Section {
                        VStack {
                            Text("Success!").foregroundColor(.green)
                            Text("Look at output in Xcode")
                        }.frame(minWidth: 0, maxWidth: .infinity)
                    }.listRowBackground(Color.clear)
                }
                Section {
                    HStack {
                        Button("stage2") {
                            stage2(kfd)
                            postExploited = true
                            
                            //set_csflags(kfd, kfd_struct(kfd).pointee.info.kernel.current_proc)
                            
                            //print("syscall filter ret:", set_syscallfilter(kfd, kfd_struct(kfd).pointee.info.kernel.current_proc))
                            
                            print("set csflags");sleep(1);
                            
                            execCmd(args: ["/bin/ps", "aux"], kfd: kfd)
                                                                                  
                            do {
                                try Bootstrapper.extractBootstrap()
                                
                                print("strapped"); sleep(1);
                                
                                try? FileManager.default.createFile(atPath: "/var/jb/.installed_ellejb", contents: Data())
                                print(try FileManager.default.contentsOfDirectory(atPath: "/private/preboot/"))
                                print(try FileManager.default.contentsOfDirectory(atPath: "/var/jb/"))
                                try? FileManager.default.createDirectory(atPath: "/var/jb/basebin/", withIntermediateDirectories: false)
                                try? FileManager.default.removeItem(atPath: "/var/jb/basebin/jailbreakd")
                                try? FileManager.default.removeItem(atPath: "/var/jb/basebin/jailbreakd.tc")

                                try? FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/jailbreakd"), toPath: "/var/jb/basebin/jailbreakd")
                                
                                chmod("/var/jb/basebin/jailbreakd", 777)
                                
                                try FileManager.default.copyItem(atPath: Bundle.main.bundlePath.appending("/jailbreakd.tc"), toPath: "/var/jb/basebin/jailbreakd.tc")
                                print(try FileManager.default.contentsOfDirectory(atPath: "/var/jb/basebin/"))
                            } catch {
                                print(error)
                            }
                            
                        }.disabled(kfd == 0 || postExploited).frame(minWidth: 0, maxWidth: .infinity)
                        Button("load tc") {
                            
                            print(self.kpf?.kalloc_data_external)
                            
                            kalloc_data_extern = self.kpf?.kalloc_data_external ?? 0

                            let tcURL = NSURL.fileURL(withPath: "/var/jb/basebin/jailbreakd.tc")
                            guard FileManager.default.fileExists(atPath: "/var/jb/basebin/jailbreakd.tc") else { return }

                            if let emptyTC = try? tcload_empty() {
                                self.trustcachePointer = emptyTC
                                
                                self.trustcachePointer = tcaddpath(emptyTC, tcURL)
                                
                                self.trustcachePointer = tcaddpath(emptyTC, NSURL.fileURL(withPath: "/var/jb/usr/bin/uicache"))
                                
                                execCmd(args: ["/var/jb/usr/bin/uicache", "-p", "/var/jb/Applications/Sileo.app"], kfd: kfd)
                                
                                print("added tc")
                            }
                            
                            guard FileManager.default.fileExists(atPath: "/var/jb/basebin/jailbreakd") else {
                                print("no jailbreakd????????????")
                                return;
                            }

                            print(execCmd(args: ["/var/jb/basebin/jailbreakd"], kfd: kfd))
                            
                        }.disabled(kfd == 0 || !postExploited).frame(minWidth: 0, maxWidth: .infinity)
                    }
                }.listRowBackground(Color.clear)
            }
        }
        .onAppear {
            if let decomp = try? Data(contentsOf: NSURL.fileURL(withPath: String(Bundle.main.bundleURL.appendingPathComponent("kc.img4").absoluteString.dropFirst(7)))) {
                let macho = try! MachO(fromData: decomp, okToLoadFAT: false)
                print(macho)
                let kpf = KPF(kernel: macho)
                
                print(kpf?.pmap_image4_trust_caches)
                
                self.kpf = kpf
                
            } else {
                print("Fail")
            }
        }
    }
    
    @State
    var kpf = KPF.running
    
    @State var trustcachePointer: UInt64 = 0
        
    func tcaddpath(_ tc: UInt64, _ url: URL) -> UInt64 {
            
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
    
    // Returns a page for cdhashes
    func tcload_empty() throws -> UInt64 {
        // Make sure the trust cache is good
        
        let pmap_image4_trust_caches: UInt64 = self.kpf!.pmap_image4_trust_caches!
        print("so far it's good", String(format: "%02llX", pmap_image4_trust_caches)) // 0xFFFFFFF0078718C0
        
        print(String(format: "%02llX", kalloc(kfd, 0x4000)))
        print(String(format: "%02llX", kalloc(kfd, 0x4000)))
        print(String(format: "%02llX", kalloc(kfd, 0x4000)))
        var mem: UInt64 = dirty_kalloc(self.kfd, 0x1000)
        if mem == 0 {
            print("Failed to allocate kernel memory for TrustCache: \(mem)")
            return 0
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
                
        print("writing in us:", us); sleep(1)
        
        kwrite64(self.kfd, us, mem+0x10)
        
        print("writing in tc:", tc); sleep(1)
        
        kwrite32(kfd, tc, 0x1); // version
        kwritebuf(kfd, tc + 0x4, "blackbathingsuit", "blackbathingsuit".count + 1)
        kwrite32(kfd, tc + 0x14, 22 * 100) // full page of entries
                
        let pitc = pmap_image4_trust_caches + kfd_struct(self.kfd).pointee.info.kernel.kernel_slide
        
        let cur = kread64(self.kfd, pitc)
        
        print("cur:", cur); sleep(1)
        
        // Read head
        guard cur != 0 else {
            print("Failed to read TrustCache head!"); sleep(1)
            return 0
        }
        
        // Write into our list entry
        
        kwrite64(self.kfd, next, cur)
        
        print("wrote in cur", cur); sleep(1)
        
        // Replace head
        kwrite64(self.kfd, pitc, mem)
        
        print("Successfully loaded TrustCache!")
        return tc + 0x18
    }

    
    func tcload(_ data: Data) throws {
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
        
        var mem: UInt64 = dirty_kalloc(self.kfd, 1024)
        if mem == 0 {
            return print("Failed to allocate kernel memory for TrustCache: \(mem)")
        }
        
        let next = mem
        let us   = mem + 0x8
        let tc   = mem + 0x10
                
        print("writing in us:", us); sleep(1)
        
        kwrite64(self.kfd, us, mem+0x10)
        
        print("writing in tc:", tc); sleep(1)
        
        var data = data
        hexdump(data.withUnsafeMutableBytes { $0.baseAddress! }, UInt32(data.count))
        
        kwritebuf(self.kfd, tc, data.withUnsafeBytes { $0.baseAddress! }, data.count)
        
        let pitc = pmap_image4_trust_caches + kfd_struct(self.kfd).pointee.info.kernel.kernel_slide
        
        let cur = kread64(self.kfd, pitc)
        
        print("cur:", cur); sleep(1)
        
        // Read head
        guard cur != 0 else {
            return print("Failed to read TrustCache head!"); sleep(1)
        }
        
        // Write into our list entry
        
        kwrite64(self.kfd, next, cur)
        
        print("wrote in cur", cur); sleep(1)
        
        // Replace head
        kwrite64(self.kfd, pitc, mem)
        
        print("Successfully loaded TrustCache!")
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

func execCmd(args: [String], fileActions: posix_spawn_file_actions_t? = nil, kfd: UInt64) -> Int32? {
    var fileActions = fileActions
    
    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    posix_spawnattr_set_persona_np(&attr, 99, 1)
    posix_spawnattr_set_persona_uid_np(&attr, 0)
    posix_spawnattr_set_persona_gid_np(&attr, 0)
    
    var pid: pid_t = 0
    var argv: [UnsafeMutablePointer<CChar>?] = []
    for arg in args {
        argv.append(strdup(arg))
    }
    
    setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/private/preboot/jb/sbin:/private/preboot/jb/bin:/private/preboot/jb/usr/sbin:/private/preboot/jb/usr/bin", 1)
    setenv("TERM", "xterm-256color", 1)
    
    print(ProcessInfo.processInfo.environment)
    
    argv.append(nil)
    
    print("POSIX SPAWN TIME"); sleep(1);
    
    let result = posix_spawn(&pid, argv[0], nil, nil, &argv, environ)
    let err = errno
    guard result == 0 else {
        NSLog("Failed")
        NSLog("Error: \(result) Errno: \(err), strerr: \(String(cString: strerror(errno)))")
        
        return nil
    }
    
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    
    return status
}

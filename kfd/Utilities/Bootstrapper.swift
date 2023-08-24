import PatchfinderUtils;

public enum BootstrapError: Error {
    case custom(_: String)
}


public class Bootstrapper {
    static func _remountPrebootPartition(writable: Bool) -> Int32? {
        print("mounting"); sleep(1);
        return mount_check("/private/preboot/")
    }
    
    static func remountPrebootPartition(writable: Bool) throws {
        let returnValue = _remountPrebootPartition(writable: writable)
        guard returnValue == 0 else {
            throw BootstrapError.custom("Failed to remount preboot partition (/private/preboot)")
        }
    }
    
    static func zstdDecompress(zstdPath: String, targetTarPath: String) -> Int32 {
        return decompress_tar_zstd(zstdPath, targetTarPath)
    }
    
    static func untar(tarPath: String, target: String) throws -> Int32? {
        let tarBinary = Bundle.main.bundlePath + "/tar"
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tarBinary)
        return try Jailbreak.shared.execCmd(args: [tarBinary, "-xpkf", tarPath, "-C", target], waitPid: true).posixSpawnStatus;
    }
    
    static func getBootManifestHash() -> String? {
        let registryEntry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/chosen")
        if registryEntry == MACH_PORT_NULL {
            return nil
        }
        guard let bootManifestHash = IORegistryEntryCreateCFProperty(registryEntry, "boot-manifest-hash" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        guard let bootManifestHashData = bootManifestHash.takeRetainedValue() as? Data else {
            return nil
        }
        return bootManifestHashData.map { String(format: "%02X", $0) }.joined()
    }
    
    static func generateFakeRootPath() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var result = ""
        for _ in 0..<6 {
            let randomIndex = Int(arc4random_uniform(UInt32(letters.count)))
            let randomCharacter = letters[letters.index(letters.startIndex, offsetBy: randomIndex)]
            result += String(randomCharacter)
        }
        return "/private/preboot/" + getBootManifestHash()! + "/jb-" + result
    }
    
    static func UUIDPathPermissionFixup() throws {
        let UUIDPath = "/private/preboot/" + getBootManifestHash()!
        
        var UUIDPathStat = stat()
        if stat(UUIDPath, &UUIDPathStat) != 0 {
            throw BootstrapError.custom("Failed to stat \(UUIDPath): (\(String(cString: strerror(errno))))")
        }
        
        let curOwnerID = UUIDPathStat.st_uid
        let curGroupID = UUIDPathStat.st_gid
        if curOwnerID != 0 || curGroupID != 0 {
            if chown(UUIDPath, 0, 0) != 0 {
                throw BootstrapError.custom("Failed to chown 0:0 \(UUIDPath): (\(String(cString: strerror(errno))))")
            }
        }
        
        let curPermissions = UUIDPathStat.st_mode & S_IRWXU
        if curPermissions != 0o755 {
            if chmod(UUIDPath, 0o755) != 0 {
                throw BootstrapError.custom("Failed to chmod 755 \(UUIDPath): (\(String(cString: strerror(errno))))")
            }
        }
    }
    
    public static func locateExistingFakeRoot() -> String? {
        guard let bootManifestHash = getBootManifestHash() else {
            return nil
        }
        let ppURL = URL(fileURLWithPath: "/private/preboot/" + bootManifestHash)
        guard let candidateURLs = try? FileManager.default.contentsOfDirectory(at: ppURL , includingPropertiesForKeys: nil, options: []) else { return nil }
        
        for candidateURL in candidateURLs {
            if candidateURL.lastPathComponent.hasPrefix("jb-") {
                return candidateURL.path
            }
        }
        return nil
    }
    
    public static func locateOrCreateFakeRoot() throws -> String {
        if let fakeRootPath = locateExistingFakeRoot() {
            return fakeRootPath
        }
        
        
        let generated = generateFakeRootPath()
        try FileManager.default.createDirectory(atPath: generated, withIntermediateDirectories: true)
        return generated
    }
    
    static func wipeSymlink(atPath path: String) {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let fileType = attributes[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                try fileManager.removeItem(atPath: path)
                print("Deleted symlink at \(path)")
            } else {
                //Logger.print("Wanted to delete symlink at \(path), but it is not a symlink")
            }
        } catch _ {
            //Logger.print("Wanted to delete symlink at \(path), error occured: \(error), but we ignore it")
        }
    }
    
    static func fileOrSymlinkExists(atPath path: String) -> Bool {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            return true
        }
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let fileType = attributes[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                return true
            }
        } catch _ { }
        
        return false
    }
    
    static func createSymbolicLink(atPath path: String, withDestinationPath pathContent: String) throws {
        let components = path.split(separator: "/")
        let directoryPath = components.dropLast(1).map(String.init).joined(separator: "/")
        if !FileManager.default.fileExists(atPath: directoryPath) {
            try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        }
        try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: pathContent)
    }
    
    static func extractBootstrap() throws {
        let jbPath = "/var/jb"
        
        try remountPrebootPartition(writable: true)
        
        try UUIDPathPermissionFixup()
        
        // Remove existing /var/jb symlink if it exists (will be recreated later)
        wipeSymlink(atPath: jbPath)
        if FileManager.default.fileExists(atPath: jbPath) {
            try FileManager.default.removeItem(atPath: jbPath)
        }
        
        // Xina has never been available on arm64
#if false
        // If xina was used before, clean the mess it creates in /var
        // Xina will recreate them on the next jb through it so there is no loss here
        let xinaLeftoverSymlinks = [
            "/var/alternatives",
            "/var/ap",
            "/var/apt",
            "/var/bin",
            "/var/bzip2",
            "/var/cache",
            "/var/dpkg",
            "/var/etc",
            "/var/gzip",
            "/var/lib",
            "/var/Lib",
            "/var/libexec",
            "/var/Library",
            "/var/LIY",
            "/var/Liy",
            "/var/local",
            "/var/newuser",
            "/var/profile",
            "/var/sbin",
            "/var/suid_profile",
            "/var/sh",
            "/var/sy",
            "/var/share",
            "/var/ssh",
            "/var/sudo_logsrvd.conf",
            "/var/suid_profile",
            "/var/sy",
            "/var/usr",
            "/var/zlogin",
            "/var/zlogout",
            "/var/zprofile",
            "/var/zshenv",
            "/var/zshrc",
            "/var/log/dpkg",
            "/var/log/apt"
        ]
        let xinaLeftoverFiles = [
            "/var/lib", //sometimes is a symlink, sometimes is not(?)
            "/var/master.passwd"
        ]
        
        if !FileManager.default.fileExists(atPath: "/var/.keep_symlinks") {
            for xinaLeftoverSymlink in xinaLeftoverSymlinks {
                wipeSymlink(atPath: xinaLeftoverSymlink)
            }
            for xinaLeftoverFile in xinaLeftoverFiles {
                if FileManager.default.fileExists(atPath: xinaLeftoverFile) {
                    try FileManager.default.removeItem(atPath: xinaLeftoverFile)
                }
            }
        }
        
        #endif
        
        // Ensure fake root directory inside /private/preboot exists
        let fakeRootPath = try locateOrCreateFakeRoot()
        
        // Extract Procursus Bootstrap if neccessary
        var bootstrapNeedsExtract = false
        let procursusPath = fakeRootPath + "/procursus"
        let installedPath = procursusPath + "/.installed_ellejb"
//        let prereleasePath = procursusPath + "/.used_dopamine_prerelease"
        
        if FileManager.default.fileExists(atPath: procursusPath) {
            if !FileManager.default.fileExists(atPath: installedPath) {
                print("Wiping existing bootstrap because installed file not found")
                try FileManager.default.removeItem(atPath: procursusPath)
            }
            
//            if FileManager.default.fileExists(atPath: prereleasePath) {
//                Logger.shared.log("Wiping existing bootstrap because pre release")
//                try FileManager.default.removeItem(atPath: procursusPath)
//            }
        }
        
        if !FileManager.default.fileExists(atPath: procursusPath) {
            try FileManager.default.createDirectory(atPath: procursusPath, withIntermediateDirectories: true)
            bootstrapNeedsExtract = true
        }
        
        #if false
        // Update basebin (should be done every rejailbreak)
        let basebinTarPath = Bundle.main.bundlePath + "/basebin.tar"
        let basebinPath = procursusPath + "/basebin"
        if FileManager.default.fileExists(atPath: basebinPath) {
            try FileManager.default.removeItem(atPath: basebinPath)
        }
        
        let untarRet = try untar(tarPath: basebinTarPath, target: procursusPath)
        if untarRet != 0 {
            throw BootstrapError.custom(String(format:"Failed to untar Basebin: \(String(describing: untarRet))"))
        }
        #endif
        
        // Create /var/jb symlink
        try createSymbolicLink(atPath: jbPath, withDestinationPath: procursusPath)
        
        // Extract Procursus if needed
        if bootstrapNeedsExtract {
            let bootstrapZstdPath = Bundle.main.bundlePath + "/bootstrap-iphoneos-arm64.tar.zst"
            let bootstrapTmpTarPath = "/var/tmp/" + "/bootstrap-iphoneos-arm64.tar"
            if FileManager.default.fileExists(atPath: bootstrapTmpTarPath) {
                try FileManager.default.removeItem(atPath: bootstrapTmpTarPath);
            }
            let zstdRet = zstdDecompress(zstdPath: bootstrapZstdPath, targetTarPath: bootstrapTmpTarPath)
            if zstdRet != 0 {
                throw BootstrapError.custom(String(format:"Failed to decompress bootstrap: \(String(describing: zstdRet))"))
            }
            
            let untarRet = try untar(tarPath: bootstrapTmpTarPath, target: "/")
            try FileManager.default.removeItem(atPath: bootstrapTmpTarPath);
            if untarRet != 0 {
                throw BootstrapError.custom(String(format:"Failed to untar bootstrap: \(String(describing: untarRet))"))
            }
            
            try "".write(toFile: installedPath, atomically: true, encoding: String.Encoding.utf8)
        }
        
        // Update default sources
        let defaultSources = """
            Types: deb
            URIs: https://repo.chariz.com/
            Suites: ./
            Components:
            
            Types: deb
            URIs: https://havoc.app/
            Suites: ./
            Components:
            
            Types: deb
            URIs: http://apt.thebigboss.org/repofiles/cydia/
            Suites: stable
            Components: main
            
            Types: deb
            URIs: https://ellekit.space/
            Suites: ./
            Components:
            """
        try defaultSources.write(toFile: "/var/jb/etc/apt/sources.list.d/default.sources", atomically: false, encoding: .utf8)
        
        // Create basebin symlinks if they don't exist
        if !fileOrSymlinkExists(atPath: "/var/jb/usr/bin/opainject") {
            try createSymbolicLink(atPath: "/var/jb/usr/bin/opainject", withDestinationPath: procursusPath + "/basebin/opainject")
        }
        if !fileOrSymlinkExists(atPath: "/var/jb/usr/bin/jbctl") {
            try createSymbolicLink(atPath: "/var/jb/usr/bin/jbctl", withDestinationPath: procursusPath + "/basebin/jbctl")
        }
        if !fileOrSymlinkExists(atPath: "/var/jb/usr/lib/libjailbreak.dylib") {
            try createSymbolicLink(atPath: "/var/jb/usr/lib/libjailbreak.dylib", withDestinationPath: procursusPath + "/basebin/libjailbreak.dylib")
        }
        if !fileOrSymlinkExists(atPath: "/var/jb/usr/lib/libfilecom.dylib") {
            try createSymbolicLink(atPath: "/var/jb/usr/lib/libfilecom.dylib", withDestinationPath: procursusPath + "/basebin/libfilecom.dylib")
        }
        
        // Create preferences directory if it does not exist
        if !FileManager.default.fileExists(atPath: "/var/jb/var/mobile/Library/Preferences") {
            let attributes: [FileAttributeKey: Any] = [
                .posixPermissions: 0o755,
                .ownerAccountID: 501,
                .groupOwnerAccountID: 501
            ]
            try FileManager.default.createDirectory(atPath: "/var/jb/var/mobile/Library/Preferences", withIntermediateDirectories: true, attributes: attributes)
        }
        
        // Write boot info from cache to disk
        let bootInfoURL = URL(fileURLWithPath: "/var/jb/basebin/boot_info.plist")
        //try? cachedBootInfo.write(to: bootInfoURL)
    }
    
    static func needsFinalize() -> Bool {
        return FileManager.default.fileExists(atPath: "/var/jb/prep_bootstrap.sh")
    }
    
    static let appDefaults: UserDefaults = {
#warning("Replace the last part of the bundle ID once we decide on a name")
        let appDefaults = String(cString: getenv("HOME")) + "/Library/Preferences/com.serena.kfdJb.plist"
        let def = UserDefaults.init(suiteName: appDefaults)!
        
        /*
         def!.register(defaults: [
         "tweakInjectionEnabled": true,
         */
        return def
    }()
    
    static func finalizeBootstrap() throws {
        let prepRet = try Jailbreak.shared.execCmd(args: ["/var/jb/bin/sh", "/var/jb/prep_bootstrap.sh"], waitPid: true).posixSpawnStatus
        
        if prepRet != 0 {
            throw BootstrapError.custom(String(format:"Failed to finalize bootstrap, prep_bootstrap.sh failed with error code: \(prepRet)"))
        }
        
        let jbdkrwRet = try Jailbreak.shared.execCmd(args: ["/var/jb/usr/bin/dpkg", "-i", Bundle.main.bundlePath + "/libjbdrw.deb"], waitPid: true).posixSpawnStatus
        
        if jbdkrwRet != 0 {
            throw BootstrapError.custom(String(format:"Failed to finalize bootstrap, installing libjbdrw failed with error code: \(jbdkrwRet)"))
        }
        
        let selectedPackageManagers = appDefaults.stringArray(forKey: "selectedPackageManagers") ?? []
        let shouldInstallSileo = selectedPackageManagers.contains("Sileo")
        let shouldInstallZebra = selectedPackageManagers.contains("Zebra")
        
        if shouldInstallSileo {
            let sileoRet = try Jailbreak.shared.execCmd(args: ["/var/jb/usr/bin/dpkg", "-i", Bundle.main.bundlePath + "/sileo.deb"], waitPid: true).posixSpawnStatus
            if sileoRet != 0 {
                throw BootstrapError.custom(String(format:"Failed to finalize bootstrap, installing Sileo failed with error code: \(sileoRet)"))
            }
            _ = try Jailbreak.shared.execCmd(args: ["/var/jb/usr/bin/uicache", "-u", "/var/jb/Applications/Sileo.app"], waitPid: true)
        }
        
        if shouldInstallZebra {
            let zebraRet = try Jailbreak.shared.execCmd(args: ["/var/jb/usr/bin/dpkg", "-i", Bundle.main.bundlePath + "/zebra.deb"], waitPid: true).posixSpawnStatus
            if zebraRet != 0 {
                throw BootstrapError.custom(String(format:"Failed to finalize bootstrap, installing Zebra failed with error code: \(zebraRet)"))
            }
            _ = try Jailbreak.shared.execCmd(args: ["/var/jb/usr/bin/uicache", "-u", "/var/jb/Applications/Zebra.app"], waitPid: true)
        }
    }
    
    static func hideBootstrap() {
        // Remove existing /var/jb symlink if it exists (will be recreated on next jb)
        // This is the only thing that apps could detect when the device is not actually jailbroken
        // Except for apps that check for random preferences and shit on /var (something no app should ever do because of way to many false positives, feel free to send this comment to your manager)
        wipeSymlink(atPath: "/var/jb")
    }
    
    static func unhideBootstrap() {
        let jbPath = "/var/jb"
        let fakeRootPath = locateExistingFakeRoot()
        if fakeRootPath != nil {
            let procursusPath = fakeRootPath! + "/procursus"
            try? createSymbolicLink(atPath: jbPath, withDestinationPath: procursusPath)
        }
    }
    
    static func uninstallBootstrap() throws {
        let jbPath = "/var/jb"
        
        try remountPrebootPartition(writable: true)
//        if remountPrebootPartition(writable: true) != 0 {
//            Logger.print("Failed to remount /private/preboot partition as writable")
//            return
//        }
        
        // Delete /var/jb symlink
        wipeSymlink(atPath: jbPath)
        
        // Delete fake root
        let fakeRootPath = locateExistingFakeRoot()
        if fakeRootPath != nil {
            do {
                try FileManager.default.removeItem(atPath: fakeRootPath!)
            }
            catch let error as NSError {
                print("Failed to delete fake root: \(error)")
                return
            }
        }
        
        try remountPrebootPartition(writable: false)
//
//        if remountPrebootPartition(writable: false) != 0 {
//            Logger.shared.log("Failed to remount /private/preboot partition as non-writable")
//            return
//        }
    }
    
    public static func isBootstrapped() -> Bool {
        guard let fakeRoot = locateExistingFakeRoot() else {
            return false
        }
        return FileManager.default.fileExists(atPath: fakeRoot + "/procursus/.installed_dopamine")
    }
}

//
//  utils.m
//  libjailbreak
//
//  Created by Serena on 20/08/2023.
//  

#import <Foundation/Foundation.h>
#import "jb_utils.h"
#include "IOKit.h"

NSString *prebootPath(NSString *path) {
    static NSString *sPrebootPrefix = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once (&onceToken, ^{
        NSMutableString* bootManifestHashStr;
        io_registry_entry_t registryEntry = IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/chosen");
        if (registryEntry) {
            CFDataRef bootManifestHash = (CFDataRef)IORegistryEntryCreateCFProperty(registryEntry, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);
            if (bootManifestHash) {
                const UInt8* buffer = CFDataGetBytePtr(bootManifestHash);
                bootManifestHashStr = [NSMutableString stringWithCapacity:(CFDataGetLength(bootManifestHash) * 2)];
                for (CFIndex i = 0; i < CFDataGetLength(bootManifestHash); i++) {
                    [bootManifestHashStr appendFormat:@"%02X", buffer[i]];
                }
                CFRelease(bootManifestHash);
            }
        }

        if (bootManifestHashStr) {
            NSString *activePrebootPath = [@"/private/preboot/" stringByAppendingPathComponent:bootManifestHashStr];
            NSArray *subItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:activePrebootPath error:nil];
            for (NSString *subItem in subItems) {
                if ([subItem hasPrefix:@"jb-"]) {
                    sPrebootPrefix = [[activePrebootPath stringByAppendingPathComponent:subItem] stringByAppendingPathComponent:@"procursus"];
                    break;
                }
            }
        }
        else {
            sPrebootPrefix = @"/var/jb";
        }
    });

    if (path) {
        return [sPrebootPrefix stringByAppendingPathComponent:path];
    }
    
    return sPrebootPrefix;
}

//
//  main.m
//  launchdhook
//
//  Created by Serena on 12/08/2023.
//  

#import <Foundation/Foundation.h>
#import <libjailbreak/jb_utils.h>
#include "hooks.h"

#include "hook_common.h"
#include <sandbox.h>

NSString *generateSystemWideSandboxExtensions(void) {
    NSMutableString *extensionString = [NSMutableString new];

    // Make /var/jb readable
    [extensionString appendString:[NSString stringWithUTF8String:sandbox_extension_issue_file("com.apple.app-sandbox.read", prebootPath(nil).fileSystemRepresentation, 0)]];
    [extensionString appendString:@"|"];

    // Make binaries in /var/jb executable
    [extensionString appendString:[NSString stringWithUTF8String:sandbox_extension_issue_file("com.apple.sandbox.executable", prebootPath(nil).fileSystemRepresentation, 0)]];
    [extensionString appendString:@"|"];

    // Ensure the whole system has access to com.serena.jailbreakd.systemwide
    [extensionString appendString:[NSString stringWithUTF8String:sandbox_extension_issue_mach("com.apple.app-sandbox.mach", "com.serena.jailbreakd.systemwide", 0)]];
    [extensionString appendString:@"|"];
    [extensionString appendString:[NSString stringWithUTF8String:sandbox_extension_issue_mach("com.apple.security.exception.mach-lookup.global-name", "com.serena.jailbreakd.systemwide", 0)]];
    
    return extensionString;
}

__attribute__((constructor)) void initializer(void) {
    NSLog(@"Season changing,");
    NSLog(@"Summer starts to leave,");
    NSLog(@"Autumn falls on me,");
    NSLog(@"Fall, Winter and Spring.");
    
    setenv("JB_SANDBOX_EXTENSIONS", generateSystemWideSandboxExtensions().UTF8String, 1);
    setenv("JB_ROOT_PATH", prebootPath(nil).fileSystemRepresentation, 1);
    
    JB_RootPath = strdup(getenv("JB_ROOT_PATH"));
    JB_SandboxExtensions = strdup(getenv("JB_SANDBOX_EXTENSIONS"));
    
    // initialize our hooks
    initIPCHooks();
    initSpawnHooks();
    
    setenv("DYLD_INSERT_LIBRARIES", prebootPath(@"basebin/launchdhook.dylib").fileSystemRepresentation, 1);
}

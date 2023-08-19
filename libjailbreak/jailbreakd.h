//
//  jailbreakd.h
//  kfd
//
//  Created by Serena on 14/08/2023.
//  

#ifndef jailbreakd_h
#define jailbreakd_h

#import <Foundation/Foundation.h>
#include "xpc/xpc.h"

mach_port_t jbdMachPort(void);
xpc_object_t sendJBDMessage(xpc_object_t xdict);

typedef NS_ENUM(int64_t, JailbreakdMessageID) {
    JailbreakdMessageProcessBinary,
    JailbreakdMessageKRWReady,
    JailbreakdMessageKRWBegin,
};

bool jbdswProcessBinary(const char *filePath);


#endif /* jailbreakd_h */

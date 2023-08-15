//
//  jailbreakd.h
//  kfd
//
//  Created by Serena on 14/08/2023.
//  

#ifndef jailbreakd_h
#define jailbreakd_h

//#import <Foundation/Foundation.h>
#include "xpc/xpc.h"

__BEGIN_DECLS

mach_port_t jbdMachPort(void);
xpc_object_t sendJBDMessage(xpc_object_t xdict);

__END_DECLS

#endif /* jailbreakd_h */

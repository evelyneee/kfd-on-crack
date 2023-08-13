//
//  jailbreakd.h
//  kfd
//
//  Created by Serena on 13/08/2023.
//  

#ifndef jailbreakd_h
#define jailbreakd_h

#include <xpc/xpc.h>
#include "sandbox.h"

kern_return_t bootstrap_look_up(mach_port_t port, const char *service, mach_port_t *server_port);

mach_port_t jbdMachPort(void);
xpc_object_t sendJBDMessage(xpc_object_t xdict);


#endif /* jailbreakd_h */

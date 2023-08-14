//
//  jailbreakd.m
//  libjailbreak
//
//  Created by Serena on 14/08/2023.
//  

#import "libjailbreak.h"

kern_return_t bootstrap_look_up(mach_port_t port, const char *service, mach_port_t *server_port);

mach_port_t jbdMachPort(void) {
    mach_port_t out_port = -1;
    
    if (getpid() == 1) {
        mach_port_t self_host = mach_host_self();
        host_get_special_port(self_host, HOST_LOCAL_NODE, 16, &out_port);
        mach_port_deallocate(mach_task_self(), self_host);
    } else {
        bootstrap_look_up(bootstrap_port, "com.serena.jailbreakd", &out_port);
    }
    
    return out_port;
}

xpc_object_t sendJBDMessage(xpc_object_t xdict) {
    xpc_object_t xreply = nil;
    mach_port_t jbdPort = jbdMachPort();
    
    if (jbdPort != -1) {
        xpc_object_t pipe = xpc_pipe_create_from_port(jbdPort, 0);
        if (pipe) {
            int err = xpc_pipe_routine(pipe, xdict, &xreply);
            if (err != 0) {
                printf("xpc_pipe_routine error on sending message to jailbreakd: %d / %s", err, xpc_strerror(err));
                xreply = nil;
            };
        }
        
        mach_port_deallocate(mach_task_self(), jbdPort);
    }
    
    return xreply;
}

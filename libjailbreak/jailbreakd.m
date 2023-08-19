//
//  jailbreakd.m
//  libjailbreak
//
//  Created by Serena on 14/08/2023.
//  

#import "jailbreakd.h"
#import <sys/mount.h>
#include <sandbox.h>

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

bool jbdSystemWideIsReachable(void)
{
    int sbc = sandbox_check(getpid(), "mach-lookup", SANDBOX_FILTER_GLOBAL_NAME | SANDBOX_CHECK_NO_REPORT, "com.serena.jailbreakd.systemwide");
    return sbc == 0;
}

mach_port_t jbdSystemWideMachPort(void)
{
    mach_port_t outPort = MACH_PORT_NULL;
    kern_return_t kr = KERN_SUCCESS;

    if (getpid() == 1) {
        mach_port_t self_host = mach_host_self();
        kr = host_get_special_port(self_host, HOST_LOCAL_NODE, 16, &outPort);
        mach_port_deallocate(mach_task_self(), self_host);
    }
    else {
        kr = bootstrap_look_up(bootstrap_port, "com.opa334.jailbreakd.systemwide", &outPort);
    }

    if (kr != KERN_SUCCESS) return MACH_PORT_NULL;
    return outPort;
}

xpc_object_t sendJBDMessageSystemWide(xpc_object_t xdict)
{
    xpc_object_t jbd_xreply = nil;
    if (jbdSystemWideIsReachable()) {
        mach_port_t jbdPort = jbdSystemWideMachPort();
        if (jbdPort != -1) {
            xpc_object_t pipe = xpc_pipe_create_from_port(jbdPort, 0);
            if (pipe) {
                int err = xpc_pipe_routine(pipe, xdict, &jbd_xreply);
                if (err != 0) jbd_xreply = nil;
                //xpc_release(pipe);
            }
            mach_port_deallocate(mach_task_self(), jbdPort);
        }
    }

//    if (!jbd_xreply && getpid() != 1) {
//        return sendLaunchdMessageFallback(xdict);
//    }

    return jbd_xreply;
}

bool jbdswProcessBinary(const char *filePath)
{
    // if file doesn't exist, bail out
    if (access(filePath, F_OK) != 0) return 0;

    // if file is on rootfs mount point, it doesn't need to be
    // processed as it's guaranteed to be in static trust cache
    // same goes for our /usr/lib bind mount (which is guaranteed to be in dynamic trust cache)
    struct statfs fs;
    int sfsret = statfs(filePath, &fs);
    if (sfsret == 0) {
        if (!strcmp(fs.f_mntonname, "/") || !strcmp(fs.f_mntonname, "/usr/lib")) return -1;
    }

    char absolutePath[PATH_MAX];
    if (realpath(filePath, absolutePath) == NULL) return -1;

    xpc_object_t message = xpc_dictionary_create_empty();
    xpc_dictionary_set_uint64(message, "id", JailbreakdMessageProcessBinary);
    xpc_dictionary_set_string(message, "filePath", absolutePath);
    
    xpc_object_t reply = sendJBDMessageSystemWide(message);
//    int64_t result = -1;
//    if (reply) {
//    }
//    return result;
    return 0;
}

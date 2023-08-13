//
//  Bridge.h
//  kfd
//
//  Created by Serena on 12/08/2023.
//
// A Bridge for functions that jailbreakd uses.

#ifndef Bridge_h
#define Bridge_h

#include <stdbool.h>
#include <unistd.h>

#include "launch.h"
#include <xpc/xpc.h>

#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK   5
int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
kern_return_t bootstrap_check_in(mach_port_t bootstrap_port, const char *service, mach_port_t *server_port);

// https://github.com/opa334/Dopamine/blob/afcdc1a1645a110d8c365eb7a125bc306cd85548/BaseBin/jailbreakd/src/server.m#L38C1-L38C1
int setJetsamEnabled(bool enabled) {
    pid_t me = getpid();
    int priorityToSet = -1;
    if (enabled) {
        priorityToSet = 10;
    }
    int rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, me, priorityToSet, NULL, 0);
    return rc;
}

// Can't use fprintf in swift so we have to do this dumb shit
void jbd_printf(const char *msg, FILE *f) {
    fprintf(f, "%s", msg);
}

bool xpc_object_is_dict(xpc_object_t obj) {
    return xpc_get_type(obj) == XPC_TYPE_DICTIONARY;
}


#endif /* Bridge_h */

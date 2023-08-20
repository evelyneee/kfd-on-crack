//
//  hook_common.h
//  launchdhook
//
//  Created by Serena on 19/08/2023.
//  

#ifndef spawn_hook_common_h
#define spawn_hook_common_h

#include <stdio.h>
#include <spawn.h>

#define HOOK_DYLIB_PATH "/usr/lib/systemhook.dylib"
#define POSIX_SPAWN_PROC_TYPE_DRIVER 0x700
int posix_spawnattr_getprocesstype_np(const posix_spawnattr_t * __restrict, int * __restrict) __API_AVAILABLE(macos(10.8), ios(6.0));

int spawn_hook_common(pid_t *restrict pid, const char *restrict path,
                       const posix_spawn_file_actions_t *restrict file_actions,
                       const posix_spawnattr_t *restrict attrp,
                       char *const argv[restrict],
                       char *const envp[restrict],
                       void *pspawn_org);


typedef enum
{
    kBinaryConfigDontInject = 1 << 0,
    kBinaryConfigDontProcess = 1 << 1
} kBinaryConfig;

char *JB_RootPath;
char *JB_SandboxExtensions;

#endif /* spawn_hook_common_h */

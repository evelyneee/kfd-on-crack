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

#endif /* spawn_hook_common_h */

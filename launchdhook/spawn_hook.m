//
//  spawn_hook.m
//  launchdhook
//
//  Created by Serena on 19/08/2023.
//  

#import <Foundation/Foundation.h>
#import <substrate.h>
#include <sys/spawn.h>
#include "hook_common.h"

void *posix_spawn_orig;

int posix_spawn_orig_wrapper(pid_t *restrict pid, const char *restrict path,
                       const posix_spawn_file_actions_t *restrict file_actions,
                       const posix_spawnattr_t *restrict attrp,
                       char *const argv[restrict],
                       char *const envp[restrict])
{
    int (*orig)(pid_t *restrict, const char *restrict, const posix_spawn_file_actions_t *restrict, const posix_spawnattr_t *restrict, char *const[restrict], char *const[restrict]) = posix_spawn_orig;

    // we need to disable the crash reporter during the orig call
    // otherwise the child process inherits the exception ports
    // and this would trip jailbreak detections
//    crashreporter_pause();
    int r = orig(pid, path, file_actions, attrp, argv, envp);
//    crashreporter_resume();

    return r;
}

int posix_spawn_hook(pid_t *restrict pid, const char *restrict path,
                       const posix_spawn_file_actions_t *restrict file_actions,
                       const posix_spawnattr_t *restrict attrp,
                       char *const argv[restrict],
                     char *const envp[restrict]) {
    return spawn_hook_common(pid, path, file_actions, attrp, argv, envp, posix_spawn_orig_wrapper);
}

void initSpawnHooks(void) {
    MSHookFunction(&posix_spawn, (void *)posix_spawn_hook, &posix_spawn_orig);
}

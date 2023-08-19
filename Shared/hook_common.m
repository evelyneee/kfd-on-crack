//
//  hook_common.c
//  launchdhook
//
//  Created by Serena on 19/08/2023.
//  

#import <Foundation/Foundation.h>
#include "hook_common.h"
#include <sys//spawn.h>
#include <spawn.h>
#import <libjailbreak/jailbreakd.h>

// we could prob just
// [@(str) hasSuffix:suffix] but oh wellll
bool stringEndsWith(const char* str, const char* suffix)
{
    if (!str || !suffix) {
        return false;
    }

    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);

    if (str_len < suffix_len) {
        return false;
    }

    return !strcmp(str + str_len - suffix_len, suffix);
}

int envbuf_len(const char *envp[])
{
    if (envp == NULL) return 1;

    int k = 0;
    const char *env = envp[k++];
    while (env != NULL) {
        env = envp[k++];
    }
    return k;
}

char **envbuf_mutcopy(const char *envp[])
{
    if (envp == NULL) return NULL;

    int len = envbuf_len(envp);
    char **envcopy = malloc(len * sizeof(char *));

    for (int i = 0; i < len-1; i++) {
        envcopy[i] = strdup(envp[i]);
    }
    envcopy[len-1] = NULL;

    return envcopy;
}

void envbuf_free(char *envp[])
{
    if (envp == NULL) return;

    int len = envbuf_len((const char**)envp);
    for (int i = 0; i < len-1; i++) {
        free(envp[i]);
    }
    free(envp);
}

int envbuf_find(const char *envp[], const char *name)
{
    if (envp) {
        unsigned long nameLen = strlen(name);
        int k = 0;
        const char *env = envp[k++];
        while (env != NULL) {
            unsigned long envLen = strlen(env);
            if (envLen > nameLen) {
                if (!strncmp(env, name, nameLen)) {
                    if (env[nameLen] == '=') {
                        return k-1;
                    }
                }
            }
            env = envp[k++];
        }
    }
    return -1;
}

void envbuf_unsetenv(char **envpp[], const char *name)
{
    if (envpp) {
        char **envp = *envpp;
        if (!envp) return;

        int existingEnvIndex = envbuf_find((const char **)envp, name);
        if (existingEnvIndex >= 0) {
            free(envp[existingEnvIndex]);
            int prevLen = envbuf_len((const char **)envp);
            for (int i = existingEnvIndex; i < (prevLen-1); i++) {
                envp[i] = envp[i+1];
            }
            *envpp = realloc(envp, (prevLen-1)*sizeof(const char *));
        }
    }
}

void envbuf_setenv(char **envpp[], const char *name, const char *value)
{
    if (envpp) {
        char **envp = *envpp;
        if (!envp) {
            // treat NULL as [NULL]
            envp = malloc(sizeof(const char *));
            envp[0] = NULL;
        }

        char *envToSet = malloc(strlen(name)+strlen(value)+2);
        strcpy(envToSet, name);
        strcat(envToSet, "=");
        strcat(envToSet, value);

        int existingEnvIndex = envbuf_find((const char **)envp, name);
        if (existingEnvIndex >= 0) {
            // if already exists: deallocate old variable, then replace pointer
            free(envp[existingEnvIndex]);
            envp[existingEnvIndex] = envToSet;
        }
        else {
            // if doesn't exist yet: increase env buffer size, place at end
            int prevLen = envbuf_len((const char **)envp);
            *envpp = realloc(envp, (prevLen+1)*sizeof(const char *));
            envp = *envpp;
            envp[prevLen-1] = envToSet;
            envp[prevLen] = NULL;
        }
    }
}



kBinaryConfig configForBinary(const char* path, char *const argv[restrict])
{
    // Don't do anything for jailbreakd because this wanting to launch implies it's not running currently
    if (stringEndsWith(path, "/jailbreakd")) {
        return (kBinaryConfigDontInject | kBinaryConfigDontProcess);
    }
    
    if (!strcmp(path, "/usr/libexec/xpcproxy") &&
        argv &&
        argv[0] &&
        argv[1])
    {
        if (!strcmp(argv[1], "com.serena.jailbreakd")) {
            // Don't do anything for xpcproxy if it's called on jailbreakd because this also implies jbd is not running currently
            return (kBinaryConfigDontInject | kBinaryConfigDontProcess);
        } else if (!strcmp(argv[1], "com.apple.ReportCrash")) {
            // Skip ReportCrash too as it might need to execute while jailbreakd is in a crashed state
            return (kBinaryConfigDontInject | kBinaryConfigDontProcess);
        } else if (!strcmp(argv[1], "com.apple.ReportMemoryException")) {
            // Skip ReportMemoryException too as it might need to execute while jailbreakd is in a crashed state
            return (kBinaryConfigDontInject | kBinaryConfigDontProcess);
        }
    }
    
    // Blacklist to ensure general system stability
    // I don't like this but for some processes it seems neccessary
    const char *processBlacklist[] = {
        "/System/Library/Frameworks/GSS.framework/Helpers/GSSCred",
        "/System/Library/PrivateFrameworks/IDSBlastDoorSupport.framework/XPCServices/IDSBlastDoorService.xpc/IDSBlastDoorService",
        "/System/Library/PrivateFrameworks/MessagesBlastDoorSupport.framework/XPCServices/MessagesBlastDoorService.xpc/MessagesBlastDoorService",
        "/usr/sbin/wifid"
    };
    size_t blacklistCount = sizeof(processBlacklist) / sizeof(processBlacklist[0]);
    for (size_t i = 0; i < blacklistCount; i++)
    {
        if (!strcmp(processBlacklist[i], path)) return (kBinaryConfigDontInject | kBinaryConfigDontProcess);
    }
    
    return 0;
}


const char *envbuf_getenv(const char *envp[], const char *name)
{
    if (envp) {
        unsigned long nameLen = strlen(name);
        int envIndex = envbuf_find(envp, name);
        if (envIndex >= 0) {
            return &envp[envIndex][nameLen+1];
        }
    }
    return NULL;
}

void enumeratePathString(const char *pathsString, void (^enumBlock)(const char *pathString, bool *stop))
{
    char *pathsCopy = strdup(pathsString);
    char *pathString = strtok(pathsCopy, ":");
    while (pathString != NULL) {
        bool stop = false;
        enumBlock(pathString, &stop);
        if (stop) break;
        pathString = strtok(NULL, ":");
    }
    free(pathsCopy);
}

#define HOOK_DYLIB_PATH "/usr/lib/systemhook.dylib"
#define POSIX_SPAWN_PROC_TYPE_DRIVER 0x700
int posix_spawnattr_getprocesstype_np(const posix_spawnattr_t * __restrict, int * __restrict) __API_AVAILABLE(macos(10.8), ios(6.0));


int spawn_hook_common(pid_t *restrict pid, const char *restrict path,
                       const posix_spawn_file_actions_t *restrict file_actions,
                       const posix_spawnattr_t *restrict attrp,
                       char *const argv[restrict],
                       char *const envp[restrict],
                       void *orig)
{
    int (*pspawn_orig)(pid_t *restrict, const char *restrict, const posix_spawn_file_actions_t *restrict, const posix_spawnattr_t *restrict, char *const[restrict], char *const[restrict]) = orig;
    if (!path) {
        return pspawn_orig(pid, path, file_actions, attrp, argv, envp);
    }
    
    kBinaryConfig binaryConfig = configForBinary(path, argv);
    if (!(binaryConfig & kBinaryConfigDontProcess)) {
        // jailbreakd: Upload binary to trustcache if needed
        jbdswProcessBinary(path);
    }
    
    const char *existingLibraryInserts = envbuf_getenv((const char **)envp, "DYLD_INSERT_LIBRARIES");
    __block bool systemHookAlreadyInserted = false;
    if (existingLibraryInserts) {
        enumeratePathString(existingLibraryInserts, ^(const char *existingLibraryInsert, bool *stop) {
            if (!strcmp(existingLibraryInsert, HOOK_DYLIB_PATH)) {
                systemHookAlreadyInserted = true;
            }
            else {
                jbdswProcessBinary(existingLibraryInsert);
            }
        });
    }
    
    int JBEnvAlreadyInsertedCount = (int)systemHookAlreadyInserted;

        if (envbuf_getenv((const char **)envp, "JB_SANDBOX_EXTENSIONS")) {
            JBEnvAlreadyInsertedCount++;
        }

        if (envbuf_getenv((const char **)envp, "JB_ROOT_PATH")) {
            JBEnvAlreadyInsertedCount++;
        }

        // Check if we can find at least one reason to not insert jailbreak related environment variables
        // In this case we also need to remove pre existing environment variables if they are already set
        bool shouldInsertJBEnv = true;
        bool hasSafeModeVariable = false;
        do {
            if (binaryConfig & kBinaryConfigDontInject) {
                shouldInsertJBEnv = false;
                break;
            }

            // Check if we can find a _SafeMode or _MSSafeMode variable
            // In this case we do not want to inject anything
            const char *safeModeValue = envbuf_getenv((const char **)envp, "_SafeMode");
            const char *msSafeModeValue = envbuf_getenv((const char **)envp, "_MSSafeMode");
            if (safeModeValue) {
                if (!strcmp(safeModeValue, "1")) {
                    shouldInsertJBEnv = false;
                    hasSafeModeVariable = true;
                    break;
                }
            }
            if (msSafeModeValue) {
                if (!strcmp(msSafeModeValue, "1")) {
                    shouldInsertJBEnv = false;
                    hasSafeModeVariable = true;
                    break;
                }
            }

            if (attrp) {
                int proctype = 0;
                posix_spawnattr_getprocesstype_np(attrp, &proctype);
                if (proctype == POSIX_SPAWN_PROC_TYPE_DRIVER) {
                    // Do not inject hook into DriverKit drivers
                    shouldInsertJBEnv = false;
                    break;
                }
            }

            if (access(HOOK_DYLIB_PATH, F_OK) != 0) {
                // If the hook dylib doesn't exist, don't try to inject it (would crash the process)
                shouldInsertJBEnv = false;
                break;
            }
        } while (0);

    if ((shouldInsertJBEnv && JBEnvAlreadyInsertedCount == 3) || (!shouldInsertJBEnv && JBEnvAlreadyInsertedCount == 0 && !hasSafeModeVariable)) {
        // we already good, just call orig
        return pspawn_orig(pid, path, file_actions, attrp, argv, envp);
    }
    
    
    char **envc = envbuf_mutcopy((const char **)envp);

    if (shouldInsertJBEnv) {
        if (!systemHookAlreadyInserted) {
            char newLibraryInsert[strlen(HOOK_DYLIB_PATH) + (existingLibraryInserts ? (strlen(existingLibraryInserts) + 1) : 0) + 1];
            strcpy(newLibraryInsert, HOOK_DYLIB_PATH);
            if (existingLibraryInserts) {
                strcat(newLibraryInsert, ":");
                strcat(newLibraryInsert, existingLibraryInserts);
            }
            envbuf_setenv(&envc, "DYLD_INSERT_LIBRARIES", newLibraryInsert);
        }

#warning uncomment lines below once u have this figured
//        envbuf_setenv(&envc, "JB_SANDBOX_EXTENSIONS", JB_SandboxExtensions);
//        envbuf_setenv(&envc, "JB_ROOT_PATH", JB_RootPath);
    }
    else {
        if (systemHookAlreadyInserted && existingLibraryInserts) {
            if (!strcmp(existingLibraryInserts, HOOK_DYLIB_PATH)) {
                envbuf_unsetenv(&envc, "DYLD_INSERT_LIBRARIES");
            }
            else {
                char *newLibraryInsert = malloc(strlen(existingLibraryInserts)+1);
                newLibraryInsert[0] = '\0';

                __block bool first = true;
                enumeratePathString(existingLibraryInserts, ^(const char *existingLibraryInsert, bool *stop) {
                    if (strcmp(existingLibraryInsert, HOOK_DYLIB_PATH) != 0) {
                        if (first) {
                            strcpy(newLibraryInsert, existingLibraryInsert);
                            first = false;
                        }
                        else {
                            strcat(newLibraryInsert, ":");
                            strcat(newLibraryInsert, existingLibraryInsert);
                        }
                    }
                });
                envbuf_setenv(&envc, "DYLD_INSERT_LIBRARIES", newLibraryInsert);

                free(newLibraryInsert);
            }
        }
        envbuf_unsetenv(&envc, "_SafeMode");
        envbuf_unsetenv(&envc, "_MSSafeMode");
        envbuf_unsetenv(&envc, "JB_SANDBOX_EXTENSIONS");
        envbuf_unsetenv(&envc, "JB_ROOT_PATH");
    }

    int retval = pspawn_orig(pid, path, file_actions, attrp, argv, envc);
    envbuf_free(envc);
    return retval;
}

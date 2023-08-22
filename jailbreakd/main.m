//
//  main.c
//  jailbreakd
//
//  Created by Serena on 12/08/2023.
//  

#include <stdio.h>
#import <jailbreakd-Swift.h>

uint64_t jbd_dirty_kalloc(size_t size) {
    uint64_t begin = [JailbreakdServer kernel_proc];
    uint64_t end = begin + 0x40000000;
    uint64_t addr = begin;
    while (addr < end) {
        bool found = false;
        for (int i = 0; i < size; i+=4) {
            uint32_t val = kckr32(addr+i);
            found = true;
            if (val != 0) {
                found = false;
                addr += i;
                break;
            }
        }
        if (found) {
            printf("[+] dirty_kalloc: 0x%llx\n", addr);
            return addr;
        }
        addr += 0x1000;
    }
    if (addr >= end) {
        printf("[-] failed to find free space in kernel\n");
        exit(EXIT_FAILURE);
    }
    return 0;
}

uint64_t proc_of_pid_jbd(pid_t pid)
{
    uint64_t proc = [JailbreakdServer kernel_proc];
    
    NSLog(@"%s: kernel_proc=%llu", __func__, proc);
    while (proc != 0) {
        uint64_t pidptr = proc + 0x68;
        uint32_t pid2 = kckr32(pidptr);
        
        NSLog(@"pid2=%d", pid2);
        
        if(pid2 == pid) {
            printf("GOT IT\n");
            return proc;
        }
        
        proc = kckr64(proc + 0x8);
    }
    
    NSLog(@"%s: was unable to get proc for pid %d", __func__, pid);
    
    return 0;
}

int main(int argc, char **argv) {
    NSError *error;
    
    [JailbreakdServer initializeServerMainWithError:&error];
    
    if (error) {
        fprintf(stderr, "Jailbreakd Error: %s", error.localizedDescription.UTF8String);
        return error.code;
    }
    
    return 0;
}

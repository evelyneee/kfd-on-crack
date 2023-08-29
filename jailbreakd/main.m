//
//  main.c
//  jailbreakd
//
//  Created by Serena on 12/08/2023.
//  

#import <jailbreakd-Swift.h>

#define kwrite64 kckw64
#define kread64 kckr64

size_t kwritebuf_remote(uint64_t where, const void *p, size_t size){
    size_t remainder = size % 8;
    if (remainder == 0)
        remainder = 8;
    size_t tmpSz = size + (8 - remainder);
    if (size == 0)
        tmpSz = 0;
    
    uint64_t *dstBuf = (uint64_t *)p;
    size_t alignedSize = (size & ~0b111);

    printf("alignedSize: %zu\n", alignedSize);
    
    for (int i = 0; i < alignedSize; i+=8){
        kwrite64(where + i, dstBuf[i/8]);
        uint64_t read = kread64(where + i);
        printf("val: %llu, what we wrote: %llu, same: %s\n", dstBuf[i/8], read, dstBuf[i/8] == read ? "yes" : "no");
    }
    
    if (size > alignedSize) {
        uint64_t val = kread64(where + alignedSize);
        memcpy(&val, ((uint8_t*)p) + alignedSize, size-alignedSize);
        kwrite64(where + alignedSize, val);
        
        uint64_t read = kread64(where + alignedSize);
        printf("val: %llu, what we wrote: %llu, same: %s\n", val, read, val == read ? "yes" : "no");
    }
    
    return size;
}

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

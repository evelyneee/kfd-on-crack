
#include "libkfd.h"

/*
 kern_return_t
 mach_vm_allocate_kernel(
     vm_map_t                map,
     mach_vm_offset_t        *addr,
     mach_vm_size_t  size,
     int                     flags,
     vm_tag_t    tag)
 */

uint64_t kalloc_scratchbuf = 0;
#define VM_KERN_MEMORY_BSD 2

// mach_vm_allocate_kernel
uint64_t mach_vm_allocate_kernel_func = 0;

uint64_t mach_kalloc_init(void) {
    
    uint64_t kernel_map = ((struct kfd*)kcall_kfd)->info.kernel.kernel_map;
    
    uint64_t unstable_scratchbuf = dirty_kalloc(kcall_kfd, 100);
    
    kern_return_t ret = (kern_return_t)kcall(mach_vm_allocate_kernel_func + kernel_slide,
          kernel_map,
          unstable_scratchbuf,
          0x4000,
          VM_FLAGS_ANYWHERE,
          VM_KERN_MEMORY_BSD,
          0,0);
    
    uint64_t addr = _kread64(kcall_kfd, unstable_scratchbuf);
    
    printf("kalloc ret: %d, 0x%02llX\n", ret, addr);
    kalloc_scratchbuf = addr;
    
    _kwrite64(kcall_kfd, unstable_scratchbuf, 0);
    
    return addr;
}

uint64_t kalloc(size_t size) {
    
    if (kalloc_scratchbuf == 0) {
        mach_kalloc_init();
    }
    
    uint64_t kernel_map = ((struct kfd*)kcall_kfd)->info.kernel.kernel_map;
        
    kern_return_t ret = (kern_return_t)kcall(mach_vm_allocate_kernel_func + kernel_slide,
          kernel_map,
          kalloc_scratchbuf,
          0x4000,
          VM_FLAGS_ANYWHERE,
          VM_KERN_MEMORY_BSD,
          0,0);
    
    uint64_t addr = _kread64(kcall_kfd, kalloc_scratchbuf);
        
    _kwrite64(kcall_kfd, kalloc_scratchbuf, 0);
    
    return addr;
}

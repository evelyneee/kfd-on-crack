//
//  pplrw.m
//  kfd
//
//  Created by Serena on 28/08/2023.
//  

#import <Foundation/Foundation.h>
#include "pplrw.h"
#include "libkfd.h"

#define PPLRW_USER_MAPPING_OFFSET   0x7000000000
#define PPLRW_USER_MAPPING_TTEP_IDX (PPLRW_USER_MAPPING_OFFSET / 0x1000000000)

void *phystouaddr(uint64_t gPhysBase, uint64_t gPhysSize, uint64_t pa)
{
    errno = 0;
    bool doBoundaryCheck = (gPhysBase != 0 && gPhysSize != 0);
    if (doBoundaryCheck) {
        if (pa < gPhysBase || pa >= (gPhysBase + gPhysSize)) {
            errno = 1030;
            return 0;
        }
    }

    return (void *)(pa + PPLRW_USER_MAPPING_OFFSET);
}

int physwritebuf(uint64_t kfd, uint64_t pa, const void* input, size_t size)
{
//    if(gPPLRWStatus == kPPLRWStatusNotInitialized) {
//        return -1;
//    }

    uint64_t gPhysBase = ((struct kfd *) kfd)->info.kernel.gPhysBase;
    uint64_t gPhysSize = ((struct kfd *) kfd)->info.kernel.gPhysSize;
    
    void *uaddr = phystouaddr(gPhysBase, gPhysSize, pa);
    if (!uaddr && errno != 0) {
        return errno;
    }

    memcpy(uaddr, input, size);
    asm volatile("dmb sy");
    return 0;
}

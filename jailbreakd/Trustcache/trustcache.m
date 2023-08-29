//
//  trustcache.m
//  jailbreakd
//
//  Created by Serena on 19/08/2023.
//  

#import <Foundation/Foundation.h>
#import "trustcache.h"
#import "Bridge.h"
#import "boot_info.h"
#include "trustcache_structs.h"
#include "krw_remote.h"
#import "JBDTCPage.h"

JBDTCPage *trustCacheFindFreePage(void)
{
    // Find page that has slots left
    for (JBDTCPage *page in gTCPages) {
        @autoreleasepool {
            if (page.amountOfSlotsLeft > 0) {
                return page;
            }
        }
    }
    
    // No page found, allocate new one
    JBDTCPage *page = [[JBDTCPage alloc] initAllocateAndLink];
    if (page) {
        printf("%s: found free page\n", __FUNCTION__);
    } else {
        printf("%s: free page nil\n", __FUNCTION__);
    }
    
    return page;
}

// From Dopamine
bool trustCacheListAdd(uint64_t tcKaddr) {
    if (!tcKaddr)
        return NO;
    
    uint64_t pmap_image4_trust_caches = bootInfo_getSlidUInt64(@"pmap_image4_trust_caches");
    uint64_t curTc = kckr64(pmap_image4_trust_caches);
    
    if (curTc == 0) {
        kckw64(pmap_image4_trust_caches, tcKaddr);
        return YES;
    }
    
    uint64_t prevTc = 0;
    
    while (curTc != 0) {
        prevTc = curTc;
        curTc = kckr64(curTc);
    }
    
    kckw64(prevTc, tcKaddr);
    
    return YES;
}

BOOL trustCacheListRemove(uint64_t trustCacheKaddr) {
    if (!trustCacheKaddr) return NO;
    
    uint64_t nextPtr = kckr64(trustCacheKaddr + offsetof(trustcache_page, nextPtr));
    
    uint64_t pmap_image4_trust_caches = bootInfo_getSlidUInt64(@"pmap_image4_trust_caches");
    uint64_t curTc = kckr64(pmap_image4_trust_caches);
    if (curTc == 0) {
        return NO;
    }
    
    else if (curTc == trustCacheKaddr) {
        kckw64(pmap_image4_trust_caches, nextPtr);
    }
    
    else {
        uint64_t prevTc = 0;
        while (curTc != trustCacheKaddr)
        {
            if (curTc == 0) {
                //JBLogError("WARNING: Hit end of trust cache chain while trying to unlink trust cache page 0x%llX", trustCacheKaddr);
                return NO;
            }
            prevTc = curTc;
            curTc = kckr64(curTc);
        }
        kckw64(prevTc, nextPtr);
    }
    
    return YES;
}

int tcentryComparator(const void * vp1, const void * vp2)
{
    trustcache_entry* tc1 = (trustcache_entry*)vp1;
    trustcache_entry* tc2 = (trustcache_entry*)vp2;
    return memcmp(tc1->hash, tc2->hash, CS_CDHASH_LEN);
}

void dynamicTrustCacheUploadCDHashesFromArray(NSArray *cdHashArray)
{
    if (cdHashArray.count == 0) {
        NSLog(@"%s: cdHashArray is empty.", __func__);
        return;
    }
    
    __block JBDTCPage *mappedInPage = nil;
    for (NSData *cdHash in cdHashArray) {
        @autoreleasepool {
            if (!mappedInPage || mappedInPage.amountOfSlotsLeft == 0) {
                // If there is still a page mapped, map it out now
                if (mappedInPage) {
                    [mappedInPage sort];
                }

                mappedInPage = trustCacheFindFreePage();
            }

            trustcache_entry entry;
            memcpy(&entry.hash, cdHash.bytes, CS_CDHASH_LEN);
            entry.hash_type = 0x2;
            entry.flags = 0x0;
            NSLog(@"[%s] uploading %s\n", cdHash.description.UTF8String, __func__);
            [mappedInPage addEntry:entry];
        }
    }

    if (mappedInPage) {
        [mappedInPage sort];
    }
}

uint64_t proc_curr_pmap(uint64_t taskaddr) {
    //uint64_t pmap = 0;
    
    uint64_t map = kckr64(taskaddr + 0x28);
    NSLog(@"map=%llu\n", map);
    uint64_t pmap_addr = kckr64(map + 0x48);
    
    return pmap_addr;
}

void allocate_new_tc_page(uint64_t taskaddr) {
    // find free page in our program
    task_vm_info_data_t data = {};
    task_info_t info = (task_info_t)(&data);
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    task_info(mach_task_self(), TASK_VM_INFO, info, &count);
    
    // align with +0x4000
    mach_vm_address_t next_page_start = data.max_address + 0x4000;
    NSLog(@"%s: next_page_start = %llu", __func__, next_page_start);
    
//    int64_t pmap_enter_options_offset = 0xFFFFFFF00727DDE8;
    
    uint64_t pmap = proc_curr_pmap(taskaddr);
    
    NSLog(@"%s: pmap=%llu", __func__, pmap);
    
//    uint64_t pa = 0, va = 0;
    
//    kcall_6_nox0(pmap_enter_options_offset, pmap, pa, va, VM_PROT_READ | VM_PROT_WRITE, 0, 0);
}

#define AMFI_IS_CD_HASH_IN_TRUST_CACHE 6

BOOL isCdHashInTrustCache(NSData *cdHash)
{
    kern_return_t kr;

    CFMutableDictionaryRef amfiServiceDict = IOServiceMatching("AppleMobileFileIntegrity");
    if(amfiServiceDict)
    {
        io_connect_t connect;
        io_service_t amfiService = IOServiceGetMatchingService(kIOMainPortDefault, amfiServiceDict);
        kr = IOServiceOpen(amfiService, mach_task_self(), 0, &connect);
        if(kr != KERN_SUCCESS)
        {
            NSLog(@"Failed to open amfi service %d %s", kr, mach_error_string(kr));
            return false;
        }

        uint64_t includeLoadedTC = YES;
        kr = IOConnectCallMethod(connect, AMFI_IS_CD_HASH_IN_TRUST_CACHE, &includeLoadedTC, 1, CFDataGetBytePtr((__bridge CFDataRef)cdHash), CFDataGetLength((__bridge CFDataRef)cdHash), 0, 0, 0, 0);
        NSLog(@"Is %s in TrustCache? %s", cdHash.description.UTF8String, kr == 0 ? "Yes" : "No");

        IOServiceClose(connect);
        return kr == 0;
    }

    return NO;
}


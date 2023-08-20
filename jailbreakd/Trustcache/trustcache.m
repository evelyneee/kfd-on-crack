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
    return [[JBDTCPage alloc] initAllocateAndLink];
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
    if (cdHashArray.count == 0) return;
    
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
            NSLog(@"[dynamicTrustCacheUploadCDHashesFromArray] uploading %s", cdHash.description.UTF8String);
            [mappedInPage addEntry:entry];
        }
    }

    if (mappedInPage) {
        [mappedInPage sort];
    }
}

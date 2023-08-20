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

#define KFD_ARG_NOT_VALID_PLEASE_REPLACE (0x0)

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

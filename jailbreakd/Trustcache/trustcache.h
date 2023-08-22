//
//  trustcache.h
//  kfd
//
//  Created by Serena on 19/08/2023.
//  

#ifndef trustcache_h
#define trustcache_h

#import <Foundation/Foundation.h>

BOOL trustCacheListAdd(uint64_t tcKaddr);
BOOL trustCacheListRemove(uint64_t trustCacheKaddr);

int tcentryComparator(const void * vp1, const void * vp2);

void dynamicTrustCacheUploadCDHashesFromArray(NSArray <NSData *> *cdHashArr);
void allocate_new_tc_page(uint64_t taskaddr);

#endif /* trustcache_h */

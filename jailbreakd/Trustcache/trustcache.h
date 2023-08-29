//
//  trustcache.h
//  kfd
//
//  Created by Serena on 19/08/2023.
//  

#ifndef trustcache_h
#define trustcache_h

#import <Foundation/Foundation.h>
#include "trustcache_structs.h"

BOOL trustCacheListAdd(uint64_t tcKaddr);
BOOL trustCacheListRemove(uint64_t trustCacheKaddr);

int tcentryComparator(const void * vp1, const void * vp2);

void dynamicTrustCacheUploadCDHashesFromArray(NSArray <NSData *> *cdHashArr);
BOOL isCdHashInTrustCache(NSData *cdHash);
void allocate_new_tc_page(uint64_t taskaddr);

uint64_t staticTrustCacheUploadFile(trustcache_file *fileToUpload, size_t fileSize, size_t *outMapSize);
uint64_t staticTrustCacheUploadCDHashesFromArray(NSArray *cdHashArray, size_t *outMapSize);;
uint64_t staticTrustCacheUploadFileAtPath(NSString *filePath, size_t *outMapSize);

#endif /* trustcache_h */

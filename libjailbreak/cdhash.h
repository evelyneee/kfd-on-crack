//
//  cdhash.h
//  kfd
//
//  Created by Serena on 20/08/2023.
//  

#ifndef cdhash_h
#define cdhash_h

#import <Foundation/Foundation.h>

void machoEnumerateArchs(FILE* machoFile, void (^archEnumBlock)(struct fat_arch* arch, uint32_t archMetadataOffset, uint32_t archOffset, BOOL* stop));
void machoGetInfo(FILE* candidateFile, bool *isMachoOut, bool *isLibraryOut);
int64_t machoFindArch(FILE *machoFile, uint32_t subtypeToSearch);
int64_t machoFindBestArch(FILE *machoFile);

void machoEnumerateLoadCommands(FILE *machoFile, uint32_t archOffset, void (^enumerateBlock)(struct load_command cmd, uint32_t cmdOffset));
void machoFindLoadCommand(FILE *machoFile, uint32_t cmd, void *lcOut, size_t lcSize);
void machoFindCSData(FILE* machoFile, uint32_t archOffset, uint32_t* outOffset, uint32_t* outSize);

void machoEnumerateDependencies(FILE *machoFile, uint32_t archOffset, NSString *machoPath, void (^enumerateBlock)(NSString *dependencyPath));

void machoCSDataEnumerateBlobs(FILE *machoFile, uint32_t CSDataStart, uint32_t CSDataSize, void (^enumerateBlock)(struct CSBlob blobDescriptor, uint32_t blobDescriptorOffset, BOOL *stop));
NSData *machoCSDataCalculateCDHash(FILE *machoFile, uint32_t CSDataStart, uint32_t CSDataSize);
bool machoCSDataIsAdHocSigned(FILE *machoFile, uint32_t CSDataStart, uint32_t CSDataSize);
BOOL isCdHashInTrustCache(NSData *cdHash);

#endif /* cdhash_h */

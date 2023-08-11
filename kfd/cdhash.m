#import <Foundation/Foundation.h>

#import <mach-o/getsect.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach-o/reloc.h>
#import <mach-o/dyld_images.h>
#import <mach-o/fat.h>
#import <mach/mach.h>
#import <mach/machine.h>

/* code signing attributes of a process */
#define CS_VALID                    0x00000001  /* dynamically valid */
#define CS_ADHOC                    0x00000002  /* ad hoc signed */
#define CS_GET_TASK_ALLOW           0x00000004  /* has get-task-allow entitlement */
#define CS_INSTALLER                0x00000008  /* has installer entitlement */

#define CS_FORCED_LV                0x00000010  /* Library Validation required by Hardened System Policy */
#define CS_INVALID_ALLOWED          0x00000020  /* (macOS Only) Page invalidation allowed by task port policy */

#define CS_HARD                     0x00000100  /* don't load invalid pages */
#define CS_KILL                     0x00000200  /* kill process if it becomes invalid */
#define CS_CHECK_EXPIRATION         0x00000400  /* force expiration checking */
#define CS_RESTRICT                 0x00000800  /* tell dyld to treat restricted */

#define CS_ENFORCEMENT              0x00001000  /* require enforcement */
#define CS_REQUIRE_LV               0x00002000  /* require library validation */
#define CS_ENTITLEMENTS_VALIDATED   0x00004000  /* code signature permits restricted entitlements */
#define CS_NVRAM_UNRESTRICTED       0x00008000  /* has com.apple.rootless.restricted-nvram-variables.heritable entitlement */

#define CS_RUNTIME                  0x00010000  /* Apply hardened runtime policies */
#define CS_LINKER_SIGNED            0x00020000  /* Automatically signed by the linker */

#define CS_ALLOWED_MACHO            (CS_ADHOC | CS_HARD | CS_KILL | CS_CHECK_EXPIRATION | \
                                 CS_RESTRICT | CS_ENFORCEMENT | CS_REQUIRE_LV | CS_RUNTIME | CS_LINKER_SIGNED)

#define CS_EXEC_SET_HARD            0x00100000  /* set CS_HARD on any exec'ed process */
#define CS_EXEC_SET_KILL            0x00200000  /* set CS_KILL on any exec'ed process */
#define CS_EXEC_SET_ENFORCEMENT     0x00400000  /* set CS_ENFORCEMENT on any exec'ed process */
#define CS_EXEC_INHERIT_SIP         0x00800000  /* set CS_INSTALLER on any exec'ed process */

#define CS_KILLED                   0x01000000  /* was killed by kernel for invalidity */
#define CS_NO_UNTRUSTED_HELPERS     0x02000000  /* kernel did not load a non-platform-binary dyld or Rosetta runtime */
#define CS_DYLD_PLATFORM            CS_NO_UNTRUSTED_HELPERS /* old name */
#define CS_PLATFORM_BINARY          0x04000000  /* this is a platform binary */
#define CS_PLATFORM_PATH            0x08000000  /* platform binary by the fact of path (osx only) */

#define CS_DEBUGGED                 0x10000000  /* process is currently or has previously been debugged and allowed to run with invalid pages */
#define CS_SIGNED                   0x20000000  /* process has a signature (may have gone invalid) */
#define CS_DEV_CODE                 0x40000000  /* code is dev signed, cannot be loaded into prod signed code (will go away with rdar://problem/28322552) */
#define CS_DATAVAULT_CONTROLLER     0x80000000  /* has Data Vault controller entitlement */

#define CS_ENTITLEMENT_FLAGS        (CS_GET_TASK_ALLOW | CS_INSTALLER | CS_DATAVAULT_CONTROLLER | CS_NVRAM_UNRESTRICTED)

#define CS_CDHASH_LEN 20

typedef enum CS_BLOB_TYPE
{
    CSSLOT_CODEDIRECTORY =   0x0,
    CSSLOT_REQUIREMENTS =     0x2,
    CSSLOT_ENTITLEMENTS =     0x5,
    CSSLOT_DER_ENTITLEMENTS = 0x7,
    CSSLOT_ALTERNATE_CODEDIRECTORIES = 0x1000, /* first alternate CodeDirectory, if any */
    CSSLOT_ALTERNATE_CODEDIRECTORY_MAX = 5,         /* max number of alternate CD slots */
    CSSLOT_ALTERNATE_CODEDIRECTORY_LIMIT = CSSLOT_ALTERNATE_CODEDIRECTORIES + CSSLOT_ALTERNATE_CODEDIRECTORY_MAX, /* one past the last */
    CSSLOT_SIGNATURESLOT =     0x10000
} CS_BLOB_TYPE;

struct CSSuperBlob {
    uint32_t magic;
    uint32_t length;
    uint32_t count;
};

struct CSBlob {
    uint32_t type;
    uint32_t offset;
};

typedef struct __CodeDirectory {
    uint32_t magic;                    /* magic number (CSMAGIC_CODEDIRECTORY) */
    uint32_t length;                /* total length of CodeDirectory blob */
    uint32_t version;                /* compatibility version */
    uint32_t flags;                    /* setup and mode flags */
    uint32_t hashOffset;            /* offset of hash slot element at 0xindex zero */
    uint32_t identOffset;            /* offset of identifier string */
    uint32_t nSpecialSlots;            /* number of special hash slots */
    uint32_t nCodeSlots;            /* number of ordinary (code) hash slots */
    uint32_t codeLimit;                /* limit to main image signature range */
    uint8_t hashSize;                /* size of each hash in bytes */
    uint8_t hashType;                /* type of hash (cdHashType* constants) */
    uint8_t platform;                /* platform identifier; zero if not platform binary */
    uint8_t    pageSize;                /* log2(page size in bytes); 0 => infinite */
    uint32_t spare2;                /* unused (must be zero) */
    /* Version 0x20100 */
    uint32_t scatterOffset;                /* offset of optional scatter vector */
    /* Version 0x20200 */
    uint32_t teamOffset;                /* offset of optional team identifier */
    /* followed by dynamic content as located by offset fields above */
} CS_CodeDirectory;

// we only care about the first two fields
typedef struct __BlobWrapper {
    uint32_t magic;                    /* magic number (CSMAGIC_CODEDIRECTORY) */
    uint32_t length;                /* total length of CodeDirectory blob */
} CS_BlobWrapper;

#define CS_MAGIC_DETACHED_SIGNATURE 0xFADE0CC1
#define CS_MAGIC_EMBEDDED_SIGNATURE 0xFADE0CC0
#define CS_MAGIC_REQUIREMENTS 0xFADE0C01
#define CS_MAGIC_CODEDIRECTORY 0xFADE0C02
#define CS_MAGIC_EMBEDDED_ENTITLEMENTS 0xFADE7171
#define CS_MAGIC_ENTITLEMENTS_DER 0xFADE7172
#define CS_MAGIC_BLOB_WRAPPER 0xFADE0B01

#define CS_HASHTYPE_SHA160_160 1
#define CS_HASHTYPE_SHA256_256 2
#define CS_HASHTYPE_SHA256_160 3
#define CS_HASHTYPE_SHA384_384 4


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

#import <CommonCrypto/CommonDigest.h>

void machoEnumerateArchs(FILE* machoFile, void (^archEnumBlock)(struct fat_arch* arch, uint32_t archMetadataOffset, uint32_t archOffset, BOOL* stop))
{
    struct mach_header_64 mh;
    fseek(machoFile,0,SEEK_SET);
    fread(&mh,sizeof(mh),1,machoFile);
    
    if(mh.magic == FAT_MAGIC || mh.magic == FAT_CIGAM)
    {
        struct fat_header fh;
        fseek(machoFile,0,SEEK_SET);
        fread(&fh,sizeof(fh),1,machoFile);
        
        for(int i = 0; i < OSSwapBigToHostInt32(fh.nfat_arch); i++)
        {
            uint32_t archMetadataOffset = sizeof(fh) + sizeof(struct fat_arch) * i;
            struct fat_arch fatArch;
            fseek(machoFile, archMetadataOffset, SEEK_SET);
            fread(&fatArch, sizeof(fatArch), 1, machoFile);
            
            BOOL stop = NO;
            archEnumBlock(&fatArch, archMetadataOffset, OSSwapBigToHostInt32(fatArch.offset), &stop);
            if(stop) break;
        }
    }
    else if(mh.magic == MH_MAGIC_64 || mh.magic == MH_CIGAM_64)
    {
        BOOL stop;
        archEnumBlock(NULL, 0, 0, &stop);
    }
}

void machoGetInfo(FILE* candidateFile, bool *isMachoOut, bool *isLibraryOut)
{
    if (!candidateFile) return;

    struct mach_header_64 mh;
    fseek(candidateFile,0,SEEK_SET);
    fread(&mh,sizeof(mh),1,candidateFile);

    bool isMacho = mh.magic == MH_MAGIC_64 || mh.magic == MH_CIGAM_64 || mh.magic == FAT_MAGIC || mh.magic == FAT_CIGAM;
    bool isLibrary = NO;
    if (isMacho && isLibraryOut) {
        __block int32_t anyArchOffset = 0;
        machoEnumerateArchs(candidateFile, ^(struct fat_arch* arch, uint32_t archMetadataOffset, uint32_t archOffset, BOOL* stop) {
            anyArchOffset = archOffset;
            *stop = YES;
        });

        fseek(candidateFile, anyArchOffset, SEEK_SET);
        fread(&mh, sizeof(mh), 1, candidateFile);

        isLibrary = OSSwapLittleToHostInt32(mh.filetype) == MH_DYLIB || OSSwapLittleToHostInt32(mh.filetype) == MH_DYLIB_STUB;
    }

    if (isMachoOut) *isMachoOut = isMacho;
    if (isLibraryOut) *isLibraryOut = isLibrary;
}

int64_t machoFindArch(FILE *machoFile, uint32_t subtypeToSearch)
{
    __block int64_t outArchOffset = -1;

    machoEnumerateArchs(machoFile, ^(struct fat_arch* arch, uint32_t archMetadataOffset, uint32_t archOffset, BOOL* stop) {
        struct mach_header_64 mh;
        fseek(machoFile, archOffset, SEEK_SET);
        fread(&mh, sizeof(mh), 1, machoFile);
        uint32_t maskedSubtype = OSSwapLittleToHostInt32(mh.cpusubtype) & ~0x80000000;
        if (maskedSubtype == subtypeToSearch) {
            outArchOffset = archOffset;
            *stop = YES;
        }
    });

    return outArchOffset;
}

int64_t machoFindBestArch(FILE *machoFile)
{
#if __arm64e__
    int64_t archOffsetCandidate = machoFindArch(machoFile, CPU_SUBTYPE_ARM64E);
    if (archOffsetCandidate < 0) {
        archOffsetCandidate = machoFindArch(machoFile, CPU_SUBTYPE_ARM64_ALL);
    }
    return archOffsetCandidate;
#else
    int64_t archOffsetCandidate = machoFindArch(machoFile, CPU_SUBTYPE_ARM64_ALL);
    return archOffsetCandidate;
#endif
}

void machoEnumerateLoadCommands(FILE *machoFile, uint32_t archOffset, void (^enumerateBlock)(struct load_command cmd, uint32_t cmdOffset))
{
    struct mach_header_64 mh;
    fseek(machoFile, archOffset, SEEK_SET);
    fread(&mh, sizeof(mh), 1, machoFile);

    uint32_t nCmds = OSSwapLittleToHostInt32(mh.ncmds);
    uint32_t sizeOfCmds = OSSwapLittleToHostInt32(mh.sizeofcmds);
    uint32_t offset = 0;
    printf("[machoEnumerateLoadCommands] About to enumerate over %u load commands (total size: 0x%X)", nCmds, sizeOfCmds);
    for (uint32_t i = 0; i < nCmds && offset < sizeOfCmds; i++) {
        uint32_t absoluteOffset = archOffset + sizeof(mh) + offset;
        struct load_command cmd;
        fseek(machoFile, absoluteOffset, SEEK_SET);
        fread(&cmd, sizeof(cmd), 1, machoFile);
        enumerateBlock(cmd, absoluteOffset);
        offset += OSSwapLittleToHostInt32(cmd.cmdsize);
    }
    printf("[machoEnumerateLoadCommands] Finished enumerating over %u load commands (total size: 0x%X)", nCmds, sizeOfCmds);
}

void machoFindCSData(FILE* machoFile, uint32_t archOffset, uint32_t* outOffset, uint32_t* outSize)
{
    machoEnumerateLoadCommands(machoFile, archOffset, ^(struct load_command cmd, uint32_t cmdOffset) {
        if (OSSwapLittleToHostInt32(cmd.cmd) == LC_CODE_SIGNATURE) {
            struct linkedit_data_command CSCommand;
            fseek(machoFile, cmdOffset, SEEK_SET);
            fread(&CSCommand, sizeof(CSCommand), 1, machoFile);
            if(outOffset) *outOffset = archOffset + OSSwapLittleToHostInt32(CSCommand.dataoff);
            if(outSize) *outSize = archOffset + OSSwapLittleToHostInt32(CSCommand.datasize);
        }
    });
}

NSString *processRpaths(NSString *path, NSString *tokenName, NSArray *rpaths)
{
    if (!rpaths) return path;

    if ([path containsString:tokenName]) {
        for (NSString *rpath in rpaths) {
            NSString *testPath = [path stringByReplacingOccurrencesOfString:tokenName withString:rpath];
            if ([[NSFileManager defaultManager] fileExistsAtPath:testPath]) {
                return testPath;
            }
        }
    }
    return path;
}

NSString *resolveLoadPath(NSString *loadPath, NSString *machoPath, NSString *sourceExecutablePath, NSArray *rpaths)
{
    if (!loadPath || !machoPath) return nil;

    NSString *processedPath = processRpaths(loadPath, @"@rpath", rpaths);
    processedPath = processRpaths(processedPath, @"@executable_path", rpaths);
    processedPath = processRpaths(processedPath, @"@loader_path", rpaths);
    processedPath = [processedPath stringByReplacingOccurrencesOfString:@"@executable_path" withString:[sourceExecutablePath stringByDeletingLastPathComponent]];
    processedPath = [processedPath stringByReplacingOccurrencesOfString:@"@loader_path" withString:[machoPath stringByDeletingLastPathComponent]];

    return processedPath;
}

void _machoEnumerateDependencies(FILE *machoFile, uint32_t archOffset, NSString *machoPath, NSString *sourceExecutablePath, NSMutableSet *enumeratedCache, void (^enumerateBlock)(NSString *dependencyPath))
{
    if (!enumeratedCache) enumeratedCache = [NSMutableSet new];

    // First iteration: Collect rpaths
    NSMutableArray* rpaths = [NSMutableArray new];
    machoEnumerateLoadCommands(machoFile, archOffset, ^(struct load_command cmd, uint32_t cmdOffset) {
        if (OSSwapLittleToHostInt32(cmd.cmd) == LC_RPATH) {
            struct rpath_command rpathCommand;
            fseek(machoFile, cmdOffset, SEEK_SET);
            fread(&rpathCommand, sizeof(rpathCommand), 1, machoFile);

            size_t stringLength = OSSwapLittleToHostInt32(rpathCommand.cmdsize) - sizeof(rpathCommand);
            char* rpathC = malloc(stringLength);
            fseek(machoFile, cmdOffset + OSSwapLittleToHostInt32(rpathCommand.path.offset), SEEK_SET);
            fread(rpathC,stringLength,1,machoFile);
            NSString *rpath = [NSString stringWithUTF8String:rpathC];
            free(rpathC);

            NSString *resolvedRpath = resolveLoadPath(rpath, machoPath, sourceExecutablePath, nil);
            if (resolvedRpath) {
                [rpaths addObject:resolvedRpath];
            }
        }
    });

    // Second iteration: Find dependencies
    machoEnumerateLoadCommands(machoFile, archOffset, ^(struct load_command cmd, uint32_t cmdOffset) {
        uint32_t cmdId = OSSwapLittleToHostInt32(cmd.cmd);
        if (cmdId == LC_LOAD_DYLIB || cmdId == LC_LOAD_WEAK_DYLIB || cmdId == LC_REEXPORT_DYLIB) {
            struct dylib_command dylibCommand;
            fseek(machoFile, cmdOffset, SEEK_SET);
            fread(&dylibCommand,sizeof(dylibCommand),1,machoFile);
            size_t stringLength = OSSwapLittleToHostInt32(dylibCommand.cmdsize) - sizeof(dylibCommand);
            char *imagePathC = malloc(stringLength);
            fseek(machoFile, cmdOffset + OSSwapLittleToHostInt32(dylibCommand.dylib.name.offset), SEEK_SET);
            fread(imagePathC, stringLength, 1, machoFile);
            NSString *imagePath = [NSString stringWithUTF8String:imagePathC];
            free(imagePathC);

            BOOL inDSC = _dyld_shared_cache_contains_path(imagePath.fileSystemRepresentation);
            if (!inDSC) {
                NSString *resolvedPath = resolveLoadPath(imagePath, machoPath, sourceExecutablePath, rpaths);
                resolvedPath = [[resolvedPath stringByResolvingSymlinksInPath] stringByStandardizingPath];
                if (![enumeratedCache containsObject:resolvedPath] && [[NSFileManager defaultManager] fileExistsAtPath:resolvedPath]) {
                    [enumeratedCache addObject:resolvedPath];
                    enumerateBlock(resolvedPath);

                    printf("[_machoEnumerateDependencies] Found depdendency %s, recursively enumerating over it...", resolvedPath.UTF8String);
                    FILE *nextFile = fopen(resolvedPath.fileSystemRepresentation, "rb");
                    if (nextFile) {
                        BOOL nextFileIsMacho = NO;
                        machoGetInfo(nextFile, &nextFileIsMacho, NULL);
                        if (nextFileIsMacho) {
                            int64_t nextBestArchCandidate = machoFindBestArch(nextFile);
                            if (nextBestArchCandidate >= 0) {
                                _machoEnumerateDependencies(nextFile, nextBestArchCandidate, resolvedPath, sourceExecutablePath, enumeratedCache, enumerateBlock);
                            }
                            else {
                                printf("[_machoEnumerateDependencies] Failed to find best arch of dependency %s", resolvedPath.UTF8String);
                            }
                        }
                        else {
                            printf("[_machoEnumerateDependencies] Dependency %s does not seem to be a macho", resolvedPath.UTF8String);
                        }
                        fclose(nextFile);
                    }
                    else {
                        printf("[_machoEnumerateDependencies] Dependency %s does not seem to exist, maybe path resolving failed?", resolvedPath.UTF8String);
                    }
                }
                else {
                    if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedPath]) {
                        printf("[_machoEnumerateDependencies] Skipped dependency %s, non existant", resolvedPath.UTF8String);
                    }
                    else {
                        printf("[_machoEnumerateDependencies] Skipped dependency %s, already cached", resolvedPath.UTF8String);
                    }
                }
            }
            else {
                printf("[_machoEnumerateDependencies] Skipped dependency %s, in dyld_shared_cache", imagePath.UTF8String);
            }
        }
    });
}

void machoEnumerateDependencies(FILE *machoFile, uint32_t archOffset, NSString *machoPath, void (^enumerateBlock)(NSString *dependencyPath))
{
    _machoEnumerateDependencies(machoFile, archOffset, machoPath, machoPath, nil, enumerateBlock);
}

unsigned CSCodeDirectoryRank(CS_CodeDirectory *cd) {
    // The supported hash types, ranked from least to most preferred. From XNU's
    // bsd/kern/ubc_subr.c.
    static uint32_t rankedHashTypes[] = {
        CS_HASHTYPE_SHA160_160,
        CS_HASHTYPE_SHA256_160,
        CS_HASHTYPE_SHA256_256,
        CS_HASHTYPE_SHA384_384,
    };
    // Define the rank of the code directory as its index in the array plus one.
    for (unsigned i = 0; i < sizeof(rankedHashTypes) / sizeof(rankedHashTypes[0]); i++) {
        if (rankedHashTypes[i] == cd->hashType) {
            return (i + 1);
        }
    }
    return 0;
}

void machoCSDataEnumerateBlobs(FILE *machoFile, uint32_t CSDataStart, uint32_t CSDataSize, void (^enumerateBlock)(struct CSBlob blobDescriptor, uint32_t blobDescriptorOffset, BOOL *stop))
{
    struct CSSuperBlob superBlob;
    fseek(machoFile, CSDataStart, SEEK_SET);
    fread(&superBlob, sizeof(superBlob), 1, machoFile);

    uint32_t blobLength = OSSwapBigToHostInt32(superBlob.length);
    uint32_t blobCount = OSSwapBigToHostInt32(superBlob.count);

    if ((CSDataStart + blobLength) > (CSDataStart + CSDataSize)) return;
    if ((sizeof(struct CSSuperBlob) + blobCount * sizeof(struct CSBlob)) > blobLength) return;

    for (int i = 0; i < blobCount; i++) {
        uint32_t blobDescriptorOffset = CSDataStart + sizeof(struct CSSuperBlob) + (i * sizeof(struct CSBlob));
        struct CSBlob blobDescriptor;
        fseek(machoFile, blobDescriptorOffset, SEEK_SET);
        fread(&blobDescriptor, sizeof(blobDescriptor), 1, machoFile);

        BOOL stop = NO;
        enumerateBlock(blobDescriptor, blobDescriptorOffset, &stop);
        if (stop) return;
    }
}

NSData *codeDirectoryCalculateCDHash(CS_CodeDirectory *cd, void *data, size_t size)
{
    uint8_t cdHashC[CS_CDHASH_LEN];

    switch (cd->hashType) {
        case CS_HASHTYPE_SHA160_160: {
            CC_SHA1(data, (CC_LONG)size, cdHashC);
            break;
        }
        
        case CS_HASHTYPE_SHA256_256:
        case CS_HASHTYPE_SHA256_160: {
            uint8_t fullHash[CC_SHA256_DIGEST_LENGTH];
            CC_SHA256(data, (CC_LONG)size, fullHash);
            memcpy(cdHashC, fullHash, CS_CDHASH_LEN);
            break;
        }

        case CS_HASHTYPE_SHA384_384: {
            uint8_t fullHash[CC_SHA384_DIGEST_LENGTH];
            CC_SHA256(data, (CC_LONG)size, fullHash);
            memcpy(cdHashC, fullHash, CS_CDHASH_LEN);
            break;
        }

        default:
        return nil;
    }

    return [NSData dataWithBytes:cdHashC length:CS_CDHASH_LEN];
}

NSData *machoCSDataCalculateCDHash(FILE *machoFile, uint32_t CSDataStart, uint32_t CSDataSize)
{
    __block CS_CodeDirectory bestCd = { 0 };
    __block unsigned bestCdRank = 0;
    __block uint32_t cdOffset = 0;

    machoCSDataEnumerateBlobs(machoFile, CSDataStart, CSDataSize, ^(struct CSBlob blobDescriptor, uint32_t blobDescriptorOffset, BOOL *stop) {
        uint32_t blobType = OSSwapBigToHostInt32(blobDescriptor.type);
        if (blobType == CSSLOT_CODEDIRECTORY || ((CSSLOT_ALTERNATE_CODEDIRECTORIES <= blobType && blobType < CSSLOT_ALTERNATE_CODEDIRECTORY_LIMIT))) {
            uint32_t blobDataOffset = OSSwapBigToHostInt32(blobDescriptor.offset);
            uint32_t blobMagic = 0;

            if ((blobDataOffset + sizeof(CS_CodeDirectory)) > CSDataSize) {
                // file corrupted, abort
                *stop = YES;
                return;
            }

            fseek(machoFile, CSDataStart + blobDataOffset, SEEK_SET);
            fread(&blobMagic, sizeof(blobMagic), 1, machoFile);
            if (OSSwapBigToHostInt32(blobMagic) == CS_MAGIC_CODEDIRECTORY) {
                CS_CodeDirectory cd;
                fseek(machoFile, CSDataStart + blobDataOffset, SEEK_SET);
                fread(&cd, sizeof(cd), 1, machoFile);

                unsigned codeDirectoryRank = CSCodeDirectoryRank(&cd);
                if (codeDirectoryRank > bestCdRank) {
                    bestCdRank = codeDirectoryRank;
                    bestCd = cd;
                    cdOffset = OSSwapBigToHostInt32(blobDescriptor.offset);
                }
            }
        }
    });

    if (!cdOffset) return nil;

    uint32_t cdDataLength = OSSwapBigToHostInt32(bestCd.length);
    if (((cdOffset + cdDataLength) > CSDataSize) || cdDataLength == 0) {
        // file corrupted, abort
        return nil;
    }

    uint8_t *cdData = malloc(cdDataLength);
    if (!cdData) return nil;

    fseek(machoFile, CSDataStart + cdOffset, SEEK_SET);
    fread(cdData, cdDataLength, 1, machoFile);

    NSData *cdHash = codeDirectoryCalculateCDHash(&bestCd, cdData, cdDataLength);
    free(cdData);
    return cdHash;
}

bool machoCSDataIsAdHocSigned(FILE *machoFile, uint32_t CSDataStart, uint32_t CSDataSize)
{
    __block bool blobWrapperFound = false;

    machoCSDataEnumerateBlobs(machoFile, CSDataStart, CSDataSize, ^(struct CSBlob blobDescriptor, uint32_t blobDescriptorOffset, BOOL *stop) {
        uint32_t blobType = OSSwapBigToHostInt32(blobDescriptor.type);
        if (blobType == CSSLOT_SIGNATURESLOT) {
            uint32_t blobDataOffset = OSSwapBigToHostInt32(blobDescriptor.offset);

            if ((blobDataOffset + sizeof(CS_BlobWrapper)) > CSDataSize) {
                // file corrupted, abort
                *stop = YES;
                return;
            }

            CS_BlobWrapper blobWrapper;
            fseek(machoFile, CSDataStart + blobDataOffset, SEEK_SET);
            fread(&blobWrapper, sizeof(blobWrapper), 1, machoFile);
            if (OSSwapBigToHostInt32(blobWrapper.magic) == CS_MAGIC_BLOB_WRAPPER) {
                if (OSSwapBigToHostInt32(blobWrapper.length) > 8) {
                    blobWrapperFound = true;
                    *stop = YES;
                }
            }
        }
    });

    return !blobWrapperFound;
}

int evaluateSignature(NSURL* fileURL, NSData **cdHashOut, BOOL *isAdhocSignedOut)
{
    if (!fileURL || (!cdHashOut && !isAdhocSignedOut)) return 1;
    if (![fileURL checkResourceIsReachableAndReturnError:nil]) return 2;

    FILE *machoFile = fopen(fileURL.fileSystemRepresentation, "rb");
    if (!machoFile) return 3;

    int ret = 0;

    BOOL isMacho = NO;
    machoGetInfo(machoFile, &isMacho, NULL);

    if (!isMacho) {
        fclose(machoFile);
        return 4;
    }

    int64_t archOffset = machoFindBestArch(machoFile);
    if (archOffset < 0) {
        fclose(machoFile);
        return 5;
    }

    uint32_t CSDataStart = 0, CSDataSize = 0;
    machoFindCSData(machoFile, archOffset, &CSDataStart, &CSDataSize);
    if (CSDataStart == 0 || CSDataSize == 0) {
        fclose(machoFile);
        return 6;
    }

    BOOL isAdhocSigned = machoCSDataIsAdHocSigned(machoFile, CSDataStart, CSDataSize);
    if (isAdhocSignedOut) {
        *isAdhocSignedOut = isAdhocSigned;
    }

    // we only care about the cd hash on stuff that's already verified to be ad hoc signed
    if (isAdhocSigned && cdHashOut) {
        *cdHashOut = machoCSDataCalculateCDHash(machoFile, CSDataStart, CSDataSize);
    }

    fclose(machoFile);
    return 0;
}

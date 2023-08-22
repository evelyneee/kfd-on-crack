//
//  JBDTCPage.m
//  jailbreakd
//
//  Created by Serena on 15/08/2023.
//

#import <Foundation/Foundation.h>
#import "JBDTCPage.h"
#import "Bridge.h"
#import "boot_info.h"
#import "trustcache.h"
#include "krw_remote.h"

void tcPagesChanged(void) {
    NSMutableArray *tcAllocations = [NSMutableArray new];
    for (JBDTCPage *page in gTCPages) {
        @autoreleasepool {
            [tcAllocations addObject:@(page.kaddr)];
        }
    }
    
    bootInfo_setObject(@"trustcache_allocations", tcAllocations);
    bootInfo_setObject(@"trustcache_unused_allocations", gTCUnusedAllocations);
}

@implementation JBDTCPage

- (instancetype)initWithKernelAddress:(uint64_t)kaddr {
    self = [super init];
    if (self) {
        _page = NULL;
        self.kaddr = kaddr;
    }
    return self;
}

- (instancetype)initAllocateAndLink {
    self = [super init];
    if (self) {
        _page = NULL;
        self.kaddr = 0;
        if (![self allocateInKernel]) return nil;
        [self linkInKernel];
    }
    return self;
}

- (void)setKaddr:(uint64_t)kaddr {
    _kaddr = kaddr;
    
#warning add kvtouaddr code here otherwise this still won't work
    if (kaddr) {
        NSLog(@"seting page\n");
        _page = malloc(0x400);
        
    } else {
        _page = 0;
    }
}

-(BOOL) allocateInKernel {
    uint64_t kaddr;
    if (gTCUnusedAllocations.count != 0) {
        kaddr = gTCUnusedAllocations.firstObject.unsignedLongLongValue;
        [gTCUnusedAllocations removeObjectAtIndex:0];
    } else {
        kaddr = jbd_dirty_kalloc(0x400);
    }
    
    if (kaddr == 0) return NO;
    self.kaddr = kaddr;
    
    _page->nextPtr = 0;
    _page->selfPtr = kaddr + 0x10;
    _page->file.version = 1;
    uuid_generate(_page->file.uuid);
    _page->file.length = 0;
    
    [gTCPages addObject:self];
    
    tcPagesChanged();
    
    return YES;
}

- (void)linkInKernel {
    BOOL res = trustCacheListAdd(self.kaddr);
    if (res) {
        NSLog(@"linkInKernel succeeded for kaddr %lld\n", self.kaddr);
    } else {
        NSLog(@"linkInKernel failed!");
    }
}

- (void)unlinkAndFree {
    [self unlinkInkernel];
    [self freeInkernel];
}

-(void)unlinkInkernel {
    trustCacheListRemove(self.kaddr);
}

-(void)freeInkernel {
    if (self.kaddr == 0) return;
    
    [gTCUnusedAllocations addObject:@(self.kaddr)];
    self.kaddr = 0;
    
    [gTCPages removeObject:self];
    tcPagesChanged();
}

- (uint32_t)amountOfSlotsLeft {
    return TC_ENTRY_COUNT_PER_PAGE - _page->file.length;
}

- (void)sort {
    qsort(_page->file.entries, _page->file.length, sizeof(trustcache_entry), tcentryComparator);
}

- (BOOL)addEntry:(trustcache_entry)entry {
    uint32_t index = _page->file.length;
    
    if (index >= TC_ENTRY_COUNT_PER_PAGE)
        return NO;
    
    _page->file.entries[index] = entry;
    _page->file.length++;
    
    return YES;
}

// This method only works when the entries are sorted, so the caller needs to ensure they are
- (int64_t)_indexOfEntry:(trustcache_entry)entry
{
    trustcache_entry *entries = _page->file.entries;
    int32_t count = _page->file.length;
    int32_t left = 0;
    int32_t right = count - 1;

    while (left <= right) {
        int32_t mid = (left + right) / 2;
        int32_t cmp = memcmp(entry.hash, entries[mid].hash, CS_CDHASH_LEN);
        if (cmp == 0) {
            return mid;
        }
        if (cmp < 0) {
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }
    NSLog(@"%s: failed to find index of given entry.", __PRETTY_FUNCTION__);
    return -1;
}

- (BOOL)removeEntry:(trustcache_entry)entry {
    int64_t entryIndexOrNot = [self _indexOfEntry:entry];
    if (entryIndexOrNot == -1) return NO; // Entry isn't in here, do nothing
    uint32_t entryIndex = (uint32_t)entryIndexOrNot;
    
    memset(_page->file.entries[entryIndex].hash, 0xFF, CS_CDHASH_LEN);
    [self sort];
    _page->file.length--;
    
    return YES;
}

@end

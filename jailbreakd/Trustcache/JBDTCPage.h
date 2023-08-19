//
//  JBDTCPage.h
//  kfd
//
//  Created by Serena on 15/08/2023.
//  

#ifndef JBDTCPage_h
#define JBDTCPage_h

#import <Foundation/Foundation.h>

#import "trustcache_structs.h"

// 742 cdhashes fit into one page
#define TC_ENTRY_COUNT_PER_PAGE 742

@class JBDTCPage;

NSMutableArray<JBDTCPage *> *gTCPages;
NSMutableArray<NSNumber *> *gTCUnusedAllocations;

BOOL tcPagesRecover(void);
void tcPagesChanged(void);


@interface JBDTCPage : NSObject
{
    trustcache_page* _page;
}

@property (nonatomic) uint64_t kaddr;

- (instancetype)initWithKernelAddress:(uint64_t)kaddr;
- (instancetype)initAllocateAndLink;

- (void)sort;
- (uint32_t)amountOfSlotsLeft;
- (BOOL)addEntry:(trustcache_entry)entry;
- (BOOL)removeEntry:(trustcache_entry)entry;

- (void)unlinkAndFree;

@end

#endif /* JBDTCPage_h */


#include <mach/vm_map.h>
#include <mach/mach.h>
#include <stdlib.h>

#include "libkfd.h"
#include "perf.h"

struct userland_page {
    vm_address_t ua;
    uint64_t pa;
    uint64_t kva;
};

int compareUserlandPageByKVA(const void* a, const void* b)
{
    const struct userland_page *pageA = (const struct userland_page *)a;
    const struct userland_page *pageB = (const struct userland_page *)b;
    if (pageA->kva < pageB->kva) {
        return -1;
    }
    else if (pageA->kva > pageB->kva) {
        return 1;
    }
    else {
        return 0;
    }
}

struct userland_page *findAdjacentPages(struct userland_page *pages, uint64_t pageCount, uint64_t findCount)
{
    if (pageCount == 0) return 0;
    qsort(pages, pageCount, sizeof(struct userland_page), compareUserlandPageByKVA);
    uint64_t adjacent = 1;
    uint64_t prevPage = pages[0].kva;
    for (uint64_t i = 1; i < pageCount; i++) {
        if ((prevPage + PAGE_SIZE) == pages[i].kva) {
            adjacent++;
            if (adjacent == findCount) {
                //printf("found %llu adjacent pages (%llu - %llu)\n", adjacent, i-findCount+1, i);
                return &pages[i-findCount+1];
            }
        }
        else {
            /*if (adjacent > 1) {
                printf("found %llu adjacent pages (%llu - %llu)\n", adjacent, i-adjacent, i-1);
            }*/
            //printf("did not find adjacent pages (%llu - %llu)\n", i-adjacent, i);
            adjacent = 1;
        }
        prevPage = pages[i].kva;
    }
    return NULL;
}

struct userland_page *allocateContigonousPages(uint64_t pageCount)
{
    uint64_t allocationPageCount = pageCount * 5000;
    struct userland_page allocatedPages[allocationPageCount];
    struct userland_page *adjacentPages;

    while (1) {
        vm_address_t pacAllocationUaddr = 0;
        kern_return_t kr = vm_allocate(mach_task_self(), &pacAllocationUaddr, PAGE_SIZE*allocationPageCount, VM_FLAGS_ANYWHERE);
        if (kr != KERN_SUCCESS) {
            printf("allocation failed\n");
            continue;
        }

        // Fault in
        uint64_t *pacAllocationUaddrPtr = (uint64_t *)pacAllocationUaddr;
        memset(pacAllocationUaddrPtr, 0xFF, PAGE_SIZE*allocationPageCount);

        for (uint64_t i = 0; i < allocationPageCount; i++) {
            uint64_t ua = pacAllocationUaddr + (PAGE_SIZE*i);
            uint64_t pa = vtophys(kcall_kfd, ua);
            uint64_t kva = phystokv(kcall_kfd, pa);
            
            allocatedPages[i].ua = ua;
            allocatedPages[i].pa = pa;
            allocatedPages[i].kva = kva;
        }

        adjacentPages = findAdjacentPages(allocatedPages, allocationPageCount, pageCount);
        if (adjacentPages) {
            break;
        }

        vm_deallocate(mach_task_self(), pacAllocationUaddr, PAGE_SIZE*allocationPageCount);
    }

    uint64_t adjacentStartIdx = (&adjacentPages[0] - &allocatedPages[0]);
    uint64_t adjacentEndIdx = adjacentStartIdx + (pageCount-1);

    for (uint64_t i = 0; i < allocationPageCount; i++) {
        if (i < adjacentStartIdx || i > adjacentEndIdx) {
            // Free all pages except for the adjacent ones
            vm_deallocate(mach_task_self(), allocatedPages[i].ua, PAGE_SIZE);
        }
    }

    struct userland_page *output = malloc(pageCount * sizeof(struct userland_page));
    memcpy(output, adjacentPages, pageCount * sizeof(struct userland_page));
    return output;
}

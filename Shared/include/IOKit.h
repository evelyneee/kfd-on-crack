//
//  IOKit.h
//  electra
//
//  Created by Jamie on 27/01/2018.
//  Copyright © 2018 Electra Team. All rights reserved.
//

#ifndef IOKit_h
#define IOKit_h

#include <CoreFoundation/CoreFoundation.h>

__BEGIN_DECLS

kern_return_t mach_vm_read(
                           vm_map_t target_task,
                           mach_vm_address_t address,
                           mach_vm_size_t size,
                           vm_offset_t *data,
                           mach_msg_type_number_t *dataCnt);

typedef mach_port_t     io_service_t;
typedef mach_port_t     io_connect_t;
typedef mach_port_t     io_object_t;
typedef io_object_t     io_registry_entry_t;
typedef char            io_name_t[128];
typedef char            io_struct_inband_t[4096];
typedef UInt32          IOOptionBits;

extern const mach_port_t kIOMasterPortDefault;

#ifndef IO_OBJECT_NULL
#define IO_OBJECT_NULL (0)
#endif

#ifndef sys_iokit
#define sys_iokit                err_system(0x38)
#endif /* sys_iokit */

#define sub_iokit_common         err_sub(0)
#define sub_iokit_usb              err_sub(1)
#define sub_iokit_firewire     err_sub(2)
#define sub_iokit_reserved       err_sub(-1)
#define    iokit_common_err(return) (sys_iokit|sub_iokit_common|return)
#define kIOReturnBadArgument     iokit_common_err(706) // invalid argument

io_service_t
IOServiceGetMatchingService(
                            mach_port_t  _masterPort,
                            CFDictionaryRef  matching);

CFTypeRef
IORegistryEntryCreateCFProperty(io_registry_entry_t  entry,
                                CFStringRef          key,
                                CFAllocatorRef      allocator,
                                IOOptionBits        options);

kern_return_t
IOServiceOpen(
              io_service_t  service,
              task_port_t   owningTask,
              uint32_t      type,
              io_connect_t* connect );

kern_return_t IOServiceClose(io_connect_t client);

io_service_t
IOServiceGetMatchingService(
                            mach_port_t  _masterPort,
                            CFDictionaryRef  matching);

CFMutableDictionaryRef
IOServiceMatching(const char* name);

kern_return_t
IORegistryEntrySetCFProperties(
                               io_registry_entry_t    entry,
                               CFTypeRef         properties );
kern_return_t
IORegistryEntryGetProperty(
                           io_registry_entry_t    entry,
                           const io_name_t        propertyName,
                           io_struct_inband_t    buffer,
                           uint32_t          * size );
io_registry_entry_t IORegistryEntryFromPath(
                                mach_port_t port,
                                const char *path );
kern_return_t IOObjectRelease(io_object_t object);

kern_return_t IOConnectTrap6(io_connect_t connect, uint32_t index, uintptr_t p1, uintptr_t p2, uintptr_t p3, uintptr_t p4, uintptr_t p5, uintptr_t p6);
kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t *outsize);
kern_return_t mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);
kern_return_t mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);
kern_return_t mach_vm_deallocate(vm_map_t target, mach_vm_address_t address, mach_vm_size_t size);
kern_return_t mach_vm_remap(vm_map_t dst, mach_vm_address_t *dst_addr, mach_vm_size_t size, mach_vm_offset_t mask, int flags, vm_map_t src, mach_vm_address_t src_addr, boolean_t copy, vm_prot_t *cur_prot, vm_prot_t *max_prot, vm_inherit_t inherit);
kern_return_t IOConnectCallMethod(io_connect_t client, uint32_t selector, const uint64_t *in, uint32_t inCnt, const void *inStruct, size_t inStructCnt, uint64_t *out, uint32_t *outCnt, void *outStruct, size_t *outStructCnt);

__END_DECLS

#endif /* IOKit_h */

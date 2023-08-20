//
//  krw_remote.h
//  kfd
//
//  Created by Serena on 19/08/2023.
//  

#ifndef krw_remote_h
#define krw_remote_h

#include <stdint.h>

uint64_t kckr64(uint64_t);
uint64_t kckw64(uint64_t virt, uint64_t what);
uint64_t jbd_kalloc(size_t);
uint64_t jbd_dirty_kalloc(size_t);
uint64_t proc_of_pid_jbd(pid_t pid);

#endif /* krw_remote_h */

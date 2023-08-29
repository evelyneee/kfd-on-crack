//
//  pplrw.h
//  kfd
//
//  Created by Serena on 28/08/2023.
//  

#ifndef pplrw_h
#define pplrw_h

int physwritebuf(uint64_t kfd, uint64_t physaddr, const void* input, size_t size);

#endif /* pplrw_h */

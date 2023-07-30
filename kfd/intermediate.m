//
//  intermediate.c
//  kfd
//
//  Created by Lars Fröder on 23.07.23.
//

#include "libkfd.h"

u64 kopen_intermediate(u64 puaf_pages, u64 puaf_method, u64 kread_method, u64 kwrite_method)
{
    return kopen(puaf_pages, puaf_method, kread_method, kwrite_method);
}

void kclose_intermediate(u64 kfd)
{
    return kclose(kfd);
}

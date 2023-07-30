/*
 * Copyright (c) 2023 Félix Poulin-Bélanger. All rights reserved.
 */

#include <stdint.h>

uint64_t kopen_intermediate(uint64_t puaf_pages, uint64_t puaf_method, uint64_t kread_method, uint64_t kwrite_method);
void kclose_intermediate(uint64_t kfd);

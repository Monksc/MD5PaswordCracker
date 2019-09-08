//
//  gpu_for_cpu.h
//  ReverseMD5Metal
//
//  Created by Cameron Monks on 8/23/19.
//  Copyright © 2019 Cameron Monks. All rights reserved.
//

#ifndef gpu_for_cpu_h
#define gpu_for_cpu_h

#include <stdio.h>

#define kernel
#define device
#define thread
#define bool char
#define true 1
#define false 0

kernel void solve_md5_cpu(device const unsigned* hash_map,
                      device const char* choices_arr,
                      device bool* doesItWork,
                      device const uint* additionToIndex,
                      uint index_of_grid);

#endif /* gpu_for_cpu_h */

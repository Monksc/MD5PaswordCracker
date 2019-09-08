//
//  gpu_for_cpu.c
//  ReverseMD5Metal
//
//  Created by Cameron Monks on 8/23/19.
//  Copyright © 2019 Cameron Monks. All rights reserved.
//

#include "gpu_for_cpu.h"
#define MAX_PASSWORD_CHARACTERS 16
#define MAX_ENCRYPTED_PASSWORD_CHARACTERS 32


void IntegerToAsci2(uint i, device const char * arr, thread char * str) {
    
    while (true) {
        if (*arr == 0) return;
        if (*arr == 1) arr++;
        
        unsigned nLen = 0;
        while (arr[nLen] != 0 && arr[nLen] != 1) {
            nLen++;
        }
        
        unsigned r = i % nLen;
        
        *str = arr[r];
        str++;
        
        i = i / nLen;
        arr += nLen;
        //IntegerToAsci2(i/nLen, arr+nLen, str);
    }
}


// hash map [size, pointer to string/0, size_index+1 start of first string, end of string, 0 end of list/1 end of string]
// choices_arr multidemnsional array [0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" choices for first value in password
kernel void solve_md5_cpu(device const unsigned* hash_map,
    device const char* choices_arr,
    device bool* doesItWork,
    device const uint* additionToIndex,
    uint index_of_grid)
{
    
    uint index = index_of_grid + *additionToIndex;
    
    unsigned str_len = additionToIndex[1];// length(choices_arr);
    char str[MAX_PASSWORD_CHARACTERS + 1];
    str[str_len] = '\0';
    
    IntegerToAsci2(index, choices_arr, str);
    
    //execl("/bin/ls", "ls", "-all");
    
    char encryptedMDMsg[MAX_ENCRYPTED_PASSWORD_CHARACTERS + 1];
    for (unsigned i = 0; i < MAX_ENCRYPTED_PASSWORD_CHARACTERS + 1; i++) {
        encryptedMDMsg[i] = '\0';
    }
    
    md5((thread const char *) str, str_len, (thread char *) encryptedMDMsg);
    
    doesItWork[index_of_grid] = HashSetArrayContains(hash_map, encryptedMDMsg);
}

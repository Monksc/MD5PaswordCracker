//
//  shader.metal
//  ReverseMD5Metal
//
//  Created by Cameron Monks on 7/16/19.
//  Copyright © 2019 Cameron Monks. All rights reserved.
//

#include <metal_stdlib>
#define MAX_PASSWORD_CHARACTERS 16
#define MAX_ENCRYPTED_PASSWORD_CHARACTERS 32
//#include "hash_map.h"

using namespace metal;

typedef unsigned Digest[4];

unsigned f0( unsigned abcd[] ){
    return ( abcd[1] & abcd[2]) | (~abcd[1] & abcd[3]);}

unsigned f1( unsigned abcd[] ){
    return ( abcd[3] & abcd[1]) | (~abcd[3] & abcd[2]);}

unsigned f2( unsigned abcd[] ){
    return  abcd[1] ^ abcd[2] ^ abcd[3];}

unsigned f3( unsigned abcd[] ){
    return abcd[2] ^ (abcd[1] |~ abcd[3]);}

unsigned ff(unsigned abcd[], unsigned char index) {
    switch (index) {
        case 0:
            return f0(abcd);
        case 1:
            return f1(abcd);
        case 2:
            return f2(abcd);
        case 3:
            return f3(abcd);
        default:
            break;
    }
    
    return -1;
}

void my_memcpy(thread char * str1, thread const char * str2, unsigned length) {
    for (unsigned i = 0; i < length; i++) {
        str1[i] = str2[i];
    }
}


// Rotate v Left by amt bits
unsigned rol( unsigned v, short amt )
{
    unsigned  msk1 = (1<<amt) -1;
    return ((v>>(32-amt)) & msk1) | ((v<<amt) & ~msk1);
}


void toHex(thread char * str, uint8_t value) {
    
    char number_system[] = "0123456789abcdef";
    
    str[1] = number_system[value % 16];
    str[0] = number_system[(value/16) % 16];
}

void md5(thread const char *msg, unsigned mlen, thread char * answer)
{
    Digest h0 = { 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476 };
    //    static Digest h0 = { 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
    //DgstFctn ff[] = { &f0, &f1, &f2, &f3 };
    short M[] = { 1, 5, 3, 7 };
    short O[] = { 0, 1, 5, 0 };
    short rot0[] = { 7,12,17,22};
    short rot1[] = { 5, 9,14,20};
    short rot2[] = { 4,11,16,23};
    short rot3[] = { 6,10,15,21};
    thread short *rots[] = {rot0, rot1, rot2, rot3 };
    uint32_t k[] = {
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
        0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
        0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
        0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
        0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
        0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
        0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
        0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
        0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
    };
    
    Digest h;
    Digest abcd;
    unsigned char fctn_index;
    short m, o, g;
    unsigned f;
    thread short *rotn;
    unsigned mmw[16];
    thread char * mmb = (thread char *) mmw;
    
    int os = 0;
    int grp, grps, q, p;
    unsigned char msg2[64 * (1 + (MAX_PASSWORD_CHARACTERS+8)/64)];
    
    for (q=0; q<4; q++) h[q] = h0[q];   // initialize
    
    {
        grps  = 1 + (mlen+8)/64;
        //msg2 = malloc( 64*grps);
        //memcpy( msg2, msg, mlen);
        my_memcpy((thread char *) msg2, (thread const char *) msg, mlen);
        msg2[mlen] = (unsigned char)0x80;
        q = mlen + 1;
        while (q < 64*grps){ msg2[q] = 0; q++ ; }
        {
            //            unsigned char t;
            unsigned w;
            w = 8*mlen;
            //            t = u.b[0]; u.b[0] = u.b[3]; u.b[3] = t;
            //            t = u.b[1]; u.b[1] = u.b[2]; u.b[2] = t;
            q -= 8;
            //memcpy(msg2+q, &w, 4 );
            my_memcpy((thread char *) msg2+q, (thread const char *) &w, 4 );
        }
    }
    
    for (grp=0; grp<grps; grp++)
    {
        //memcpy( mm.b, msg2+os, 64);
        my_memcpy( (thread char *) mmb, (thread const char *) msg2+os, 64);
        for(q=0;q<4;q++) abcd[q] = h[q];
        for (p = 0; p<4; p++) {
            fctn_index = p;
            rotn = rots[p];
            m = M[p]; o= O[p];
            for (q=0; q<16; q++) {
                g = (m*q + o) % 16;
                f = abcd[1] + rol( abcd[0]+ ff(abcd, fctn_index) + k[q+16*p] + mmw[g], rotn[q%4]);
                
                abcd[0] = abcd[3];
                abcd[3] = abcd[2];
                abcd[2] = abcd[1];
                abcd[1] = f;
            }
        }
        for (p=0; p<4; p++)
            h[p] += abcd[p];
        os += 64;
    }
    
    //if( msg2 )
    //free( msg2 );
    thread char * buffer = (thread char *) h;
    for (unsigned i = 0; i < 16; i++) {
        toHex(answer + i*2, buffer[i]);
    }
    //return h;
}

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

unsigned length(device const char * arr) {
    
    unsigned size = 1;
    for (unsigned i = 0; arr[i] != 0; i++) {
        if (arr[i] == 1) {
            size++;
        }
    }
    return size;
}

unsigned hash(const thread char * str) {
    
    unsigned int hash = 1315423911;
    while (*str != '\0') {
        hash ^= (hash << 5) + *str;
        str++;
    }
    
    return hash;
}

bool HashSetArrayContains(device const unsigned* arr, thread const char * str) {
    
    unsigned h = (hash(str) % arr[0]) + 1;
    
    unsigned itr = arr[h];
    if (itr == 0) return false;
    
    while (true) {
        
        // loop through while str[itr..<index] == str[0..<index]
        unsigned index = 0;
        while (arr[itr+index] == str[index] && str[index] != '\0' && arr[itr+index] != 1 && arr[itr+index] != 0) {
            index++;
        }
        
        // check if arr[itr..<index] == str
        if ((arr[itr+index] == 0 || arr[itr+index] == 1) && str[index] == '\0') {
            return true;
        }
        
        // go to the next word
        while (arr[itr+index] != 0 && arr[itr+index] != 1) {
            index++;
        }
        
        itr += index;
        if (arr[itr] == 0) {
            return false;
        }
        if (arr[itr] == 1) {
            itr++;
        }
    }
    
    return false;
}

// hash map [size, pointer to string/0, size_index+1 start of first string, end of string, 0 end of list/1 end of string]
// choices_arr multidemnsional array [0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" choices for first value in password
kernel void solve_md5(device const unsigned* hash_map,
                      device const char* choices_arr,
                      device bool* doesItWork,
                      device const uint* additionToIndex,
                      uint index_of_grid [[thread_position_in_grid]])
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

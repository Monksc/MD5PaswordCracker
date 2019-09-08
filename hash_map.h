//
//  hash_map.h
//  ReverseMD5Metal
//
//  Created by Cameron Monks on 7/16/19.
//  Copyright © 2019 Cameron Monks. All rights reserved.
//

#ifndef hash_map_h
#define hash_map_h

#define thread
#define MAX_PASSWORD_CHARACTERS 16

//#include <stdio.h>
#include <stdlib.h>
/*
#include <assert.h>
#include <string.h>
 */

typedef enum { false, true } bool;


// MARK: Node

typedef struct Node {
    char * value;
    struct Node* next;
} Node;

Node* NodeInit(char *str);

Node* NodeAdd(Node *self, char *str, bool allowDuplicates);

bool NodeContains(const Node *self, const char *str);

void NodePrint(const Node *self);

unsigned NodeCount(const Node *self);

char * NodeToCharArray(const Node *self);

// MARK: HashSet

typedef struct {
    Node ** arr;
    unsigned count;
    unsigned size;
} HashSet;

HashSet* HashSetInit(unsigned size);

bool HashSetAdd(HashSet *self, char * str);

bool HashSetContains(const HashSet *self, const char *str);

void HashSetPrint(const HashSet* self);


// MARK: HashSet Array

unsigned HashSetToArraySize(const HashSet* self);

unsigned* HashSetToArray(const HashSet* self);

bool HashSetArrayContains(const unsigned* arr, const char * str);


// MARK: Integer Formsat

char* IntegerToAsci(unsigned long i, const Node* n);

char* IntegerToAsciTwo(unsigned long i, const char * arr);


// MARK: MD5
#define thread
void md52(thread int8_t *initial_msg, size_t initial_len, thread char * encryptedMDMsg);
//void md5(thread const char *msg, unsigned mlen, thread char * answer);

#endif /* hash_map_h */

//
//  AluminumArgumentBuffer.h
//  Aluminum
//
//  Created by Maxim Vainshtein on 21/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

#pragma once
#import <simd/simd.h>

struct TestStruct {
    uint i;
    float k;
    bool j;
};
typedef struct TestStruct TestStruct;

struct TestInternalArgumentsBuffer {
    device int * buffer;
    device TestStruct * tr;
    metal::array<TestStruct, 9> arr;
};
typedef struct TestInternalArgumentsBuffer TestInternalArgumentsBuffer;

struct TestArgumentsBuffer {
    metal::array<TestInternalArgumentsBuffer, 1> arr_t;
    constant TestInternalArgumentsBuffer * t1;
    device float * buffer;
    uint l;
    metal::array<bool, 9> arr;
};
typedef struct TestArgumentsBuffer TestArgumentsBuffer;


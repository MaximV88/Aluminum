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

struct TestInternalArgumentsBuffer {
    device int * buffer;
    metal::array<TestStruct, 9> arr;
};
typedef struct TestInternalArgumentsBuffer TestInternalArgumentsBuffer;

struct TestArgumentsBuffer {
    device float * buffer;
    uint length;
    metal::array<bool, 9> arr;
    constant TestInternalArgumentsBuffer * t;
    metal::array<TestInternalArgumentsBuffer, 4> arr_t;
};
typedef struct TestArgumentsBuffer TestArgumentsBuffer;


//
//  AluminumTests.metal
//  AluminumTests
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

#import <metal_stdlib>
using namespace metal;

#import "AluminumTestsUniforms.h"
#import "AluminumArgumentBuffer.h"

struct Composite {
//    device float * t;
    float b;
    uint a;
    GridRegion d;

};

typedef struct Composite Composite;

struct C {
    
    uint a;
    device float * t;
    metal::array<uint, 9> arr;
    ushort c;
    metal::array<Composite, 9> d;
};
typedef struct C C;


kernel void test_array_argument(device metal::array<C, 40> & arr [[ buffer(0) ]],
                                device metal::array<TestArgumentsBuffer, 40> & tarr [[ buffer(1) ]],
                                device atomic_uint * result [[ buffer(2) ]])
{
    for (int i = 0, end = arr.size() ; i < end ; i++)
    {
        atomic_fetch_add_explicit(result, *arr[i].t
                                  + arr[i].a
                                  + arr[i].c
                                  + arr[i].arr[0]
                                  + arr[i].arr[1]
                                  + tarr[i].l
                                  + *tarr[i].arr_t[0].buffer
                                  + tarr[i].arr_t[0].tr->i,
                                  memory_order_relaxed);
    }
}

kernel void test_argument(device uint * source [[ buffer(0) ]],
                          device uint * destination [[ buffer(1) ]],
                          uint gid [[ thread_position_in_grid ]])
{
    destination[gid] = source[gid];
}

kernel void multiple_arguments(device metal::array<float, 3> * arr [[ buffer(1) ]],
                               threadgroup metal::array<float, 2> * k [[ threadgroup(5) ]],
                               array<texture2d<float>, 10> constarr [[ texture(3) ]],
                               texture_buffer<float> testarr [[ texture(0) ]],
                               texture1d_array<float, metal::access::read> testtextarr [[ texture(1) ]],
                               device float * buff [[ buffer(2) ]],
                               constant TestArgumentsUniforms &uniforms [[ buffer(3) ]],
                               device TestArgumentsBuffer & argumentBuffer [[ buffer(4) ]],
                               texture2d<float> tex [[ texture(2) ]])
{
    
}

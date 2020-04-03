//
//  AluminumTests.metal
//  AluminumTests
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

#import <metal_stdlib>
using namespace metal;

#pragma mark - Test Argument Pointer

kernel void test_argument_pointer(device uint * buffer,
                                  device uint * result)
{
    *result = *buffer;
}

#pragma mark - Test Argument Array

kernel void test_argument_array(device metal::array<int, 10> & array,
                                device uint * result)
{
    for (int i = 0, end = array.size() ; i < end ; i++)
    {
        *result += array[i];
    }
}

#pragma mark - Test Argument Struct

struct ArgumentStruct {
    int i;
    uint j;
    bool k;
    float l;
};

kernel void test_argument_struct(device ArgumentStruct& argument_struct,
                                 device uint * result)
{
    *result = argument_struct.i + argument_struct.j + argument_struct.k + argument_struct.l;
}

#pragma mark - Test Argument Complex Struct

struct ArgumentComplexStruct {
    int i_arr[10];
    metal::array<uint, 10> ui_arr;
};

kernel void test_argument_complex_struct(device ArgumentComplexStruct& argument_complex_struct,
                                         device uint * result)
{
    for (int i = 0, end = 10 ; i < end ; i++)
    {
        *result += argument_complex_struct.i_arr[i] + argument_complex_struct.ui_arr[i];
    }
}


#pragma mark - Test Argument Buffer

struct ArgumentBuffer {
    constant int * buff;
    int i;
    uint j;
};

kernel void test_argument_buffer(device ArgumentBuffer& argument_buffer,
                                 device uint * result)
{
    // assume buffer length
    for (int i = 0, end = 10 ; i < end ; i++)
    {
        *result += argument_buffer.buff[i];
    }

    *result += argument_buffer.i;
    *result += argument_buffer.j;
}




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
    
    uint k[4];
    uint a;
    device float * t;
    metal::array<uint, 9> arr;
    ushort c;
    metal::array<Composite, 9> d;
};
typedef struct C C;

//kernel void test_array_argument(device C arr[40] , // still a buffer
//device metal::array<TestArgumentsBuffer, 40> & tarr ,
//device atomic_uint * result)


kernel void test_array_argument(device metal::array<C, 40> & arr,
                                device metal::array<TestArgumentsBuffer, 40> & tarr,
                                device atomic_uint * result)
{
    for (int i = 0, end = 40 ; i < end ; i++)
    {
        atomic_fetch_add_explicit(result, *arr[i].t
                                  + arr[i].a
                                  + arr[i].c
                                  + arr[i].arr[0]
                                  + arr[i].arr[1]
                                  + tarr[i].l
                                  + *tarr[i].arr_t[0].buffer
                                  + tarr[i].arr_t[0].tr->i
                                  + tarr[i].arr_t[0].tr->k
                                  + tarr[i].arr_t[0].tr->j
                                  + *tarr[i].t1->buffer,
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

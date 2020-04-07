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

struct ComplexStruct {
    int i_arr[10];
    metal::array<uint, 10> ui_arr;
    uint j;
};

kernel void test_argument_complex_struct(device ComplexStruct& argument_complex_struct,
                                         device uint * result)
{
    for (int i = 0, end = 10 ; i < end ; i++)
    {
        *result += argument_complex_struct.i_arr[i] + argument_complex_struct.ui_arr[i];
    }
    
    *result += argument_complex_struct.j;
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
    for (int i = 0, end = 10 ; i < end ; i++)
    {
        *result += argument_buffer.buff[i];
    }

    *result += argument_buffer.i;
    *result += argument_buffer.j;
}

#pragma mark - Test Argument Buffer Array

kernel void test_argument_buffer_array(device metal::array<ArgumentBuffer, 10> & argument_buffer_array,
                                       device uint * result)
{
    for (int i = 0, end = argument_buffer_array.size() ; i < end ; i++) {
        for (int j = 0, end = 10 ; j < end ; j++)
        {
            *result += argument_buffer_array[i].buff[j];
        }
        
        *result += argument_buffer_array[i].i;
        *result += argument_buffer_array[i].j;
    }
}

#pragma mark - Test Argument Buffer With Nested Argument Buffer

struct ArgumentBufferContainer {
    int i;
    constant ArgumentBuffer * child;
};

kernel void test_argument_buffer_with_nested_argument_buffer(device ArgumentBufferContainer& argument_buffer,
                                                             device uint * result)
{
    *result += argument_buffer.i;
    constant ArgumentBuffer& child = *argument_buffer.child;
    
    for (int i = 0, end = 10 ; i < end ; i++)
    {
        *result += child.buff[i];
    }

    *result += child.i;
    *result += child.j;
}

#pragma mark - Test Argument Buffer Array With Nested Array

struct ArgumentBufferWithNestedArray {
    int i;
    metal::array<ComplexStruct, 2> j;
};

kernel void test_argument_buffer_array_with_nested_array(device metal::array<ArgumentBufferWithNestedArray, 10> & argument_buffer,
                                                         device uint * result)
{
    for (int i = 0, end = argument_buffer.size() ; i < end ; i++)
    {
        *result += argument_buffer[i].i;
        *result += argument_buffer[i].j[0].j + argument_buffer[i].j[1].j;
        
        for (int j = 0 ; j < 10 ; j++)
        {
            *result += argument_buffer[i].j[0].i_arr[j] + argument_buffer[i].j[0].ui_arr[j];
            *result += argument_buffer[i].j[1].i_arr[j] + argument_buffer[i].j[1].ui_arr[j];
        }
    }
}

#pragma mark - Test Argument Buffer Array With Nested Argument Buffer

struct ArgumentBufferWithNestedArgumentBuffer {
    constant ArgumentBuffer *i;
};

kernel void test_argument_buffer_array_with_nested_argument_buffer(device metal::array<ArgumentBufferWithNestedArgumentBuffer, 10> & argument_buffer,
                                                                   device uint * result)
{
    for (int i = 0, end = argument_buffer.size() ; i < end ; i++)
    {
        *result += argument_buffer[i].i->i + argument_buffer[i].i->j;

        for (int j = 0 ; j < 10 ; j++)
        {
            *result += argument_buffer[i].i->buff[j];
        }
    }
}

#pragma mark - Test Argument Buffer Array With Nested Argument Buffer Array

struct ArgumentBufferWithNestedArgumentBufferArray {
    int i;
    metal::array<ArgumentBuffer, 2> j;
};

kernel void test_argument_buffer_array_with_nested_argument_buffer_array(device metal::array<ArgumentBufferWithNestedArgumentBufferArray, 10> & argument_buffer,
                                                         device uint * result)
{
    for (int i = 0, end = argument_buffer.size() ; i < end ; i++)
    {
        *result += argument_buffer[i].i;
        *result += argument_buffer[i].j[0].i + argument_buffer[i].j[0].j;
        *result += argument_buffer[i].j[1].i + argument_buffer[i].j[1].j;

        for (int j = 0 ; j < 10 ; j++)
        {
            *result += argument_buffer[i].j[0].buff[j] + argument_buffer[i].j[1].buff[j];
        }
    }
}

#pragma mark - Test Argument Buffer Array With Nested Argument Buffer And Array

struct ArgumentBufferWithArgumentBufferAndArray {
    constant ArgumentBuffer *i;
    int i_arr[10];
    metal::array<uint, 10> ui_arr;
};

kernel void test_argument_buffer_array_with_nested_argument_buffer_and_array(device metal::array<ArgumentBufferWithArgumentBufferAndArray, 10> & argument_buffer,
                                                                             device uint * result)
{
    for (int i = 0, end = argument_buffer.size() ; i < end ; i++)
    {
        *result += argument_buffer[i].i->i + argument_buffer[i].i->j;

        for (int j = 0 ; j < 10 ; j++)
        {
            *result += argument_buffer[i].i->buff[j];
            *result += argument_buffer[i].i_arr[j] + argument_buffer[i].ui_arr[j];
        }
    }
}

#pragma mark - Test Argument Buffer Array With Nested Argument Buffer And Argument Buffer Array

struct ArgumentBufferWithArgumentBufferAndArgumentBufferArray {
    constant ArgumentBuffer *i;
    metal::array<ArgumentBuffer, 2> j;
};

kernel void test_argument_buffer_array_with_nested_argument_buffer_and_argument_buffer_array(device metal::array<ArgumentBufferWithArgumentBufferAndArgumentBufferArray, 10> & argument_buffer,
                                                         device uint * result)
{
    for (int i = 0, end = argument_buffer.size() ; i < end ; i++)
    {
        *result += argument_buffer[i].i->i + argument_buffer[i].i->j;
        *result += argument_buffer[i].j[0].i + argument_buffer[i].j[0].j;
        *result += argument_buffer[i].j[1].i + argument_buffer[i].j[1].j;

        for (int j = 0 ; j < 10 ; j++)
        {
            *result += argument_buffer[i].i->buff[j];
            *result += argument_buffer[i].j[0].buff[j] + argument_buffer[i].j[1].buff[j];
        }
    }
}

#pragma mark - Test Argument Buffer With Multi Nested Argument Buffer

struct MultiNestedC {
    constant ArgumentBuffer * i;
};

struct MultiNestedB {
    constant MultiNestedC * c;
};

struct MultiNestedA {
    constant MultiNestedB * b;
};

kernel void test_argument_buffer_with_multi_nested_argument_buffer(device MultiNestedA & argument_buffer,
                                                                   device uint * result)
{
    *result += argument_buffer.b->c->i->i + argument_buffer.b->c->i->j;
    
    for (int i = 0 ; i < 10 ; i++)
    {
        *result += argument_buffer.b->c->i->buff[i];
    }
}

#pragma mark - Test Argument Buffer Array With Multi Nested Argument Buffer

kernel void test_argument_buffer_array_with_multi_nested_argument_buffer(device metal::array<MultiNestedA, 10> & argument_buffer,
                                                                         device uint * result)
{
    for (int i = 0 ; i < 10 ; i++)
    {
        *result += argument_buffer[i].b->c->i->i + argument_buffer[i].b->c->i->j;
        
        for (int j = 0 ; j < 10 ; j++)
        {
            *result += argument_buffer[i].b->c->i->buff[i];
        }
    }
}

#pragma mark - Test Argument Buffer Encodable Buffer

struct EncodableStruct {
    int i;
    uint j;
    bool k;
};

struct ArgumentBufferWithEncodableStruct {
    device EncodableStruct * i;
};

kernel void test_argument_buffer_encodable_buffer(device ArgumentBufferWithEncodableStruct & argument_buffer,
                                                  device uint * result)
{
    *result += argument_buffer.i->i + argument_buffer.i->j + argument_buffer.i->k;
}

#pragma mark - Test Argument Buffer Encodable Buffer Array

struct ArgumentBufferWithEncodableStructArray {
    metal::array<device EncodableStruct *, 10> arr;
};

kernel void test_argument_buffer_encodable_buffer_array(device ArgumentBufferWithEncodableStructArray & argument_buffer,
                                                        device uint * result)
{
    for (int i = 0 ; i < 10 ; i++)
    {
        device EncodableStruct& encodable = *argument_buffer.arr[i];
        *result += encodable.i + encodable.j + encodable.k;
    }
}

#pragma mark - Test Argument Buffer Array Encodable Buffer Array

kernel void test_argument_buffer_array_encodable_buffer_array(device metal::array<ArgumentBufferWithEncodableStructArray, 10> & argument_buffer,
                                                              device uint * result)
{
    for (int i = 0 ; i < 10 ; i++)
    {
        for (int j = 0 ; j < 10 ; j++)
        {
            device EncodableStruct& encodable = *argument_buffer[i].arr[j];
            *result += encodable.i + encodable.j + encodable.k;
        }
    }
}

#pragma mark - Test Argument Buffer Struct Array

struct ArgumentBufferArray {
    ArgumentBuffer arr[10];
};

kernel void test_argument_buffer_struct_array(device ArgumentBufferArray * argument,
                                                device uint * result)
{
    for (int i = 0 ; i < 10 ; i++)
    {
        device ArgumentBuffer& encodable = argument->arr[i];

        for (int j = 0; j < 10 ; j++)
        {
            *result += encodable.buff[i];
        }

        *result += encodable.i;
        *result += encodable.j;
    }
}

#pragma mark - Test Argument Buffer Pointer Array

struct ArgumentBufferPointerArray {
    metal::array<device int *, 10> arr;
};

kernel void test_argument_buffer_pointer_array(device ArgumentBufferPointerArray * argument,
                                               device uint * result)
{
    for (int i = 0 ; i < 10 ; i++)
    {
        device int* encodable = argument->arr[i];

        for (int j = 0; j < 10 ; j++)
        {
            *result += encodable[j];
        }
    }
}

#pragma mark - Test Texture Argument

kernel void test_texture_argument(texture2d<uint, access::read> argument,
                                  device uint * result)
{
    for (ushort i = 0 ; i < 10 ; i++)
    {
        for (ushort j = 0 ; j < 10 ; j++)
        {
            auto value = argument.read(ushort2(i, j));
            *result += value.x;// + value.y + value.z + value.w;
        }
    }
}

//kernel void multiple_arguments(device metal::array<float, 3> * arr [[ buffer(1) ]],
//                               threadgroup metal::array<float, 2> * k [[ threadgroup(5) ]],
//                               array<texture2d<float>, 10> constarr [[ texture(3) ]],
//                               texture_buffer<float> testarr [[ texture(0) ]],
//                               texture1d_array<float, metal::access::read> testtextarr [[ texture(1) ]],
//                               device float * buff [[ buffer(2) ]],
//                               constant TestArgumentsUniforms &uniforms [[ buffer(3) ]],
//                               device TestArgumentsBuffer & argumentBuffer [[ buffer(4) ]],
//                               texture2d<float> tex [[ texture(2) ]])
//{
//
//}

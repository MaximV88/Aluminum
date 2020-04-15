//
//  Utilities.metal
//  AluminumTests
//
//  Created by Maxim Vainshtein on 11/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void fill_test_texture(texture2d<uint, access::write> texture)
{
    uint value = 1;
    
    for (ushort i = 0 ; i < 10 ; i++)
    {
        for (ushort j = 0 ; j < 10 ; j++)
        {
            texture.write(uint4(value, 0, 0, 0), ushort2(i, j));
            value += 1;
        }
    }

}

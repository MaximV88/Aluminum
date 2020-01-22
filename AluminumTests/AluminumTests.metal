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


kernel void test_arguments(device metal::array<float, 3> * arr [[ buffer(1) ]],
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

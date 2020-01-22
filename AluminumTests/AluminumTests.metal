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


kernel void test_arguments(device float * buff [[ buffer(0) ]],
                           constant TestArgumentsUniforms &uniforms [[ buffer(1) ]],
                           device metal::array<float, 3> * arr [[ buffer(2) ]],
                           device TestArgumentsBuffer & argumentBuffer [[ buffer(3) ]],
                           texture2d<float> tex [[ texture(0) ]])
{
    
}

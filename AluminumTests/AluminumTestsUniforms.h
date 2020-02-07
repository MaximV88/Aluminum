//
//  AluminumTestsUniforms.h
//  Aluminum
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

#pragma once
#import <simd/simd.h>


struct TestArgumentsUniforms {
    uint bufferLength;
};
typedef struct TestArgumentsUniforms TestArgumentsUniforms;

typedef vector_int3 GridPoint;

struct GridSize {
    uint width, height, depth;
};
typedef struct GridSize GridSize;

struct GridRegion {
    GridSize size;
    GridPoint origin;
};
typedef struct GridRegion GridRegion;

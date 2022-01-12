//
//  ShaderTypes.h
//  
//
//  Created by Xcode Developer on 1/9/22.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

//#import <Foundation/Foundation.h>
#include <simd/simd.h>

/*
 Accessing Vector Components
 
 pos = float4(1.0f, 2.0f, 3.0f, 4.0f);
 float x = pos[0]; // x = 1.0 float z = pos[2]; // z = 3.0
 float4 vA = float4(1.0f, 2.0f, 3.0f, 4.0f); float4 vB;
 for (int i=0; i<4; i++)
 vB[i] = vA[i] * 2.0f // vB = (2.0, 4.0, 6.0, 8.0);

 float3x2(float2, float2, float2);
 */

typedef struct
{
    vector_float2 arc_touch_point;
    vector_float2 button_center_points[5];
    float arc_radius;
    vector_float2 arc_center;
    matrix_float3x2 arc_control_points;
} CaptureDevicePropertyControlLayout;

#endif /* ShaderTypes_h */

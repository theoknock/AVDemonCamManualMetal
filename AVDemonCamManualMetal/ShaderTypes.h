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

typedef struct
{
    vector_float3 touch_point__angle;
    vector_float3 button_center__angle[5];
    vector_float3 arc_center__radius;
    vector_float3 arc_control_points_xy[2];
} CaptureDevicePropertyControlLayout;

#endif /* ShaderTypes_h */

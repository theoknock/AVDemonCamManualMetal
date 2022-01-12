/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A shader that adds two arrays of floats.
*/

#include <metal_stdlib>
#include <simd/simd.h>
#include "ShaderTypes.h"

using namespace metal;

kernel void add_arrays(device CaptureDevicePropertyControlLayout & layout [[ buffer(0) ]],
                       uint idx [[ thread_position_in_grid ]])
{
    // TO-DO: Simply plot control points of bezier curve for button center (all this other math is grossly unnecessary)
    
    layout.arc_center__radius.z   = sqrt(pow(layout.touch_point__angle.x - layout.arc_center__radius.x, 2.0) +
                                         pow(layout.touch_point__angle.y - layout.arc_center__radius.y, 2.0));
    layout.touch_point__angle.z   =    atan2(layout.touch_point__angle.y - layout.arc_center__radius.y,
                                             layout.touch_point__angle.x - layout.arc_center__radius.x) * (180.0 / M_PI_F);
    if (layout.touch_point__angle.z < 0.0) layout.touch_point__angle.z += 360.0;
    
    for (int property = 0; property < 5; property++) {
        float time = layout.button_center__angle[property].z;
        float x = (1 - time) * (1 - time) * layout.arc_control_points_xy[0].x + 2 * (1 - time) * time * layout.arc_control_points_xy[0].y + time * time * layout.arc_control_points_xy[0].z;
        float y = (1 - time) * (1 - time) * layout.arc_control_points_xy[1].x + 2 * (1 - time) * time * layout.arc_control_points_xy[1].y + time * time * layout.arc_control_points_xy[1].z;
        layout.button_center__angle[property] = vector_float3(vector_float2(x, y), time);
    }
    
    
    
    /*
     
     typedef struct
     {
     vector_float3 touch_point__angle;
     vector_float3 button_center__angle[5];
     vector_float3 arc_center__radius;
     vector_float3 arc_control_points_xy[2];
     } CaptureDevicePropertyControlLayout;
     
     */
    
    
    /*
     
     Accessing Vector Components
     
     pos = float4(1.0f, 2.0f, 3.0f, 4.0f);
     float x = pos[0]; // x = 1.0 float z = pos[2]; // z = 3.0
     float4 vA = float4(1.0f, 2.0f, 3.0f, 4.0f); float4 vB;
     for (int i=0; i<4; i++)
     vB[i] = vA[i] * 2.0f // vB = (2.0, 4.0, 6.0, 8.0);
     
     float3x2(float2, float2, float2);
     
     */
    

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
    layout.arc_radius = sqrt(pow(layout.arc_touch_point.x - layout.arc_center.x, 2.0) + pow(layout.arc_touch_point.y - layout.arc_center.y, 2.0));
    
//    CGFloat touch_angle = (atan2((touch_point).y - (center_point).y,
//                         (touch_point).x - (center_point).x)) * (180.0 / M_PI);
//    if (touch_angle < 0.0) touch_angle += 360.0;
//    touch_angle = fmaxf(180.0, fminf(touch_angle, 270.0));

    for (int property = 0; property < 5; property++) {
        float angle   = (180.0 + (90.0 * (property / 4.0)));
        float time    = (1.0 - 0.0) * /*(fmax(old_min, fmin(old_value, old_max))*/ (angle - 180.0) / (270.0 - 180.0) + 0.0;

        float x = (1 - time) * (1 - time) * layout.arc_control_points.columns[0].x + 2 * (1 - time) * time * layout.arc_control_points.columns[1].x + time * time * layout.arc_control_points.columns[2].x;
        float y = (1 - time) * (1 - time) * layout.arc_control_points.columns[0].y + 2 * (1 - time) * time * layout.arc_control_points.columns[1].y + time * time * layout.arc_control_points.columns[2].y;
        layout.button_center_points[property] = vector_float2(x, y);
    }
}

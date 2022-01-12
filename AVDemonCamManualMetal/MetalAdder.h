/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class to manage all of the Metal objects this app creates.
*/

#import <Foundation/Foundation.h>
//@import CoreGraphics;
#import <Metal/Metal.h>
#include "ShaderTypes.h"

NS_ASSUME_NONNULL_BEGIN

static CaptureDevicePropertyControlLayout * captureDevicePropertyControlLayoutBufferPtr;

@interface MetalAdder : NSObject

- (instancetype) initWithDevice: (id<MTLDevice>) device arcCenter:(vector_float2)arc_center arcControlPoints:(matrix_float3x2)control_points;
- (vector_float2 *) prepareData:(vector_float2)touch_point;
- (float) sendComputeCommand;



@end

NS_ASSUME_NONNULL_END

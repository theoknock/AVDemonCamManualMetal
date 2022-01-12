//
//  ViewController.h
//  AVDemonCamManualMetal
//
//  Created by Xcode Developer on 1/11/22.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "ShaderTypes.h"

NS_ASSUME_NONNULL_BEGIN

static CaptureDevicePropertyControlLayout * captureDevicePropertyControlLayoutBufferPtr;

@interface MetalAdder : NSObject

- (instancetype) initWithDevice: (id<MTLDevice>) device arcCenter:(vector_float2)arc_center arcControlPoints:(matrix_float3x2)control_points;
- (void) prepareData:(vector_float2)touch_point;
- (float) sendComputeCommand;

@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController


@end

NS_ASSUME_NONNULL_END

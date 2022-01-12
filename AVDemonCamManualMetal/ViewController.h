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

- (instancetype) initWithDevice: (id<MTLDevice>) device boundToContext:(CGRect)context_rect;
- (void) prepareData:(CGPoint)touch_point
- (void) sendComputeCommand;

@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController


@end

NS_ASSUME_NONNULL_END

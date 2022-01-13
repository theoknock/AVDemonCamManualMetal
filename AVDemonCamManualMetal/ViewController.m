//
//  ViewController.m
//  AVDemonCamManualMetal
//
//  Created by Xcode Developer on 1/11/22.
//

#import "ViewController.h"
#import <Metal/Metal.h>
#import "ShaderTypes.h"
#import <objc/runtime.h>

#define degreesToRadians(angleDegrees) (angleDegrees * M_PI / 180.0)

static float button_angles[5] =               {0.0, 0.25, 0.5, 0.75, 1.0};    // button_center__angle[0 ... 5].z
static vector_float2 arc_center =             {1.0, 1.0};                     // arc_center__radius.z
static vector_float3 arc_control_points[2] = {{0.0, 0.0, 1.0},                // arc_control_points_xy[0].xyz
                                              {1.0, 0.5, 0.5}};               // arc_control_points_xy[1].xyz


static __strong UIButton * buttons[5];
static void (^(^populate_collection)(__strong UIButton * [5]))(UIButton * (^__strong)(unsigned int)) = ^ (__strong UIButton * button_collection[5]) {
    dispatch_queue_t enumerator_queue  = dispatch_queue_create("enumerator_queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t enumeration_queue = dispatch_queue_create_with_target("enumeration_queue", DISPATCH_QUEUE_SERIAL, dispatch_get_main_queue());
    return ^ (UIButton *(^enumeration)(unsigned int)) {
        dispatch_apply(5, enumerator_queue, ^(size_t index) {
            dispatch_async(enumeration_queue, ^{
                button_collection[index] = enumeration((unsigned int)index); // adds buttons to an array after configured by enumeration
            });
        });
    };
};

static void (^(^enumerate_collection)(__strong UIButton * [5]))(void (^__strong)(UIButton * _Nonnull, unsigned int)) = ^ (__strong UIButton * button_collection[5]) {
    dispatch_queue_t enumerator_queue  = dispatch_queue_create("enumerator_queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t enumeration_queue = dispatch_queue_create_with_target("enumeration_queue", DISPATCH_QUEUE_SERIAL, dispatch_get_main_queue());
    return ^ (void(^enumeration)(UIButton * _Nonnull, unsigned int)) {
        dispatch_apply(5, enumerator_queue, ^(size_t index) {
            dispatch_async(enumeration_queue, ^{
                enumeration(button_collection[index], (unsigned int)index); // no return value
            });
        });
    };
};

static void (^(^(^(^touch_handler_init)(dispatch_block_t))(void(^)(CGPoint)))(UITouch * _Nonnull))(void) = ^ (dispatch_block_t _Nullable init_blk) {
    (!init_blk) ?: init_blk();
    return ^ (void(^process_touch_point)(CGPoint)) {
        return ^ (UITouch * _Nonnull touch) {
            return ^ {
                CGPoint touch_point = [touch preciseLocationInView:touch.view];
                process_touch_point(touch_point);
            };
        };
    };
};
static void (^(^touch_handler)(UITouch *))(void);
static void (^handle_touch)(void);

@implementation MetalAdder
{
    id<MTLDevice> _mDevice;
    id<MTLComputePipelineState> _mAddFunctionPSO;
    id<MTLCommandQueue> _mCommandQueue;
    id<MTLBuffer> captureDevicePropertyControlLayoutBuffer;
    CGRect contextRect;
}

- (instancetype) initWithDevice:(id<MTLDevice>)device boundToContext:(CGRect)context_rect
{
    self = [super init];
    if (self)
    {
        CaptureDevicePropertyControlLayout control_layout = (CaptureDevicePropertyControlLayout) {
            .touch_point__angle    = {  (simd_make_float3(simd_make_float2(0.00, 0.00), 0.50))              },
            .button_center__angle  = {  (simd_make_float3(simd_make_float2(0.00, 1.00), button_angles[0])),
                                        (simd_make_float3(simd_make_float2(0.25, 0.25), button_angles[1])),
                                        (simd_make_float3(simd_make_float2(0.50, 0.50), button_angles[2])),
                                        (simd_make_float3(simd_make_float2(0.75, 0.75), button_angles[3])),
                                        (simd_make_float3(simd_make_float2(1.00, 0.00), button_angles[4]))  },
            .arc_center__radius    = {  (simd_make_float3(simd_make_float2(1.00, 1.00), 0.5))               },
            .arc_control_points_xy = {  (simd_make_float3(0.0, 0.0, 1.0)),
                                        (simd_make_float3(1.0, 0.5, 0.5))                                   }
        };
        contextRect = CGRectIntegral(context_rect);
        
        __autoreleasing NSError* error = nil;
        
        _mDevice = device;
        
        id<MTLLibrary> defaultLibrary = [_mDevice newDefaultLibrary];
        if (defaultLibrary == nil)
        {
            NSLog(@"Failed to find the default library.");
            return nil;
        }
        
        id<MTLFunction> addFunction = [defaultLibrary newFunctionWithName:@"add_arrays"];
        if (addFunction == nil)
        {
            NSLog(@"Failed to find the adder function.");
            return nil;
        }
        
        _mAddFunctionPSO = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
        if (_mAddFunctionPSO == nil)
        {
            NSLog(@"Failed to created pipeline state object, error %@.", error);
            return nil;
        }
        
        _mCommandQueue = [_mDevice newCommandQueue];
        if (_mCommandQueue == nil)
        {
            NSLog(@"Failed to find the command queue.");
            return nil;
        }

        int minX    = (float)CGRectGetMinX(contextRect);
        int midX    = (float)CGRectGetMidX(contextRect);
        int minXmid = ((midX & minX) + ((midX ^ minX) >> 1));
        int maxX    = (float)CGRectGetMinX(contextRect);
        int midXmax = ((maxX & midX) + ((maxX ^ midX) >> 1));
                    
        int minY    = (float)CGRectGetMinY(contextRect);
        int midY    = (float)CGRectGetMidY(contextRect);
        int minYmid = ((midY & minY) + ((midY ^ minY) >> 1));
        int maxY    = (float)CGRectGetMinY(contextRect);
        int midYmax = ((maxY & midY) + ((maxY ^ midY) >> 1));
        
        captureDevicePropertyControlLayoutBuffer       = [_mDevice newBufferWithLength:sizeof(CaptureDevicePropertyControlLayout) options:MTLResourceStorageModeShared];
        captureDevicePropertyControlLayoutBufferPtr    = captureDevicePropertyControlLayoutBuffer.contents;
        captureDevicePropertyControlLayoutBufferPtr[0] = (CaptureDevicePropertyControlLayout) {
            .touch_point__angle    = {  (simd_make_float3(simd_make_float2(0.00, 0.00), 0.50))              },
            .button_center__angle  = {  (simd_make_float3(simd_make_float2(CGRectGetMinX(contextRect), 1.00), button_angles[0])),
                                        (simd_make_float3(simd_make_float2(, CGRectGetMidY(contextRect) >> 1), button_angles[1])),
                                        (simd_make_float3(simd_make_float2(CGRectGetMidX(contextRect), CGRectGetMidY(contextRect)), button_angles[2])),
                                        (simd_make_float3(simd_make_float2(0.75, 0.75), button_angles[3])),
                                        (simd_make_float3(simd_make_float2(CGRectGetMaxX(contextRect), 0.00), button_angles[4]))  },
            .arc_center__radius    = {  (simd_make_float3(simd_make_float2(CGRectGetMaxX(contextRect), CGRectGetMaxY(contextRect)), CGRectGetMidX(contextRect)))               },
            .arc_control_points_xy = {  (simd_make_float3(CGRectGetMinX(contextRect), CGRectGetMinX(contextRect), CGRectGetMaxX(contextRect))),
                                        (simd_make_float3(CGRectGetMaxY(contextRect), CGRectGetMidY(contextRect), CGRectGetMidY(contextRect)))                                   }
        };
    }
    
    return self;
}

- (void)prepareData:(CGPoint)touch_point
{
    captureDevicePropertyControlLayoutBufferPtr[0].touch_point__angle = simd_make_float3(simd_make_float2((float)(touch_point.x), (float)(touch_point.y)), (float)(0.0));
}

- (void)encodeAddCommand:(id<MTLComputeCommandEncoder>)computeEncoder {
    [computeEncoder setComputePipelineState:_mAddFunctionPSO];
    [computeEncoder setBuffer:captureDevicePropertyControlLayoutBuffer offset:0 atIndex:0];
    
    MTLSize threadsPerThreadgroup = MTLSizeMake(MIN(sizeof(CaptureDevicePropertyControlLayout), (_mAddFunctionPSO.maxTotalThreadsPerThreadgroup / _mAddFunctionPSO.threadExecutionWidth)), 1, 1);
    MTLSize threadsPerGrid = MTLSizeMake(sizeof(CaptureDevicePropertyControlLayout), 1, 1);
    [computeEncoder dispatchThreads: threadsPerGrid
              threadsPerThreadgroup: threadsPerThreadgroup];
}

- (void)sendComputeCommand
{
    // Create a command buffer to hold commands.
    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    assert(commandBuffer != nil);
    
    // Start a compute pass.
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    assert(computeEncoder != nil);
    
    [self encodeAddCommand:computeEncoder];
    
    // End the compute pass.
    [computeEncoder endEncoding];
    
    // Execute the command.
    [commandBuffer commit];
    
    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    [commandBuffer waitUntilCompleted];
    
    [commandBuffer addCompletedHandler:^ (id<MTLBuffer> buffer) {
        return ^ (id<MTLCommandBuffer> _Nonnull commands) {
            printf("%d == {%.1f, %.1f}\n",
                   (*captureDevicePropertyControlLayoutBufferPtr).touch_point__angle.x,
                   (*captureDevicePropertyControlLayoutBufferPtr).touch_point__angle.y);
            for (int i = 0; i < 3; i++) {
                printf("%d == {%f, %f}\n",
                       i,
                       (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[i].x,
                       (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[i].y);
            }
            for (int i = 0; i < 5; i++) {
                printf("%d == {%f, %f}\n",
                       i,
                       (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[i].x,
                       (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[i].y);
            }
        };
    }(captureDevicePropertyControlLayoutBuffer)];
    
    return (*captureDevicePropertyControlLayoutBufferPtr).arc_radius;
}

@end


@interface ViewController ()

//    void(^g(void(^)(void)))(void);
//    void(^b)(void) =
//    ^{
//        return g(^{
//
//        });
//    }();

@end

@implementation ViewController
{
    id<MTLDevice> device;
    CAShapeLayer * shape_layer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [(shape_layer = [CAShapeLayer new]) setFrame:self.view.frame];
    [shape_layer setStrokeColor:[UIColor systemBlueColor].CGColor];
    [shape_layer setFillColor:[UIColor clearColor].CGColor];
    [shape_layer setBackgroundColor:[UIColor clearColor].CGColor];
    [self.view.layer addSublayer:shape_layer];
    
    device = MTLCreateSystemDefaultDevice();
    center_point = CGPointMake(CGRectGetMaxX(self.view.frame), CGRectGetMaxY(self.view.frame));
    control_points = {
        vector2((float)CGRectGetMinX(self.view.frame),(float)CGRectGetMaxY(self.view.frame)),
        vector2((float)CGRectGetMidX(self.view.frame),(float)CGRectGetMidY(self.view.frame)),
        vector2((float)CGRectGetMaxX(self.view.frame),(float)CGRectGetMinY(self.view.frame))};
    MetalAdder * adder = [[MetalAdder alloc] initWithDevice:device arcCenter:vector2((float)center_point.x, (float)center_point.y) arcControlPoints:control_points];
    [adder prepareData:vector2((float)CGRectGetMidX(self.view.frame), (float)CGRectGetMidX(self.view.frame))];
    [adder sendComputeCommand];
    
    populate_collection(buttons)(^ UIButton * (unsigned int index) {
        UIButton * button;
        [button = [UIButton new] setTag:index];
        [button setBackgroundColor:[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.25]];
        [button setImage:[UIImage systemImageNamed:@"questionmark.circle" withConfiguration:[[UIImageSymbolConfiguration configurationWithPointSize:42] configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationPreferringMulticolor]]] forState:UIControlStateNormal];
        [button sizeToFit];
        void (^eventHandlerBlock)(void) = ^{ };
        objc_setAssociatedObject(button, @selector(invoke), eventHandlerBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:eventHandlerBlock action:@selector(invoke) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
        [button.layer setBorderColor:[UIColor redColor].CGColor];
        [button.layer setBorderWidth:0.25];
        [self.view setNeedsDisplay];
        
        return button;
    });
    
    touch_handler = touch_handler_init(self.view)(^ (CGPoint touch_point) {
        if (!CGPointEqualToPoint(touch_point, CGPointZero)) { // ERROR: This is a workaround to a bug that sets the touch point to 0, 0 after touchesEnded
            [adder prepareData:vector2((float)touch_point.x, (float)touch_point.y)];
            [(CAShapeLayer *)self.view.layer.sublayers.firstObject setPath:[UIBezierPath bezierPathWithArcCenter:center_point radius:[adder sendComputeCommand] startAngle:degreesToRadians(180.0) endAngle:degreesToRadians(270.0) clockwise:TRUE].CGPath];
        }
    });
    [self.view setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{ (handle_touch = touch_handler(touches.anyObject))(); });
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{ handle_touch(); });
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{ handle_touch();
        enumerate_collection(buttons)(^ (UIButton * button, unsigned int index) {
            CGFloat x = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].x;
            CGFloat y = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].y;
            CGPoint button_center_point = CGPointMake((float)(*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].x,
                                                      (float)(*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].y);
            [button setCenter:button_center_point];
            printf("\nbutton (%s)\npoint %s\n", [[button description] UTF8String], [NSStringFromCGPoint(button.center) UTF8String]);
        });
    });
}

@end

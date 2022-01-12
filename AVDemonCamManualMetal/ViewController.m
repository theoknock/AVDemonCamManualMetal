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

static const MetalAdder * adder;
static CGPoint center_point;

static __strong UIButton * buttons[5];
static void (^(^populate_collection)(__strong UIButton * [5]))(UIButton * (^__strong)(unsigned int)) = ^ (__strong UIButton * button_collection[5]) {
    dispatch_queue_t enumerator_queue  = dispatch_queue_create("enumerator_queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t enumeration_queue = dispatch_queue_create_with_target("enumeration_queue", DISPATCH_QUEUE_SERIAL, dispatch_get_main_queue());
    return ^ (UIButton *(^enumeration)(unsigned int)) {
        dispatch_apply(5, enumerator_queue, ^(size_t index) {
            dispatch_async(enumeration_queue, ^{
                button_collection[index] = enumeration((unsigned int)index);
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
                enumeration(button_collection[index], (unsigned int)index);
            });
        });
    };
};

static void (^(^(^(^touch_handler_init)(UIView *))(void(^)(CGPoint)))(UITouch * _Nonnull))(void) = ^ (UIView * control_view) {
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

// The number of floats in each array, and the size of the arrays in bytes.
const unsigned int arrayLength = 0x05;
const unsigned int bufferSize = arrayLength * (sizeof(CaptureDevicePropertyControlLayout));

@implementation MetalAdder
{
    id<MTLDevice> _mDevice;
    
    // The compute pipeline generated from the compute kernel in the .metal shader file.
    id<MTLComputePipelineState> _mAddFunctionPSO;
    
    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _mCommandQueue;
    
    // Data and buffers to hold data
    id<MTLBuffer> captureDevicePropertyControlLayoutBuffer;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device arcCenter:(vector_float2)arc_center arcControlPoints:(matrix_float3x2)control_points
{
    self = [super init];
    if (self)
    {
        _mDevice = device;
        
        NSError* error = nil;
        
        // Load the shader files with a .metal file extension in the project
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
        
        // Create a compute pipeline state object.
        _mAddFunctionPSO = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
        if (_mAddFunctionPSO == nil)
        {
            //  If the Metal API validation is enabled, you can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state object, error %@.", error);
            return nil;
        }
        
        _mCommandQueue = [_mDevice newCommandQueue];
        if (_mCommandQueue == nil)
        {
            NSLog(@"Failed to find the command queue.");
            return nil;
        }
        
        captureDevicePropertyControlLayoutBuffer = [_mDevice newBufferWithLength:sizeof(CaptureDevicePropertyControlLayout) options:MTLResourceStorageModeShared];
        captureDevicePropertyControlLayoutBufferPtr = captureDevicePropertyControlLayoutBuffer.contents;
        captureDevicePropertyControlLayoutBufferPtr[0] = (CaptureDevicePropertyControlLayout) {
            .arc_touch_point      =  {0.0, 0.0},
            .button_center_points = {{0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}},
            .arc_radius           = 0.0,
            .arc_center           = arc_center,
            .arc_control_points   = control_points
        };
    }
    
    return self;
}

- (void)prepareData:(vector_float2)touch_point
{
//    CaptureDevicePropertyControlLayout * captureDevicePropertyControlLayoutBufferPtr = (CaptureDevicePropertyControlLayout *)captureDevicePropertyControlLayoutBuffer.contents;
    captureDevicePropertyControlLayoutBufferPtr[0] = (CaptureDevicePropertyControlLayout) {
        .arc_touch_point      = touch_point,
        .button_center_points = {
            {(*captureDevicePropertyControlLayoutBufferPtr).button_center_points[0].x, (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[0].y},
            {(*captureDevicePropertyControlLayoutBufferPtr).button_center_points[1].x, (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[1].y},
            {(*captureDevicePropertyControlLayoutBufferPtr).button_center_points[2].x, (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[2].y},
            {(*captureDevicePropertyControlLayoutBufferPtr).button_center_points[3].x, (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[3].y},
            {(*captureDevicePropertyControlLayoutBufferPtr).button_center_points[4].x, (*captureDevicePropertyControlLayoutBufferPtr).button_center_points[4].y}},
        .arc_radius           = (*captureDevicePropertyControlLayoutBufferPtr).arc_radius,
        .arc_center           = (*captureDevicePropertyControlLayoutBufferPtr).arc_center,
        .arc_control_points   = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points
    };
}

- (void)encodeAddCommand:(id<MTLComputeCommandEncoder>)computeEncoder {
    // Encode the pipeline state object and its parameters.
    [computeEncoder setComputePipelineState:_mAddFunctionPSO];
    [computeEncoder setBuffer:captureDevicePropertyControlLayoutBuffer offset:0 atIndex:0];
    
    MTLSize threadsPerThreadgroup = MTLSizeMake(MIN(sizeof(CaptureDevicePropertyControlLayout), (_mAddFunctionPSO.maxTotalThreadsPerThreadgroup / _mAddFunctionPSO.threadExecutionWidth)), 1, 1);
    MTLSize threadsPerGrid = MTLSizeMake(arrayLength, 1, 1);
    [computeEncoder dispatchThreads: threadsPerGrid
              threadsPerThreadgroup: threadsPerThreadgroup];
}

- (float) sendComputeCommand
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
            printf("control_layout_buffer.arc_touch_point == {%.1f, %.1f}\n",
                   (*captureDevicePropertyControlLayoutBufferPtr).arc_touch_point.x,
                   (*captureDevicePropertyControlLayoutBufferPtr).arc_touch_point.y);
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
            enumerate_collection(buttons)(^ (UIButton * button, unsigned int index) {
                CGFloat x = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].x;
                CGFloat y = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].y;
                CGPoint button_center_point = CGPointMake(x, y);
                [button setCenter:button_center_point];
                printf("\nbutton (%s)\npoint %s\n", [[button description] UTF8String], [NSStringFromCGPoint(button.center) UTF8String]);
            });
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
    [shape_layer setStrokeColor:[UIColor blueColor].CGColor];
    [shape_layer setFillColor:[UIColor clearColor].CGColor];
    [shape_layer setBackgroundColor:[UIColor clearColor].CGColor];
    [self.view.layer addSublayer:shape_layer];
    
    device = MTLCreateSystemDefaultDevice();
    center_point = CGPointMake(CGRectGetMaxX(self.view.frame), CGRectGetMaxY(self.view.frame));
    matrix_float3x2 control_points = {
        vector2((float)CGRectGetMinX(self.view.frame),(float)CGRectGetMaxY(self.view.frame)),
        vector2((float)CGRectGetMidX(self.view.frame),(float)CGRectGetMidY(self.view.frame)),
        vector2((float)CGRectGetMaxX(self.view.frame),(float)CGRectGetMinY(self.view.frame))};
    adder = [[MetalAdder alloc] initWithDevice:device arcCenter:vector2((float)center_point.x, (float)center_point.y) arcControlPoints:control_points];
    [adder prepareData:vector2((float)CGRectGetMidX(self.view.frame), (float)CGRectGetMidX(self.view.frame))];
    [adder sendComputeCommand];
    
    populate_collection(buttons)(^ UIButton * (unsigned int index) {
        UIButton * button;
        [button = [UIButton new] setTag:index];
        [button setBackgroundColor:[UIColor redColor]];
        [button setImage:[UIImage systemImageNamed:@"questionmark.circle" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:CGRectGetMidX(button.superview.frame) / 5]] forState:UIControlStateNormal];
        [button sizeToFit];
        [button setCenter:center_point];
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
    dispatch_barrier_async(dispatch_get_main_queue(), ^{ handle_touch(); });
}

@end

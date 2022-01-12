/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A class to manage all of the Metal objects this app creates.
 */

#import "MetalAdder.h"
#include "ShaderTypes.h"

#import <simd/simd.h>

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

- (matrix_float3x2) prepareData:(vector_float2)touch_point
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
    return (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points;
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
        };
    }(captureDevicePropertyControlLayoutBuffer)];
    
    return (*captureDevicePropertyControlLayoutBufferPtr).arc_radius;
}

@end

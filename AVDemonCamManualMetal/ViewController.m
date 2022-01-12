//
//  ViewController.m
//  AVDemonCamManualMetal
//
//  Created by Xcode Developer on 1/11/22.
//

#import "ViewController.h"
#import <Metal/Metal.h>
#import "MetalAdder.h"
#import "ShaderTypes.h"
#import <objc/runtime.h>

#define degreesToRadians(angleDegrees) (angleDegrees * M_PI / 180.0)

static const MetalAdder * adder;
static CGPoint center_point;

static __strong UIButton * buttons[5];
static void (^(^populate_collection)(__strong UIButton * [5]))(UIButton * (^__strong)(size_t)) = ^ (__strong UIButton * button_collection[5]) {
    dispatch_queue_t enumerator_queue  = dispatch_queue_create("enumerator_queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t enumeration_queue = dispatch_queue_create_with_target("enumeration_queue", DISPATCH_QUEUE_SERIAL, dispatch_get_main_queue());
    return ^ (UIButton *(^enumeration)(size_t)) {
        dispatch_apply(5, enumerator_queue, ^(size_t index) {
            dispatch_async(enumeration_queue, ^{
                button_collection[index] = enumeration(index);
            });
        });
    };
};

static void (^(^enumerate_collection)(__strong UIButton * [5]))(void (^__strong)(UIButton * _Nonnull, size_t)) = ^ (__strong UIButton * button_collection[5]) {
    dispatch_queue_t enumerator_queue  = dispatch_queue_create("enumerator_queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t enumeration_queue = dispatch_queue_create_with_target("enumeration_queue", DISPATCH_QUEUE_SERIAL, dispatch_get_main_queue());
    return ^ (void(^enumeration)(UIButton * _Nonnull, size_t)) {
        dispatch_apply(5, enumerator_queue, ^(size_t index) {
            dispatch_async(enumeration_queue, ^{
                enumeration(button_collection[index], index);
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
        vector2((float)CGRectGetMidX(self.view.frame),(float)CGRectGetMaxY(self.view.frame)),
        vector2((float)CGRectGetMidX(self.view.frame),(float)CGRectGetMidX(self.view.frame)),
        vector2((float)CGRectGetMaxX(self.view.frame),(float)CGRectGetMaxX(self.view.frame))};
    adder = [[MetalAdder alloc] initWithDevice:device arcCenter:vector2((float)center_point.x, (float)center_point.y) arcControlPoints:control_points];
    [adder prepareData:vector2((float)CGRectGetMidX(self.view.frame), (float)CGRectGetMidX(self.view.frame))];
    [adder sendComputeCommand];
    
    populate_collection(buttons)(^ UIButton * (size_t index) {
        UIButton * button = [[UIButton alloc] init];
        [button setTag:index];
        [button setBackgroundColor:[UIColor clearColor]];
        [button setImage:[UIImage systemImageNamed:@"questionmark.circle" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:CGRectGetMidX(button.superview.frame) / 5]] forState:UIControlStateNormal];
        [button sizeToFit];
        void (^eventHandlerBlock)(void) = ^{ };
        objc_setAssociatedObject(button, @selector(invoke), eventHandlerBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:eventHandlerBlock action:@selector(invoke) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
        
        return button;
    });
    
    enumerate_collection(buttons)(^ (UIButton * button, size_t index) {
//        CGFloat x = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].x;
//        CGFloat y = (*captureDevicePropertyControlLayoutBufferPtr).arc_control_points.columns[index].y;
//        CGPoint button_center_point = CGPointMake(x, y);
//        [button setCenter:button_center_point];
        printf("\nbutton (%s) %s\n", [[button description] UTF8String], [NSStringFromCGPoint(button.center) UTF8String]);
        
        [self.view setNeedsDisplay];
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

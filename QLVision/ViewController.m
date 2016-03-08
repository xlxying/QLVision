//
//  ViewController.m
//  QLVision
//
//  Created by LIU Can on 16/3/8.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import "ViewController.h"
#import "QLVision.h"
#import "QLVisionUtilities.h"

@interface ViewController ()<QLVisionDelegate>
{
    UIView *_previewView;
    AVCaptureVideoPreviewLayer *_previewLayer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // preview and AV layer
    _previewView = [[UIView alloc] initWithFrame:CGRectZero];
    _previewView.backgroundColor = [UIColor blackColor];
    CGRect previewFrame = CGRectMake(0, 0.0f, MOZWIDTH, MOZHEIGHT);
    _previewView.frame = previewFrame;
    _previewLayer = [[QLVision sharedInstance] previewLayer];
    _previewLayer.frame = _previewView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer addSublayer:_previewLayer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self _resetCapture];
    [[QLVision sharedInstance] startPreview:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[QLVision sharedInstance] stopPreview];
}

- (void)_resetCapture
{
    
    QLVision *vision = [QLVision sharedInstance];
    vision.delegate = self;
    
    vision.cameraMode = QLCameraModeVideo;
    //vision.cameraMode = PBJCameraModePhoto; // PHOTO: uncomment to test photo capture
    vision.cameraOrientation = QLCameraOrientationPortrait;
//    vision.focusMode = QLFocusModeContinuousAutoFocus;
    vision.outputFormat = QLOutputFormatPreset;
//    vision.videoRenderingEnabled = YES;
//    vision.additionalCompressionProperties = @{AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline30}; // AVVideoProfileLevelKey requires specific captureSessionPreset
    
    // specify a maximum duration with the following property
    // vision.maximumCaptureDuration = CMTimeMakeWithSeconds(5, 600); // ~ 5 seconds
}

#pragma mark - PBJVisionDelegate

// session

- (void)visionSessionWillStart:(QLVision *)vision
{
    NSLog(@"Session will start");
}

- (void)visionSessionDidStart:(QLVision *)vision
{
    if (![_previewView superview]) {
        [self.view addSubview:_previewView];
//        [self.view bringSubviewToFront:_gestureView];
    }
}

- (void)visionSessionDidStop:(QLVision *)vision
{
    [_previewView removeFromSuperview];
}

// preview

- (void)visionSessionDidStartPreview:(QLVision *)vision
{
    NSLog(@"Camera preview did start");
    
}

- (void)visionSessionDidStopPreview:(QLVision *)vision
{
    NSLog(@"Camera preview did stop");
}

// device

- (void)visionCameraDeviceWillChange:(QLVision *)vision
{
    NSLog(@"Camera device will change");
}

- (void)visionCameraDeviceDidChange:(QLVision *)vision
{
    NSLog(@"Camera device did change");
}

// mode

- (void)visionCameraModeWillChange:(QLVision *)vision
{
    NSLog(@"Camera mode will change");
}

- (void)visionCameraModeDidChange:(QLVision *)vision
{
    NSLog(@"Camera mode did change");
}

// format

- (void)visionOutputFormatWillChange:(QLVision *)vision
{
    NSLog(@"Output format will change");
}

- (void)visionOutputFormatDidChange:(QLVision *)vision
{
    NSLog(@"Output format did change");
}
@end

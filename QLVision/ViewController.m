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
#import "RecordView.h"
#import "UIColor+Hex.h"

#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController ()<QLVisionDelegate,UIGestureRecognizerDelegate>
{
    UIView *_previewView;
    AVCaptureVideoPreviewLayer *_previewLayer;
    RecordView *_recordView;
    
    ALAssetsLibrary *_assetLibrary;
    __block NSDictionary *_currentVideo;
    __block NSDictionary *_currentPhoto;
    
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
    UITapGestureRecognizer *_focusTapGestureRecognizer;
    UITapGestureRecognizer *_photoTapGestureRecognizer;
}
@end

@implementation ViewController
- (void)dealloc
{
//    [UIApplication sharedApplication].idleTimerDisabled = NO;
    _longPressGestureRecognizer.delegate = nil;
    _focusTapGestureRecognizer.delegate = nil;
    _photoTapGestureRecognizer.delegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _assetLibrary = [[ALAssetsLibrary alloc] init];
    
    // preview and AV layer
    _previewView = [[UIView alloc] initWithFrame:CGRectZero];
    _previewView.backgroundColor = [UIColor blackColor];
    CGRect previewFrame = CGRectMake(0.0f, 0.0f, MOZWIDTH, MOZHEIGHT);
    _previewView.frame = previewFrame;
    _previewLayer = [[QLVision sharedInstance] previewLayer];
    _previewLayer.frame = _previewView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer addSublayer:_previewLayer];
    
    _recordView = [[RecordView alloc] initWithFrame:CGRectMake((MOZWIDTH-76.0)/2, MOZHEIGHT-20.0-76.0, 76.0, 76.0)];
    _recordView.arcFinishColor = [UIColor colorWithHexString:@"#BFBFBF"];
    _recordView.arcUnfinishColor = [UIColor colorWithHexString:@"#DA3A3A"];
    _recordView.arcBackColor = [UIColor colorWithHexString:@"#FFFFFF"];
    _recordView.percent = 1;
    [_recordView setUserInteractionEnabled:YES];
    
    // tap to focus
    _photoTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePhotoTapGesterRecognizer:)];
    _photoTapGestureRecognizer.delegate = self;
    _photoTapGestureRecognizer.numberOfTapsRequired = 1;
    _photoTapGestureRecognizer.enabled = YES;
    [_recordView addGestureRecognizer:_photoTapGestureRecognizer];
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
    
    vision.cameraMode = QLCameraModePhoto;
    //vision.cameraMode = PBJCameraModePhoto; // PHOTO: uncomment to test photo capture
    vision.cameraOrientation = QLCameraOrientationPortrait;
    vision.focusMode = QLFocusModeContinuousAutoFocus;
    vision.outputFormat = QLOutputFormatPreset;
    vision.captureSessionPreset = AVCaptureSessionPresetPhoto;
//    vision.videoRenderingEnabled = YES;
//    vision.additionalCompressionProperties = @{AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline30}; // AVVideoProfileLevelKey requires specific captureSessionPreset
    
    // specify a maximum duration with the following property
    // vision.maximumCaptureDuration = CMTimeMakeWithSeconds(5, 600); // ~ 5 seconds
}

#pragma mark - UIGestureRecognizer

- (void)_handlePhotoTapGesterRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    [[QLVision sharedInstance] capturePhoto];
}

#pragma mark - QLVisionDelegate

// session

- (void)visionSessionWillStart:(QLVision *)vision
{
    NSLog(@"Session will start");
}

- (void)visionSessionDidStart:(QLVision *)vision
{
    if (![_previewView superview]) {
        [self.view addSubview:_previewView];
        [self.view addSubview:_recordView];
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

// focus / exposure

- (void)visionWillStartFocus:(QLVision *)vision
{
}

- (void)visionDidStopFocus:(QLVision *)vision
{
//    if (_focusView && [_focusView superview]) {
//        [_focusView stopAnimation];
//    }
}

- (void)visionWillChangeExposure:(QLVision *)vision
{
}

- (void)visionDidChangeExposure:(QLVision *)vision
{
//    if (_focusView && [_focusView superview]) {
//        [_focusView stopAnimation];
//    }
}

// photo

- (void)visionWillCapturePhoto:(QLVision *)vision
{
}

- (void)visionDidCapturePhoto:(QLVision *)vision
{
}

- (void)vision:(QLVision *)vision capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    if (error) {
        // handle error properly
        return;
    }
    _currentPhoto = photoDict;
    
    // save to library
    NSData *photoData = _currentPhoto[QLVisionPhotoJPEGKey];
    NSDictionary *metadata = _currentPhoto[QLVisionPhotoMetadataKey];
    [_assetLibrary writeImageDataToSavedPhotosAlbum:photoData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error1) {
        if (error1 || !assetURL) {
            // handle error properly
            return;
        }
        
        NSString *albumName = @"QLVision";
        __block BOOL albumFound = NO;
        [_assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if ([albumName compare:[group valueForProperty:ALAssetsGroupPropertyName]] == NSOrderedSame) {
                albumFound = YES;
                [_assetLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                    [group addAsset:asset];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Photo Saved!" message: @"Saved to the camera roll."
                                                                   delegate:nil
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:@"OK", nil];
                    [alert show];
                } failureBlock:nil];
            }
            if (!group && !albumFound) {
                __weak ALAssetsLibrary *blockSafeLibrary = _assetLibrary;
                [_assetLibrary addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group1) {
                    [blockSafeLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                        [group1 addAsset:asset];
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Photo Saved!" message: @"Saved to the camera roll."
                                                                       delegate:nil
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:@"OK", nil];
                        [alert show];
                    } failureBlock:nil];
                } failureBlock:nil];
            }
        } failureBlock:nil];
    }];
    
    _currentPhoto = nil;
}
@end

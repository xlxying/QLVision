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
    
    BOOL _recording;
}
@end

@implementation ViewController
- (void)dealloc
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
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
    
    // touch to record
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressGestureRecognizer:)];
    _longPressGestureRecognizer.delegate = self;
    _longPressGestureRecognizer.minimumPressDuration = 0.05f;
    _longPressGestureRecognizer.allowableMovement = 10.0f;
    [_recordView addGestureRecognizer:_longPressGestureRecognizer];
    
    // tap to focus
    _focusTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleFocusTapGesterRecognizer:)];
    _focusTapGestureRecognizer.delegate = self;
    _focusTapGestureRecognizer.numberOfTapsRequired = 1;
    _focusTapGestureRecognizer.enabled = NO;
    [_previewView addGestureRecognizer:_focusTapGestureRecognizer];
    
    // tap to focus
    _photoTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePhotoTapGesterRecognizer:)];
    _photoTapGestureRecognizer.delegate = self;
    _photoTapGestureRecognizer.numberOfTapsRequired = 1;
    _photoTapGestureRecognizer.enabled = NO;
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

- (void)_startCapture
{
    //让程序不锁屏
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    [_recordView setFrame:CGRectMake((MOZWIDTH-96.0)/2, MOZHEIGHT-10.0-96.0, 96.0, 96.0)];
    _recordView.arcBackColor = [UIColor colorWithHexString:@"#DA3A3A"];
    [_recordView startAnim];
//    [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//        _instructionLabel.alpha = 0;
//        _instructionLabel.transform = CGAffineTransformMakeTranslation(0, 10.0f);
//    } completion:^(BOOL finished) {
//    }];
    [[QLVision sharedInstance] startVideoCapture];
}

- (void)_resetCapture
{
    
    QLVision *vision = [QLVision sharedInstance];
    vision.delegate = self;
    
//    vision.cameraMode = QLCameraModePhoto;
    vision.cameraMode = QLCameraModeVideo; // PHOTO: uncomment to test photo capture
    vision.cameraOrientation = QLCameraOrientationPortrait;
    vision.focusMode = QLFocusModeContinuousAutoFocus;
    vision.outputFormat = QLOutputFormatPreset;
    vision.captureSessionPreset = AVCaptureSessionPreset640x480;
    vision.videoRenderingEnabled = YES;
    vision.additionalCompressionProperties = @{AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline30}; // AVVideoProfileLevelKey requires specific captureSessionPreset
    
    // specify a maximum duration with the following property
     vision.maximumCaptureDuration = CMTimeMakeWithSeconds(60, 600); // ~ 60 seconds
}

- (void)_endCapture
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_recordView setFrame:CGRectMake((MOZWIDTH-76.0)/2, MOZHEIGHT-20.0-76.0, 76.0, 76.0)];
    _recordView.arcBackColor = [UIColor colorWithHexString:@"#FFFFFF"];
    [_recordView stopAnim];
    [[QLVision sharedInstance] endVideoCapture];
//    _effectsViewController.view.hidden = YES;
}

#pragma mark - UIGestureRecognizer

- (void)_handlePhotoTapGesterRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    [[QLVision sharedInstance] capturePhoto];
}

- (void)_handleLongPressGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    // PHOTO: uncomment to test photo capture
    //    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    //        [[PBJVision sharedInstance] capturePhoto];
    //        return;
    //    }
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            if (!_recording)
                [self _startCapture];
//            else
//                [self _resumeCapture];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
//            [self _pauseCapture];
            [self _endCapture];
            break;
        }
        default:
            break;
    }
}

- (void)_handleFocusTapGesterRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint tapPoint = [gestureRecognizer locationInView:_previewView];
    
    // auto focus is occuring, display focus view
    CGPoint point = tapPoint;
    
//    CGRect focusFrame = _focusView.frame;
//#if defined(__LP64__) && __LP64__
//    focusFrame.origin.x = rint(point.x - (focusFrame.size.width * 0.5));
//    focusFrame.origin.y = rint(point.y - (focusFrame.size.height * 0.5));
//#else
//    focusFrame.origin.x = rintf(point.x - (focusFrame.size.width * 0.5f));
//    focusFrame.origin.y = rintf(point.y - (focusFrame.size.height * 0.5f));
//#endif
//    [_focusView setFrame:focusFrame];
//    
//    [_previewView addSubview:_focusView];
//    [_focusView startAnimation];
//    
//    CGPoint adjustPoint = [PBJVisionUtilities convertToPointOfInterestFromViewCoordinates:tapPoint inFrame:_previewView.frame];
//    [[QLVision sharedInstance] focusExposeAndAdjustWhiteBalanceAtAdjustedPoint:adjustPoint];
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

// video capture

- (void)visionDidStartVideoCapture:(QLVision *)vision
{
//    [_strobeView start];
    _recording = YES;
}

- (void)visionDidPauseVideoCapture:(QLVision *)vision
{
//    [_strobeView stop];
}

- (void)visionDidResumeVideoCapture:(QLVision *)vision
{
//    [_strobeView start];
}

- (void)vision:(QLVision *)vision capturedVideo:(NSDictionary *)videoDict error:(NSError *)error
{
    _recording = NO;
    
    if (error && [error.domain isEqual:QLVisionErrorDomain] && error.code == QLVisionErrorCancelled) {
        NSLog(@"recording session cancelled");
        return;
    } else if (error) {
        NSLog(@"encounted an error in video capture (%@)", error);
        return;
    }
    
    _currentVideo = videoDict;
    
    NSString *videoPath = [_currentVideo  objectForKey:QLVisionVideoPathKey];
    [_assetLibrary writeVideoAtPathToSavedPhotosAlbum:[NSURL URLWithString:videoPath] completionBlock:^(NSURL *assetURL, NSError *error1) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Video Saved!" message: @"Saved to the camera roll."
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
    }];
}

// progress

- (void)vision:(QLVision *)vision didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    //    NSLog(@"captured audio (%f) seconds", vision.capturedAudioSeconds);
}

- (void)vision:(QLVision *)vision didCaptureAudioSample:(CMSampleBufferRef)sampleBuffer
{
    //    NSLog(@"captured video (%f) seconds", vision.capturedVideoSeconds);
}
@end

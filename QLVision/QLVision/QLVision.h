//
//  QLVision.h
//  QLVision
//
//  Created by LIU Can on 16/3/8.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN

// vision types

typedef NS_ENUM(NSInteger, QLCameraDevice) {
    QLCameraDeviceBack = 0,
    QLCameraDeviceFront
};

typedef NS_ENUM(NSInteger, QLCameraMode) {
    QLCameraModePhoto = 0,
    QLCameraModeVideo
};

typedef NS_ENUM(NSInteger, QLCameraOrientation) {
    QLCameraOrientationPortrait = AVCaptureVideoOrientationPortrait,
    QLCameraOrientationPortraitUpsideDown = AVCaptureVideoOrientationPortraitUpsideDown,
    QLCameraOrientationLandscapeRight = AVCaptureVideoOrientationLandscapeRight,
    QLCameraOrientationLandscapeLeft = AVCaptureVideoOrientationLandscapeLeft,
};

typedef NS_ENUM(NSInteger, QLFocusMode) {
    QLFocusModeLocked = AVCaptureFocusModeLocked,
    QLFocusModeAutoFocus = AVCaptureFocusModeAutoFocus,
    QLFocusModeContinuousAutoFocus = AVCaptureFocusModeContinuousAutoFocus
};

typedef NS_ENUM(NSInteger, QLExposureMode) {
    QLExposureModeLocked = AVCaptureExposureModeLocked,
    QLExposureModeAutoExpose = AVCaptureExposureModeAutoExpose,
    QLExposureModeContinuousAutoExposure = AVCaptureExposureModeContinuousAutoExposure
};

typedef NS_ENUM(NSInteger, QLOutputFormat) {
    QLOutputFormatPreset = 0,
    QLOutputFormatSquare, // 1:1
    QLOutputFormatWidescreen, // 16:9
    QLOutputFormatStandard // 4:3
};

// QLError

extern NSString * const QLVisionErrorDomain;

typedef NS_ENUM(NSInteger, QLVisionErrorType)
{
    QLVisionErrorUnknown = -1,
    QLVisionErrorCancelled = 100,
    QLVisionErrorSessionFailed = 101,
    QLVisionErrorBadOutputFile = 102,
    QLVisionErrorOutputFileExists = 103,
    QLVisionErrorCaptureFailed = 104,
};

// photo dictionary keys

extern NSString * const QLVisionPhotoMetadataKey;
extern NSString * const QLVisionPhotoJPEGKey;
extern NSString * const QLVisionPhotoImageKey;
extern NSString * const QLVisionPhotoThumbnailKey; // 160x120

@protocol QLVisionDelegate;
@interface QLVision : NSObject
//单例对象
+ (QLVision *)sharedInstance;
//代理
@property (nonatomic, weak, nullable) id<QLVisionDelegate> delegate;

// session

@property (nonatomic, readonly, getter=isCaptureSessionActive) BOOL captureSessionActive;

// setup

@property (nonatomic) QLCameraOrientation cameraOrientation;
@property (nonatomic) QLCameraMode cameraMode;
@property (nonatomic) QLCameraDevice cameraDevice;
// Indicates whether the capture session will make use of the app’s shared audio session. Allows you to
// use a previously configured audios session with a category such as AVAudioSessionCategoryAmbient.
@property (nonatomic) BOOL usesApplicationAudioSession;
- (BOOL)isCameraDeviceAvailable:(QLCameraDevice)cameraDevice;

// video output settings

@property (nonatomic, copy) NSDictionary *additionalVideoProperties;
@property (nonatomic, copy) NSString *captureSessionPreset;
@property (nonatomic, copy) NSString *captureDirectory;
@property (nonatomic) QLOutputFormat outputFormat;

// preview

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic) BOOL autoUpdatePreviewOrientation;//是否自动根据cemera方向改变preview方向
@property (nonatomic) QLCameraOrientation previewOrientation;
@property (nonatomic) BOOL autoFreezePreviewDuringCapture;//当拍照的时候是否自动冻结preview显示的图像

- (void)startPreview:(NSError *__autoreleasing *)error;
- (void)stopPreview;

- (void)freezePreview;
- (void)unfreezePreview;

// focus, exposure, white balance

// note: focus and exposure modes change when adjusting on point
- (BOOL)isFocusPointOfInterestSupported;
- (void)focusExposeAndAdjustWhiteBalanceAtAdjustedPoint:(CGPoint)adjustedPoint;

@property (nonatomic) QLFocusMode focusMode;
@property (nonatomic, readonly, getter=isFocusLockSupported) BOOL focusLockSupported;
- (void)focusAtAdjustedPointOfInterest:(CGPoint)adjustedPoint;
- (BOOL)isAdjustingFocus;

@property (nonatomic) QLExposureMode exposureMode;
@property (nonatomic, readonly, getter=isExposureLockSupported) BOOL exposureLockSupported;
- (void)exposeAtAdjustedPointOfInterest:(CGPoint)adjustedPoint;
- (BOOL)isAdjustingExposure;

// photo

@property (nonatomic, readonly) BOOL canCapturePhoto;
- (void)capturePhoto;
@end

@protocol QLVisionDelegate <NSObject>
@optional

// session

- (void)visionSessionWillStart:(QLVision *)vision;
- (void)visionSessionDidStart:(QLVision *)vision;
- (void)visionSessionDidStop:(QLVision *)vision;

- (void)visionSessionWasInterrupted:(QLVision *)vision;
- (void)visionSessionInterruptionEnded:(QLVision *)vision;

// device / mode / format

- (void)visionCameraDeviceWillChange:(QLVision *)vision;
- (void)visionCameraDeviceDidChange:(QLVision *)vision;

- (void)visionCameraModeWillChange:(QLVision *)vision;
- (void)visionCameraModeDidChange:(QLVision *)vision;

- (void)visionOutputFormatWillChange:(QLVision *)vision;
- (void)visionOutputFormatDidChange:(QLVision *)vision;

// focus / exposure

- (void)visionWillStartFocus:(QLVision *)vision;
- (void)visionDidStopFocus:(QLVision *)vision;

- (void)visionWillChangeExposure:(QLVision *)vision;
- (void)visionDidChangeExposure:(QLVision *)vision;


// preview

- (void)visionSessionDidStartPreview:(QLVision *)vision;
- (void)visionSessionDidStopPreview:(QLVision *)vision;

// photo

- (void)visionWillCapturePhoto:(QLVision *)vision;
- (void)visionDidCapturePhoto:(QLVision *)vision;
- (void)vision:(QLVision *)vision capturedPhoto:(nullable NSDictionary *)photoDict error:(nullable NSError *)error;

// video

- (NSString *)vision:(QLVision *)vision willStartVideoCaptureToFile:(NSString *)fileName;
- (void)visionDidStartVideoCapture:(QLVision *)vision;
- (void)visionDidPauseVideoCapture:(QLVision *)vision; // stopped but not ended
- (void)visionDidResumeVideoCapture:(QLVision *)vision;
- (void)visionDidEndVideoCapture:(QLVision *)vision;
- (void)vision:(QLVision *)vision capturedVideo:(nullable NSDictionary *)videoDict error:(nullable NSError *)error;

// video capture progress

- (void)vision:(QLVision *)vision didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)vision:(QLVision *)vision didCaptureAudioSample:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
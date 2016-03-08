//
//  QLVision.m
//  QLVision
//
//  Created by LIU Can on 16/3/8.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import "QLVision.h"
#import "QLVisionUtilities.h"

#import <UIKit/UIKit.h>

NSString * const QLVisionErrorDomain = @"QLVisionErrorDomain";

@interface QLVision () <
AVCaptureAudioDataOutputSampleBufferDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate>
{
    //自定义摄像头必要属性
    AVCaptureSession *_captureSession;
    
    AVCaptureDevice *_captureDeviceFront;
    AVCaptureDevice *_captureDeviceBack;
    AVCaptureDevice *_captureDeviceAudio;
    
    AVCaptureDeviceInput *_captureDeviceInputFront;
    AVCaptureDeviceInput *_captureDeviceInputBack;
    AVCaptureDeviceInput *_captureDeviceInputAudio;
    
    AVCaptureStillImageOutput *_captureOutputPhoto;
    AVCaptureAudioDataOutput *_captureOutputAudio;
    AVCaptureVideoDataOutput *_captureOutputVideo;
    
    dispatch_queue_t _captureSessionDispatchQueue;
    dispatch_queue_t _captureCaptureDispatchQueue;
    
    QLCameraDevice _cameraDevice;
    QLCameraMode _cameraMode;
    QLCameraOrientation _cameraOrientation;
    
    QLCameraOrientation _previewOrientation;
    BOOL _autoUpdatePreviewOrientation;
    BOOL _autoFreezePreviewDuringCapture;
    BOOL _usesApplicationAudioSession;
    
    AVCaptureDevice *_currentDevice;
    AVCaptureDeviceInput *_currentInput;
    AVCaptureOutput *_currentOutput;
    
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    // flags，各种开关
    
    struct {
        unsigned int previewRunning:1;
        unsigned int changingModes:1;
        unsigned int recording:1;
        unsigned int paused:1;
        unsigned int interrupted:1;
        unsigned int videoWritten:1;
        unsigned int videoRenderingEnabled:1;
        unsigned int audioCaptureEnabled:1;
        unsigned int thumbnailEnabled:1;
        unsigned int defaultVideoThumbnails:1;
        unsigned int videoCaptureFrame:1;
    } __block _flags;
}

@property (nonatomic) AVCaptureDevice *currentDevice;

@end

@implementation QLVision
@synthesize delegate = _delegate;
@synthesize currentDevice = _currentDevice;
@synthesize previewLayer = _previewLayer;
@synthesize cameraOrientation = _cameraOrientation;
@synthesize previewOrientation = _previewOrientation;
@synthesize autoUpdatePreviewOrientation = _autoUpdatePreviewOrientation;
@synthesize autoFreezePreviewDuringCapture = _autoFreezePreviewDuringCapture;
@synthesize usesApplicationAudioSession = _usesApplicationAudioSession;
@synthesize cameraDevice = _cameraDevice;
@synthesize cameraMode = _cameraMode;
@synthesize outputFormat = _outputFormat;
@synthesize captureSessionPreset = _captureSessionPreset;
@synthesize captureDirectory = _captureDirectory;
@synthesize additionalVideoProperties = _additionalVideoProperties;

#pragma mark - singleton

+ (QLVision *)sharedInstance
{
    static QLVision *singleton = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        singleton = [[QLVision alloc] init];
    });
    return singleton;
}

#pragma mark - getters/setters

- (BOOL)isVideoWritten
{
    return _flags.videoWritten;
}

- (BOOL)isCaptureSessionActive
{
    return ([_captureSession isRunning]);
}

- (BOOL)isRecording
{
    return _flags.recording;
}

- (BOOL)isPaused
{
    return _flags.paused;
}

- (void)setVideoRenderingEnabled:(BOOL)videoRenderingEnabled
{
    _flags.videoRenderingEnabled = (unsigned int)videoRenderingEnabled;
}

- (BOOL)isVideoRenderingEnabled
{
    return _flags.videoRenderingEnabled;
}

- (void)setAudioCaptureEnabled:(BOOL)audioCaptureEnabled
{
    _flags.audioCaptureEnabled = (unsigned int)audioCaptureEnabled;
}

- (BOOL)isAudioCaptureEnabled
{
    return _flags.audioCaptureEnabled;
}

- (void)setThumbnailEnabled:(BOOL)thumbnailEnabled
{
    _flags.thumbnailEnabled = (unsigned int)thumbnailEnabled;
}

- (BOOL)thumbnailEnabled
{
    return _flags.thumbnailEnabled;
}

- (void)setDefaultVideoThumbnails:(BOOL)defaultVideoThumbnails
{
    _flags.defaultVideoThumbnails = (unsigned int)defaultVideoThumbnails;
}

- (BOOL)defaultVideoThumbnails
{
    return _flags.defaultVideoThumbnails;
}

- (void)setCameraOrientation:(QLCameraOrientation)cameraOrientation
{
    if (cameraOrientation == _cameraOrientation)
        return;
    _cameraOrientation = cameraOrientation;
    
    if (self.autoUpdatePreviewOrientation) {
        [self setPreviewOrientation:cameraOrientation];
    }
}

- (void)setPreviewOrientation:(QLCameraOrientation)previewOrientation {
    if (previewOrientation == _previewOrientation)
        return;
    
    if ([_previewLayer.connection isVideoOrientationSupported]) {
        _previewOrientation = previewOrientation;
        [self _setOrientationForConnection:_previewLayer.connection];
    }
}

- (void)_setOrientationForConnection:(AVCaptureConnection *)connection
{
    if (!connection || ![connection isVideoOrientationSupported])
        return;
    
    AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
    switch (_cameraOrientation) {
        case QLCameraOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case QLCameraOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case QLCameraOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case QLCameraOrientationPortrait:
        default:
            break;
    }
    
    [connection setVideoOrientation:orientation];
}

- (void)_setCameraMode:(QLCameraMode)cameraMode cameraDevice:(QLCameraDevice)cameraDevice outputFormat:(QLOutputFormat)outputFormat
{
    BOOL changeDevice = (_cameraDevice != cameraDevice);
    BOOL changeMode = (_cameraMode != cameraMode);
    BOOL changeOutputFormat = (_outputFormat != outputFormat);
    
//    DLog(@"change device (%d) mode (%d) format (%d)", changeDevice, changeMode, changeOutputFormat);
    
    if (!changeMode && !changeDevice && !changeOutputFormat) {
        return;
    }
    
    if (changeDevice && [_delegate respondsToSelector:@selector(visionCameraDeviceWillChange:)]) {
        [_delegate performSelector:@selector(visionCameraDeviceWillChange:) withObject:self];
    }
    if (changeMode && [_delegate respondsToSelector:@selector(visionCameraModeWillChange:)]) {
        [_delegate performSelector:@selector(visionCameraModeWillChange:) withObject:self];
    }
    if (changeOutputFormat && [_delegate respondsToSelector:@selector(visionOutputFormatWillChange:)]) {
        [_delegate performSelector:@selector(visionOutputFormatWillChange:) withObject:self];
    }
    
    _flags.changingModes = YES;
    
    _cameraDevice = cameraDevice;
    _cameraMode = cameraMode;
    _outputFormat = outputFormat;
    
    QLVisionBlock didChangeBlock = ^{
        _flags.changingModes = NO;
        
        if (changeDevice && [_delegate respondsToSelector:@selector(visionCameraDeviceDidChange:)]) {
            [_delegate performSelector:@selector(visionCameraDeviceDidChange:) withObject:self];
        }
        if (changeMode && [_delegate respondsToSelector:@selector(visionCameraModeDidChange:)]) {
            [_delegate performSelector:@selector(visionCameraModeDidChange:) withObject:self];
        }
        if (changeOutputFormat && [_delegate respondsToSelector:@selector(visionOutputFormatDidChange:)]) {
            [_delegate performSelector:@selector(visionOutputFormatDidChange:) withObject:self];
        }
    };
    
    // since there is no session in progress, set and bail
    if (!_captureSession) {
        _flags.changingModes = NO;
        
        didChangeBlock();
        
        return;
    }
    
    [self _enqueueBlockOnCaptureSessionQueue:^{
        // camera is already setup, no need to call _setupCamera
        [self _setupSession:nil];
        
//        [self setMirroringMode:_mirroringMode];
        
        [self _enqueueBlockOnMainQueue:didChangeBlock];
    }];
}

- (void)setCameraDevice:(QLCameraDevice)cameraDevice
{
    [self _setCameraMode:_cameraMode cameraDevice:cameraDevice outputFormat:_outputFormat];
}

- (void)setCaptureSessionPreset:(NSString *)captureSessionPreset
{
    _captureSessionPreset = captureSessionPreset;
    if ([_captureSession canSetSessionPreset:captureSessionPreset]){
        [self _commitBlock:^{
            [_captureSession setSessionPreset:captureSessionPreset];
        }];
    }
}

- (void)setCameraMode:(QLCameraMode)cameraMode
{
    [self _setCameraMode:cameraMode cameraDevice:_cameraDevice outputFormat:_outputFormat];
}

- (void)setOutputFormat:(QLOutputFormat)outputFormat
{
    [self _setCameraMode:_cameraMode cameraDevice:_cameraDevice outputFormat:outputFormat];
}

- (BOOL)isCameraDeviceAvailable:(QLCameraDevice)cameraDevice
{
    return [UIImagePickerController isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)cameraDevice];
}

- (void) _setCurrentDevice:(AVCaptureDevice *)device
{
    _currentDevice  = device;
//    _exposureMode   = (PBJExposureMode)device.exposureMode;
//    _focusMode      = (PBJFocusMode)device.focusMode;
}

#pragma mark - init

- (id)init
{
    self = [super init];
    if (self) {
        
        _captureSessionPreset = AVCaptureSessionPresetMedium;
        _captureDirectory = nil;
        
        _autoUpdatePreviewOrientation = YES;
        _autoFreezePreviewDuringCapture = YES;
        _usesApplicationAudioSession = NO;
        
        // default flags
        _flags.thumbnailEnabled = YES;
        _flags.defaultVideoThumbnails = YES;
        _flags.audioCaptureEnabled = YES;
        
        // setup queues
        _captureSessionDispatchQueue = dispatch_queue_create("PBJVisionSession", DISPATCH_QUEUE_SERIAL); // protects session
        _captureCaptureDispatchQueue = dispatch_queue_create("PBJVisionCapture", DISPATCH_QUEUE_SERIAL); // protects capture
        
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _delegate = nil;
}

#pragma mark - camera

// only call from the session queue
- (void)_setupCamera:(NSError *__autoreleasing *)error
{
    if (_captureSession)
        return;
    
    // create session
    _captureSession = [[AVCaptureSession alloc] init];
    
    if (_usesApplicationAudioSession) {
        _captureSession.usesApplicationAudioSession = YES;
    }
    
    // capture devices
    _captureDeviceFront = [QLVisionUtilities captureDeviceForPosition:AVCaptureDevicePositionFront];
    _captureDeviceBack = [QLVisionUtilities captureDeviceForPosition:AVCaptureDevicePositionBack];
    
    // capture device inputs
    NSError *error2 = nil;
    _captureDeviceInputFront = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceFront error:&error2];
    if (error2 != nil) {
        if (error != nil) {
            *error = error2;
            return;
        }
    }
    
    _captureDeviceInputBack = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceBack error:&error2];
    if (error2 != nil) {
        if (error != nil) {
            *error = error2;
            return;
        }
    }
    
    if (_cameraMode != QLCameraModePhoto && _flags.audioCaptureEnabled) {
        _captureDeviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        _captureDeviceInputAudio = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceAudio error:&error2];
        
        if (error2 != nil) {
            if (error != nil) {
                *error = error2;
                return;
            }
        }
    }
    
    // capture device ouputs
    _captureOutputPhoto = [[AVCaptureStillImageOutput alloc] init];
    if (_cameraMode != QLCameraModePhoto && _flags.audioCaptureEnabled) {
        _captureOutputAudio = [[AVCaptureAudioDataOutput alloc] init];
    }
    _captureOutputVideo = [[AVCaptureVideoDataOutput alloc] init];
    
    if (_cameraMode != QLCameraModePhoto && _flags.audioCaptureEnabled) {
        [_captureOutputAudio setSampleBufferDelegate:self queue:_captureCaptureDispatchQueue];
    }
    [_captureOutputVideo setSampleBufferDelegate:self queue:_captureCaptureDispatchQueue];
    
    // add notification observers
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter addObserver:self selector:@selector(_sessionRuntimeErrored:) name:AVCaptureSessionRuntimeErrorNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionStarted:) name:AVCaptureSessionDidStartRunningNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionStopped:) name:AVCaptureSessionDidStopRunningNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:_captureSession];
    
}

// only call from the session queue
- (void)_destroyCamera
{
    if (!_captureSession)
        return;
    
    // remove notification observers (we don't want to just 'remove all' because we're also observing background notifications
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:_captureSession];
    
    _captureOutputPhoto = nil;
    _captureOutputAudio = nil;
    _captureOutputVideo = nil;
    
    _captureDeviceAudio = nil;
    _captureDeviceInputAudio = nil;
    _captureDeviceInputFront = nil;
    _captureDeviceInputBack = nil;
    _captureDeviceFront = nil;
    _captureDeviceBack = nil;
    
    _captureSession = nil;
    _currentDevice = nil;
    _currentInput = nil;
    _currentOutput = nil;
    
//    DLog(@"camera destroyed");
}

#pragma mark - AVCaptureSession

//- (BOOL)_canSessionCaptureWithOutput:(AVCaptureOutput *)captureOutput
//{
//    BOOL sessionContainsOutput = [[_captureSession outputs] containsObject:captureOutput];
//    BOOL outputHasConnection = ([captureOutput connectionWithMediaType:AVMediaTypeVideo] != nil);
//    return (sessionContainsOutput && outputHasConnection);
//}

// _setupSession is always called from the captureSession queue
- (void)_setupSession:(NSError *__autoreleasing *)error
{
    if (!_captureSession) {
//        DLog(@"error, no session running to setup");
        return;
    }
    
    BOOL shouldSwitchDevice = (_currentDevice == nil) ||
    ((_currentDevice == _captureDeviceFront) && (_cameraDevice != QLCameraDeviceFront)) ||
    ((_currentDevice == _captureDeviceBack) && (_cameraDevice != QLCameraDeviceBack));
    
    BOOL shouldSwitchMode = (_currentOutput == nil) ||
    ((_currentOutput == _captureOutputPhoto) && (_cameraMode != QLCameraModePhoto)) ||
    ((_currentOutput == _captureOutputVideo) && (_cameraMode != QLCameraModeVideo));
    
//    DLog(@"switchDevice %d switchMode %d", shouldSwitchDevice, shouldSwitchMode);
    
    if (!shouldSwitchDevice && !shouldSwitchMode)
        return;
    
    AVCaptureDeviceInput *newDeviceInput = nil;
    AVCaptureOutput *newCaptureOutput = nil;
    AVCaptureDevice *newCaptureDevice = nil;
    
    [_captureSession beginConfiguration];
    
    // setup session device
    
    if (shouldSwitchDevice) {
        switch (_cameraDevice) {
            case QLCameraDeviceFront:
            {
                if (_captureDeviceInputBack)
                    [_captureSession removeInput:_captureDeviceInputBack];
                
                if (_captureDeviceInputFront && [_captureSession canAddInput:_captureDeviceInputFront]) {
                    [_captureSession addInput:_captureDeviceInputFront];
                    newDeviceInput = _captureDeviceInputFront;
                    newCaptureDevice = _captureDeviceFront;
                }
                break;
            }
            case QLCameraDeviceBack:
            {
                if (_captureDeviceInputFront)
                    [_captureSession removeInput:_captureDeviceInputFront];
                
                if (_captureDeviceInputBack && [_captureSession canAddInput:_captureDeviceInputBack]) {
                    [_captureSession addInput:_captureDeviceInputBack];
                    newDeviceInput = _captureDeviceInputBack;
                    newCaptureDevice = _captureDeviceBack;
                }
                break;
            }
            default:
                break;
        }
        
    } // shouldSwitchDevice
    
    // setup session input/output
    
    if (shouldSwitchMode) {
        
        // disable audio when in use for photos, otherwise enable it
        
        if (self.cameraMode == QLCameraModePhoto) {
            if (_captureDeviceInputAudio)
                [_captureSession removeInput:_captureDeviceInputAudio];
            
            if (_captureOutputAudio)
                [_captureSession removeOutput:_captureOutputAudio];
            
        } else if (!_captureDeviceAudio && !_captureDeviceInputAudio && !_captureOutputAudio &&  _flags.audioCaptureEnabled) {
            
            NSError *error2 = nil;
            _captureDeviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            _captureDeviceInputAudio = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceAudio error:&error2];
            if (error2 != nil) {
                if (error != nil) {
                    *error = error2;
                    return;
                }
            }
            
            _captureOutputAudio = [[AVCaptureAudioDataOutput alloc] init];
            [_captureOutputAudio setSampleBufferDelegate:self queue:_captureCaptureDispatchQueue];
            
        }
        
        [_captureSession removeOutput:_captureOutputVideo];
        [_captureSession removeOutput:_captureOutputPhoto];
        
        switch (_cameraMode) {
            case QLCameraModeVideo:
            {
                // audio input
                if ([_captureSession canAddInput:_captureDeviceInputAudio]) {
                    [_captureSession addInput:_captureDeviceInputAudio];
                }
                // audio output
                if ([_captureSession canAddOutput:_captureOutputAudio]) {
                    [_captureSession addOutput:_captureOutputAudio];
                }
                // vidja output
                if ([_captureSession canAddOutput:_captureOutputVideo]) {
                    [_captureSession addOutput:_captureOutputVideo];
                    newCaptureOutput = _captureOutputVideo;
                }
                break;
            }
            case QLCameraModePhoto:
            {
                // photo output
                if ([_captureSession canAddOutput:_captureOutputPhoto]) {
                    [_captureSession addOutput:_captureOutputPhoto];
                    newCaptureOutput = _captureOutputPhoto;
                }
                break;
            }
            default:
                break;
        }
        
    } // shouldSwitchMode
    
    if (!newCaptureDevice)
        newCaptureDevice = _currentDevice;
    
    if (!newCaptureOutput)
        newCaptureOutput = _currentOutput;
    
    // setup video connection
    AVCaptureConnection *videoConnection = [_captureOutputVideo connectionWithMediaType:AVMediaTypeVideo];
    
    // setup input/output
    
    NSString *sessionPreset = _captureSessionPreset;
    
    if ( newCaptureOutput && (newCaptureOutput == _captureOutputVideo) && videoConnection ) {
        
        // setup video orientation
        [self _setOrientationForConnection:videoConnection];
        
        // setup video stabilization, if available
        if ([videoConnection isVideoStabilizationSupported]) {
            if ([videoConnection respondsToSelector:@selector(setPreferredVideoStabilizationMode:)]) {
                [videoConnection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
            } else {
                [videoConnection setEnablesVideoStabilizationWhenAvailable:YES];
            }
        }
        
        // discard late frames
        [_captureOutputVideo setAlwaysDiscardsLateVideoFrames:YES];
        
        // specify video preset
        sessionPreset = _captureSessionPreset;
        
        // setup video settings
        // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range (luma=[0,255] chroma=[1,255])
        // baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct
        BOOL supportsFullRangeYUV = NO;
        BOOL supportsVideoRangeYUV = NO;
        NSArray *supportedPixelFormats = _captureOutputVideo.availableVideoCVPixelFormatTypes;
        for (NSNumber *currentPixelFormat in supportedPixelFormats) {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                supportsFullRangeYUV = YES;
            }
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
                supportsVideoRangeYUV = YES;
            }
        }
        
        NSDictionary *videoSettings = nil;
        if (supportsFullRangeYUV) {
            videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };
        } else if (supportsVideoRangeYUV) {
            videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) };
        }
        if (videoSettings) {
            [_captureOutputVideo setVideoSettings:videoSettings];
        }
        
        // setup video device configuration
        NSError *error2 = nil;
        if ([newCaptureDevice lockForConfiguration:&error2]) {
            
            // smooth autofocus for videos
            if ([newCaptureDevice isSmoothAutoFocusSupported])
                [newCaptureDevice setSmoothAutoFocusEnabled:YES];
            
            [newCaptureDevice unlockForConfiguration];
            
        } else if (error2 != nil) {
            if (error != nil) {
                *error = error2;
                return;
            }
        }
        
    } else if ( newCaptureOutput && (newCaptureOutput == _captureOutputPhoto) ) {
        
        // specify photo preset
        sessionPreset = _captureSessionPreset;
        
        // setup photo settings
        NSDictionary *photoSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
        [_captureOutputPhoto setOutputSettings:photoSettings];
        
        // setup photo device configuration
        NSError *error2 = nil;
        if ([newCaptureDevice lockForConfiguration:&error2]) {
            
            if ([newCaptureDevice isLowLightBoostSupported])
                [newCaptureDevice setAutomaticallyEnablesLowLightBoostWhenAvailable:YES];
            
            [newCaptureDevice unlockForConfiguration];
            
        } else if (error2 != nil) {
            if (error != nil) {
                *error = error2;
                return;
            }
        }
        
    }
    
    // apply presets
    if ([_captureSession canSetSessionPreset:sessionPreset])
        [_captureSession setSessionPreset:sessionPreset];
    
    if (newDeviceInput)
        _currentInput = newDeviceInput;
    
    if (newCaptureOutput)
        _currentOutput = newCaptureOutput;
    
    // ensure there is a capture device setup
    if (_currentInput) {
        AVCaptureDevice *device = [_currentInput device];
        if (device) {
            [self willChangeValueForKey:@"currentDevice"];
            [self _setCurrentDevice:device];
            [self didChangeValueForKey:@"currentDevice"];
        }
    }
    
    [_captureSession commitConfiguration];
    
//    DLog(@"capture session setup");
}

#pragma mark - preview

- (void)startPreview:(NSError *__autoreleasing *)error
{
    [self _enqueueBlockOnCaptureSessionQueue:^{
        if (!_captureSession) {
            NSError *error2 = nil;
            [self _setupCamera:&error2];
            if (error2 != nil) {
                if (error != nil) {
                    *error = error2;
                    return;
                }
            }
            [self _setupSession:&error2];
            if (error2 != nil) {
                if (error != nil) {
                    *error = error2;
                    return;
                }
            }
        }
        
        if (_previewLayer && _previewLayer.session != _captureSession) {
            _previewLayer.session = _captureSession;
            [self _setOrientationForConnection:_previewLayer.connection];
        }
        
        if (_previewLayer)
            _previewLayer.connection.enabled = YES;
        
        if (![_captureSession isRunning]) {
            if ([_delegate respondsToSelector:@selector(visionSessionWillStart:)]) {
                [_delegate visionSessionWillStart:self];
            }
            [_captureSession startRunning];
            
            [self _enqueueBlockOnMainQueue:^{
                if ([_delegate respondsToSelector:@selector(visionSessionDidStartPreview:)]) {
                    [_delegate visionSessionDidStartPreview:self];
                }
            }];
//            DLog(@"capture session running");
        }
        _flags.previewRunning = YES;
    }];
}

- (void)stopPreview
{
    [self _enqueueBlockOnCaptureSessionQueue:^{
        if (!_flags.previewRunning)
            return;
        
        if (_previewLayer)
            _previewLayer.connection.enabled = NO;
        
        if ([_captureSession isRunning])
            [_captureSession stopRunning];
        
        [self _executeBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(visionSessionDidStopPreview:)]) {
                [_delegate visionSessionDidStopPreview:self];
            }
        }];
//        DLog(@"capture session stopped");
        _flags.previewRunning = NO;
    }];
}

- (void)freezePreview
{
    if (_previewLayer)
        _previewLayer.connection.enabled = NO;
}

- (void)unfreezePreview
{
    if (_previewLayer)
        _previewLayer.connection.enabled = YES;
}

#pragma mark - queue helper methods

typedef void (^QLVisionBlock)();

- (void)_enqueueBlockOnCaptureSessionQueue:(QLVisionBlock)block
{
    dispatch_async(_captureSessionDispatchQueue, ^{
        block();
    });
}

- (void)_enqueueBlockOnCaptureVideoQueue:(QLVisionBlock)block
{
    dispatch_async(_captureCaptureDispatchQueue, ^{
        block();
    });
}

- (void)_enqueueBlockOnMainQueue:(QLVisionBlock)block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

- (void)_executeBlockOnMainQueue:(QLVisionBlock)block
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        block();
    });
}

- (void)_commitBlock:(QLVisionBlock)block
{
    [_captureSession beginConfiguration];
    block();
    [_captureSession commitConfiguration];
}

#pragma mark - App NSNotifications

- (void)_applicationWillEnterForeground:(NSNotification *)notification
{
//    DLog(@"applicationWillEnterForeground");
    [self _enqueueBlockOnCaptureSessionQueue:^{
        if (!_flags.previewRunning)
            return;
        
        [self _enqueueBlockOnMainQueue:^{
            [self startPreview:nil];
        }];
    }];
}

- (void)_applicationDidEnterBackground:(NSNotification *)notification
{
//    DLog(@"applicationDidEnterBackground");
//    if (_flags.recording)
//        [self pauseVideoCapture];
    
    if (_flags.previewRunning) {
        [self stopPreview];
        [self _enqueueBlockOnCaptureSessionQueue:^{
            _flags.previewRunning = YES;
        }];
    }
}

#pragma mark - AV NSNotifications

// capture session handlers

- (void)_sessionRuntimeErrored:(NSNotification *)notification
{
    [self _enqueueBlockOnCaptureSessionQueue:^{
        if ([notification object] == _captureSession) {
            NSError *error = [[notification userInfo] objectForKey:AVCaptureSessionErrorKey];
            if (error) {
                switch ([error code]) {
                    case AVErrorMediaServicesWereReset:
                    {
//                        DLog(@"error media services were reset");
                        [self _destroyCamera];
                        if (_flags.previewRunning)
                            [self startPreview:nil];
                        break;
                    }
                    case AVErrorDeviceIsNotAvailableInBackground:
                    {
//                        DLog(@"error media services not available in background");
                        break;
                    }
                    default:
                    {
//                        DLog(@"error media services failed, error (%@)", error);
                        [self _destroyCamera];
                        if (_flags.previewRunning)
                            [self startPreview:nil];
                        break;
                    }
                }
            }
        }
    }];
}

- (void)_sessionStarted:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        if ([notification object] != _captureSession)
            return;
        
//        DLog(@"session was started");
        
        // ensure there is a capture device setup
        if (_currentInput) {
            AVCaptureDevice *device = [_currentInput device];
            if (device) {
                [self willChangeValueForKey:@"currentDevice"];
                [self _setCurrentDevice:device];
                [self didChangeValueForKey:@"currentDevice"];
            }
        }
        
        if ([_delegate respondsToSelector:@selector(visionSessionDidStart:)]) {
            [_delegate visionSessionDidStart:self];
        }
    }];
}

- (void)_sessionStopped:(NSNotification *)notification
{
    [self _enqueueBlockOnCaptureSessionQueue:^{
        if ([notification object] != _captureSession)
            return;
        
//        DLog(@"session was stopped");
        
//        if (_flags.recording)
//            [self endVideoCapture];
        
        [self _enqueueBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(visionSessionDidStop:)]) {
                [_delegate visionSessionDidStop:self];
            }
        }];
    }];
}

- (void)_sessionWasInterrupted:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        if ([notification object] != _captureSession)
            return;
        
//        DLog(@"session was interrupted");
        
//        if (_flags.recording) {
//            [self _enqueueBlockOnMainQueue:^{
//                if ([_delegate respondsToSelector:@selector(visionSessionDidStop:)]) {
//                    [_delegate visionSessionDidStop:self];
//                }
//            }];
//        }
        
        [self _enqueueBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(visionSessionWasInterrupted:)]) {
                [_delegate visionSessionWasInterrupted:self];
            }
        }];
    }];
}

- (void)_sessionInterruptionEnded:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        
        if ([notification object] != _captureSession)
            return;
        
//        DLog(@"session interruption ended");
        
        [self _enqueueBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(visionSessionInterruptionEnded:)]) {
                [_delegate visionSessionInterruptionEnded:self];
            }
        }];
        
    }];
}
@end

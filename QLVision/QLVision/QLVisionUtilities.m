//
//  QLVisionUtilities.m
//  QLVision
//
//  Created by LIU Can on 16/3/8.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import "QLVisionUtilities.h"
#import "QLVision.h"

@implementation QLVisionUtilities
+ (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates inFrame:(CGRect)frame
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = frame.size;
    
    switch ([[QLVision sharedInstance] previewOrientation]) {
        case QLCameraOrientationPortrait:
            break;
        case QLCameraOrientationPortraitUpsideDown:
            viewCoordinates = CGPointMake(frameSize.width - viewCoordinates.x, frameSize.height - viewCoordinates.y);
            break;
        case QLCameraOrientationLandscapeLeft:
            viewCoordinates = CGPointMake(viewCoordinates.y, frameSize.width - viewCoordinates.x);
            frameSize = CGSizeMake(frameSize.height, frameSize.width);
            break;
        case QLCameraOrientationLandscapeRight:
            viewCoordinates = CGPointMake(frameSize.height - viewCoordinates.y, viewCoordinates.x);
            frameSize = CGSizeMake(frameSize.height, frameSize.width);
            break;
    }
    
    // TODO: add check for AVCaptureConnection videoMirrored
    //        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    
    AVCaptureVideoPreviewLayer *previewLayer = [[QLVision sharedInstance] previewLayer];
    
    if ( [[previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGSize apertureSize = CGSizeMake(CGRectGetHeight(frame), CGRectGetWidth(frame));
        if (!CGSizeEqualToSize(apertureSize, CGSizeZero)) {
            CGPoint point = viewCoordinates;
            CGFloat apertureRatio = apertureSize.height / apertureSize.width;
            CGFloat viewRatio = frameSize.width / frameSize.height;
            CGFloat xc = .5f;
            CGFloat yc = .5f;
            
            if ( [[previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                if (viewRatio > apertureRatio) {
                    CGFloat y2 = frameSize.height;
                    CGFloat x2 = frameSize.height * apertureRatio;
                    CGFloat x1 = frameSize.width;
                    CGFloat blackBar = (x1 - x2) / 2;
                    if (point.x >= blackBar && point.x <= blackBar + x2) {
                        xc = point.y / y2;
                        yc = 1.f - ((point.x - blackBar) / x2);
                    }
                } else {
                    CGFloat y2 = frameSize.width / apertureRatio;
                    CGFloat y1 = frameSize.height;
                    CGFloat x2 = frameSize.width;
                    CGFloat blackBar = (y1 - y2) / 2;
                    if (point.y >= blackBar && point.y <= blackBar + y2) {
                        xc = ((point.y - blackBar) / y2);
                        yc = 1.f - (point.x / x2);
                    }
                }
            } else if ([[previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                if (viewRatio > apertureRatio) {
                    CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                    xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                    yc = (frameSize.width - point.x) / frameSize.width;
                } else {
                    CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                    yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                    xc = point.y / frameSize.height;
                }
            }
            
            pointOfInterest = CGPointMake(xc, yc);
        }
    }
    
    return pointOfInterest;
}

+ (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    
    return nil;
}

+ (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
    for ( AVCaptureConnection *connection in connections ) {
        for ( AVCaptureInputPort *port in [connection inputPorts] ) {
            if ( [[port mediaType] isEqual:mediaType] ) {
                return connection;
            }
        }
    }
    
    return nil;
}

+ (CMSampleBufferRef)createOffsetSampleBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer withTimeOffset:(CMTime)timeOffset
{
    CMItemCount itemCount;
    
    OSStatus status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, NULL, &itemCount);
    if (status) {
        return NULL;
    }
    
    CMSampleTimingInfo *timingInfo = (CMSampleTimingInfo *)malloc(sizeof(CMSampleTimingInfo) * (unsigned long)itemCount);
    if (!timingInfo) {
        return NULL;
    }
    
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, timingInfo, &itemCount);
    if (status) {
        free(timingInfo);
        timingInfo = NULL;
        return NULL;
    }
    
    for (CMItemCount i = 0; i < itemCount; i++) {
        timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
        timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
    }
    
    CMSampleBufferRef offsetSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, timingInfo, &offsetSampleBuffer);
    
    if (timingInfo) {
        free(timingInfo);
        timingInfo = NULL;
    }
    
    return offsetSampleBuffer;
}

+ (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
    CGFloat angle = 0.0;
    
    switch (orientation) {
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = (CGFloat)M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = (CGFloat)-M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = (CGFloat)M_PI_2;
            break;
        case AVCaptureVideoOrientationPortrait:
        default:
            break;
    }
    
    return angle;
}

#pragma mark - memory

+ (uint64_t)availableDiskSpaceInBytes
{
    uint64_t totalFreeSpace = 0;
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error:&error];
    
    if (dictionary) {
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    }
    
    return totalFreeSpace;
}

@end

#pragma mark - NSString Extras

@implementation NSString (QLExtras)

+ (NSString *)QLformattedTimestampStringFromDate:(NSDate *)date
{
    if (!date)
        return nil;
    
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
        [dateFormatter setLocale:[NSLocale autoupdatingCurrentLocale]];
    });
    
    return [dateFormatter stringFromDate:date];
}
@end

//
//  QLMediaWriter.h
//  QLVision
//
//  Created by LIU Can on 16/3/9.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol QLMediaWriterDelegate;
@interface QLMediaWriter : NSObject
- (id)initWithOutputURL:(NSURL *)outputURL;

@property (nonatomic, weak) id<QLMediaWriterDelegate> delegate;

@property (nonatomic, readonly) NSURL *outputURL;
@property (nonatomic, readonly) NSError *error;

// configure settings before writing

@property (nonatomic, readonly, getter=isAudioReady) BOOL audioReady;
@property (nonatomic, readonly, getter=isVideoReady) BOOL videoReady;

- (BOOL)setupAudioWithSettings:(NSDictionary *)audioSettings;

- (BOOL)setupVideoWithSettings:(NSDictionary *)videoSettings withAdditional:(NSDictionary *)additional;

// write methods, time durations

@property (nonatomic, readonly) CMTime audioTimestamp;
@property (nonatomic, readonly) CMTime videoTimestamp;

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer withMediaTypeVideo:(BOOL)video;
- (void)finishWritingWithCompletionHandler:(void (^)(void))handler;

@end

@protocol QLMediaWriterDelegate <NSObject>
@optional
// authorization status provides the opportunity to prompt the user for allowing capture device access
- (void)mediaWriterDidObserveAudioAuthorizationStatusDenied:(QLMediaWriter *)mediaWriter;
- (void)mediaWriterDidObserveVideoAuthorizationStatusDenied:(QLMediaWriter *)mediaWriter;

@end
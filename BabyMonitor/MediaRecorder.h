//
//  MediaRecorder.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQRecorder.h"
#import "BMUtility.h"
#import "GCDAsyncUdpSocket.h"

@protocol MediaRecorderDelegate <NSObject>
@optional
- (void) sendMediaPacketTimeoutMaxed;
- (void) socketCloseDueToNetworkConnectionLoss;
@end


@interface MediaRecorder : NSObject <AudioRecorderDelegate>
{
    AQRecorder*					mAQRecorder;
    BOOL						playbackWasInterrupted;
    
    __weak id<MediaRecorderDelegate>  mMediaRecorderDelegate;

    
    GCDAsyncUdpSocket*         mMediaRecorderSocket;
    NSTimer*                   mMediaStreamActivityWatchTimer;
    unsigned short             mNumOfMediaPacketSendTimeoutMissed;
    dispatch_queue_t    	   mMediaRecorderQueue;
    
    uint16_t                   mReusePort;
    
    NSString*                  mPeerName;
}

//this function will serve for both "starting" and "resuming" recording
- (BMErrorCode)StartRecording;
- (BMErrorCode)StopRecording;
-(BMErrorCode) ResumeRecording;
- (BMErrorCode)PauseRecording;

-(id) init;
-(void) getLocalAddress:(struct sockaddr**)localAddress andRemoteAddress:(struct sockaddr**)remoteAddress;

-(id) initWithPortNum:(uint16_t) portNum;
- (uint16_t) getSocketPort;

-(void) startMediaStreamActivityWatchTimer;
-(void) stopMediaStreamActivityWatchTimer;
-(void) mediaStreamActivityTimerFired:(NSTimer*) timer;

- (BMErrorCode) sendRecordedMediaPacket:(void *)packet withSize:(UInt32)sizeInBytes;

void interruptionListener
(
    void *	inClientData,
    UInt32  inInterruptionState
 );

void propListener
(	
    void *                  inClientData,
    AudioSessionPropertyID	inID,
    UInt32                  inDataSize,
    const void *            inData
 );

//-(id) initWithDelegate: (id) delegate;

@property					  BOOL				           playbackWasInterrupted;
@property (nonatomic) NSTimer*                         mMediaStreamActivityWatchTimer;
@property (nonatomic, weak) id<MediaRecorderDelegate>    mMediaRecorderDelegate;
@property   (nonatomic) AQRecorder*     mAQRecorder;
@property (nonatomic)     GCDAsyncUdpSocket*         mMediaRecorderSocket;

@end

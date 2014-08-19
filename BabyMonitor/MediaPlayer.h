//
//  MediaPlayer.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQPlayer.h"
#import "BMUtility.h"
#import "PacketReceiver.h"
#import "GCDAsyncUdpSocket.h"

@class MediaPlayer;

@protocol MediaPlayerDelegate <NSObject>
@optional
- (void) receiveMediaPacketTimeoutMaxed;
@end


@interface MediaPlayer : NSObject
{
    AQPlayer*                  mAQPlayer;
    CFStringRef				   mFileName;
    
    GCDAsyncUdpSocket*         mMediaPlayerSocket;
    
    dispatch_queue_t    	   mMediaPlayerQueue;
    
    __weak id<MediaPlayerDelegate>  mMediaPlayerDelegate;

    NSTimer*                          mMediaStreamActivityWatchTimer;
    unsigned short                    mNumOfMediaPacketReceiveTimeoutMissed;
    
    bool                        mAudioMuted;
    AudioQueueParameterValue    mSavedVolume;
}

-(id) initWithPortNumber:(uint16_t) portnum;

//this function will serve for both "starting" and "resuming" recording
- (BMErrorCode)StartPlaying;
- (BMErrorCode)StopPlaying;
- (BMErrorCode)PausePlaying;
-(BMErrorCode) ResumePlaying;
-(BMErrorCode) muteAudio;

-(id) init;
-(void) getLocalAddress:(struct sockaddr**)localAddress andRemoteAddress:(struct sockaddr**)remoteAddress;

-(void) startMediaStreamActivityWatchTimer;
-(void) stopMediaStreamActivityWatchTimer;
-(void) mediaStreamActivityTimerFired:(NSTimer*) timer;

-(uint16_t) getSocketPort;

@property (nonatomic) AQPlayer* mAQPlayer;
@property (nonatomic) NSTimer*                         mMediaStreamActivityWatchTimer;
@property (nonatomic, weak) id<MediaPlayerDelegate>    mMediaPlayerDelegate;
@property (nonatomic)     GCDAsyncUdpSocket*         mMediaPlayerSocket;
@end

//
//  MediaPlayer.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "MediaPlayer.h"
#import "MediaPacket.h"
#import "PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

static const unsigned short MAX_NUM_OF_MEDIA_PACKET_RECEIVE_TIMEOUT_ACCEPTABLE = 4;


@implementation MediaPlayer

@synthesize mAQPlayer;
@synthesize mMediaStreamActivityWatchTimer;
@synthesize mMediaPlayerDelegate;
@synthesize mMediaPlayerSocket;

//-(id) initWithDelegate: (id) delegate
-(id) initWithPortNumber:(uint16_t) portnum
{
    self = [super init];
    if(self != nil)
    {
        mAQPlayer =  [[AQPlayer alloc] init];
        
        BMErrorCode error = [self setupSocket:portnum];
        
        mAudioMuted = NO;
        
        if(error != BM_ERROR_NONE)
        {
            return self;
        }
    }
    
    return self;
}

-(id) init 
{
    self = [super init];
    if(self != nil)
    {
        //DDLogInfo(@"\nMediaPlayer: Mediaplayer init...");
        mAQPlayer =  [[AQPlayer alloc] init];
    }
    
    return self;   
}

-(void) getLocalAddress:(struct sockaddr**)localAddress andRemoteAddress:(struct sockaddr**)remoteAddress
{
    *localAddress = (struct sockaddr *)[mMediaPlayerSocket.localAddress bytes];
    *remoteAddress = (struct sockaddr*) [mMediaPlayerSocket.connectedAddress bytes];
}

-(BMErrorCode) muteAudio
{
    if(BM_AS_PLAYING)
    {
        OSStatus err = 0;
        if(!mAudioMuted)
        {
            DDLogInfo(@"\nMediaPlayer: Muting audio...");
            err = AudioQueueSetParameter(mAQPlayer.mAudioQueue, kAudioQueueParam_Volume, 0.0);
            if(!err)
                mAudioMuted = YES;
        }
        else 
        {
           // DDLogInfo(@"\nMediaPlayer: UnMuting audio...");
            err = AudioQueueSetParameter(mAQPlayer.mAudioQueue, kAudioQueueParam_Volume, 1.0);
            if(!err)
                mAudioMuted = NO;
        }
        
        if(err)
        {
            DDLogInfo(@"\nMediaPlayer: Error setting speaker volume");
            [Utilities print4char_errorcode:err];
        }
            
        return BM_ERROR_NONE;
    }

    
    return BM_ERROR_FAIL;
}

-(void) startMediaStreamActivityWatchTimer
{
   // DDLogInfo(@"\nMediaPlayer: startMediaStreamActivityWatchTimer");
    if(mMediaStreamActivityWatchTimer)
        [self stopMediaStreamActivityWatchTimer];
    
    mNumOfMediaPacketReceiveTimeoutMissed = 0;
    mMediaStreamActivityWatchTimer = [NSTimer scheduledTimerWithTimeInterval:1 
                                                                      target:self 
                                                                    selector:@selector(mediaStreamActivityTimerFired:) 
                                                                    userInfo:nil 
                                                                     repeats:YES];
    
   // DDLogInfo(@"\nMediaPlayer: Started: startMediaStreamActivityWatchTimer");
}

-(void) stopMediaStreamActivityWatchTimer
{
    if(mMediaStreamActivityWatchTimer)
        [mMediaStreamActivityWatchTimer invalidate];
    
    mMediaStreamActivityWatchTimer = nil;
    
    mNumOfMediaPacketReceiveTimeoutMissed = 0;
    
  //  DDLogInfo(@"\nMediaPlayer: Stopped: startMediaStreamActivityWatchTimer");
}

-(void) mediaStreamActivityTimerFired:(NSTimer*) timer
{
    //DDLogInfo(@"\nPacketReceiver: mediaStreamActivityTimerFired");
    {
        if(mNumOfMediaPacketReceiveTimeoutMissed > 0)
        {
            mNumOfMediaPacketReceiveTimeoutMissed++;
          //  DDLogInfo(@"\nMediaPlayer: Has not yet received media packet mNumOfMediaPacketReceiveTimeoutMissed = %d", mNumOfMediaPacketReceiveTimeoutMissed);
            
            if(mNumOfMediaPacketReceiveTimeoutMissed > MAX_NUM_OF_MEDIA_PACKET_RECEIVE_TIMEOUT_ACCEPTABLE)
            {
                if(mMediaPlayerDelegate && 
                   [mMediaPlayerDelegate respondsToSelector:@selector(receiveMediaPacketTimeoutMaxed)])
                {
                    [mMediaPlayerDelegate receiveMediaPacketTimeoutMaxed];
                }
                
                [self stopMediaStreamActivityWatchTimer];
            }
        }
        else 
        {
            mNumOfMediaPacketReceiveTimeoutMissed++;
        }
        
    }
}

-(uint16_t) getSocketPort
{
    if(mMediaPlayerSocket)
        return [mMediaPlayerSocket localPort];
    else 
        return 0;
}

-(BMErrorCode) setupSocket:(uint16_t) portnum
{
    if(!mMediaPlayerQueue)
        mMediaPlayerQueue =  dispatch_queue_create("MediaPlayerQueue", NULL);
    
    if(!mMediaPlayerQueue)
    {
      //  DDLogInfo(@"\nMediaPlayer: ERROR creating MediaPlayer queue");
        return BM_ERROR_FAIL;
    }
    
    mMediaPlayerSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self 
                                                         delegateQueue:mMediaPlayerQueue];
    if(!mMediaPlayerSocket)
    {
        DDLogInfo(@"\nMediaPlayer: Error creating GCD socket");
        return BM_ERROR_FAIL;
    }
    
    NSError *error = nil;
    if (portnum < 0 || portnum > 65535)
        portnum = 0;

    if (![mMediaPlayerSocket bindToPort:portnum error:&error])
    {
        DDLogInfo(@"Error starting server (bind): %@", error);
        return BM_ERROR_FAIL;
    }
    
    DDLogInfo(@"\nMediaPlayer: started socket with portnum %d. Input port num was %d",
              [self getSocketPort],
              portnum);
    
    mAQPlayer.mPlayerQueue = mMediaPlayerQueue;
    
    mMediaPlayerSocket.delegate = self;
    
    if (![mMediaPlayerSocket beginReceiving:&error])
    {
        DDLogInfo(@"Error starting server (recv): %@", error);
        [mMediaPlayerSocket close];
        return BM_ERROR_FAIL;
    }
    
//    NSString* peerName = [PersistentStorage readPeerServiceNameFromPersistentStorage];
//    NSError* socketError = nil;
//    [mMediaPlayerSocket connectToHost:peerName onPort:[self getSocketPort] error:&socketError];
    
    return BM_ERROR_NONE;
}

-(void)dealloc
{
    DDLogInfo(@"\nMediaPlayer: deallocing self");
}

- (BMErrorCode)StartPlaying
{
    return BM_ERROR_NONE;
}

- (BMErrorCode)StopPlaying
{
       // DDLogInfo(@"\nMediaPlayer: StopRecording");
    [mAQPlayer StopPlaying];
    [mMediaPlayerSocket close];
    [self stopMediaStreamActivityWatchTimer];
    return BM_ERROR_NONE;
}

- (BMErrorCode)PausePlaying
{
    if([mAQPlayer pausePlaying] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nMediaPlayer: Error pausing AQ Player");
        return BM_ERROR_FAIL;
    }
    
    [self stopMediaStreamActivityWatchTimer];
    return BM_ERROR_NONE;
}

-(BMErrorCode) ResumePlaying
{
    if([mAQPlayer resumePlaying] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nMediaPlayer: Error resuming AQ Player");
        return BM_ERROR_FAIL;
    }
    
    [self startMediaStreamActivityWatchTimer];
    return BM_ERROR_NONE;
}

///////////////////////////////////SOCKET DELEGATE FUNCTIONS////////////////////////
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    DDLogInfo(@"\nMediaPlayer: didConnectToAddress %@", address);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error
{
    DDLogInfo(@"\nMediaPlayer: didNotConnect %@", error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    DDLogInfo(@"\nMediaPlayer: didSendDataWithTag");
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    DDLogInfo(@"\nMediaPlayer: didNotSendDataWithTag error %@", error);

}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    DDLogInfo(@"\nMediaPlayer: udpSocketDidClose error %@", error);
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    //DDLogInfo(@"\nMediaPlayer:didReceiveData");
    if(!data)
    {
   //     DDLogInfo(@"\nMediaPlayer: No data received");
        return;
    }
    
    @autoreleasepool
    {
        MediaPacket* mediaPacket =  (MediaPacket*)malloc(sizeof(MediaPacket));
        if(!mediaPacket)
        {
            return;
        }
        
        mediaPacket->mVoiceData = malloc(2048);
        if(!mediaPacket->mVoiceData)
        {
            return;
        }
        
        [data getBytes:mediaPacket->mVoiceData];
        mediaPacket->msizeInBytes = 2048;
        mediaPacket->mMediaPacketType = MEDIA_PACKET_TYPE_VOICE;
        
        mNumOfMediaPacketReceiveTimeoutMissed = 0;
        
        [self.mAQPlayer StreamDataAvailable:mediaPacket];
    }
    
    //DDLogInfo(@"\nMediaPlayer: Didreceive data END");
}

@end

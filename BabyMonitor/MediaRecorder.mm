//
//  MediaRecorder.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "MediaRecorder.h"
#import "PersistentStorage.h"
#import "DDLog.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

const int ddLogLevel = LOG_LEVEL_VERBOSE;

static const unsigned short MAX_NUM_OF_MEDIA_PACKET_SEND_TIMEOUT_ACCEPTABLE = 2;


@implementation MediaRecorder

@synthesize playbackWasInterrupted;
@synthesize mAQRecorder;
@synthesize mMediaStreamActivityWatchTimer;
@synthesize mMediaRecorderDelegate;
@synthesize mMediaRecorderSocket;

#pragma mark init

//-(id) initWithDelegate: (id) delegate
-(id) initWithPortNum:(uint16_t) portNum
{
    self = [super init];
    
    if(self != nil)
    {
        BMErrorCode error = [self setupSocket:portNum];
        if(error != BM_ERROR_NONE)
        {
            return self;
        }
        
        mAQRecorder = [[AQRecorder alloc] init];
        
        mPeerName = [PersistentStorage readPeerServiceNameFromPersistentStorage];

    }
    
    return self;
}

-(id) init 
{
    self = [super init];
    
    if(self != nil)
    {
       // DDLogInfo(@"\nMediaRecorder: MediaRecorder init...");
        mAQRecorder = [[AQRecorder alloc] init];        
     
        //save it so we don't have to read it everytime we send
        mPeerName = [PersistentStorage readPeerNameFromPersistentStorage];
    }
    
    return self;
}

-(uint16_t) getSocketPort
{
    if(mMediaRecorderSocket)
    {
        uint16_t port = [mMediaRecorderSocket localPort];
       // DDLogInfo(@"\nMediaRecorder: getSocketPort: port number is: %d", port);
        return port; // [mMediaRecorderSocket localPort];
    }
    else 
    {
        DDLogInfo(@"\nMediaRecorder:getSocketPort ERROR mMediaRecorderSocket is nil" );
        return 0;
    }
}

-(void) getLocalAddress:(struct sockaddr**)localAddress andRemoteAddress:(struct sockaddr**)remoteAddress
{
    *localAddress = (struct sockaddr *)[mMediaRecorderSocket.localAddress bytes];
    *remoteAddress = (struct sockaddr*) [mMediaRecorderSocket.connectedAddress bytes];
}

-(BMErrorCode) setupSocket:(uint16_t) portnum
{
    if(!mMediaRecorderQueue)
        mMediaRecorderQueue =  dispatch_queue_create("MediaRecorderQueue", NULL);
    
    if(!mMediaRecorderQueue)
    {
        DDLogInfo(@"\nMediaRecorder: ERROR creating MediaRecorder queue");
        return BM_ERROR_FAIL;
    }
    
    mMediaRecorderSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self 
                                                         delegateQueue:mMediaRecorderQueue];
    if(!mMediaRecorderSocket)
    {
        DDLogInfo(@"\nMediaRecorder: Error creating GCD socket");
        return BM_ERROR_FAIL;
    }
    
    NSError *error = nil;
    if (portnum < 0 || portnum > 65535)
        portnum = 0;
    
    if (![mMediaRecorderSocket bindToPort:portnum error:&error])
    {
        DDLogInfo(@"\nMediaRecorder: Error starting server (bind): %@", error);
        return BM_ERROR_FAIL;
    }
    
    DDLogInfo(@"\nMediaRecorder: started socket with portnum %d. Input port num was %d",
              [self getSocketPort],
              portnum);

    //save it so we don't have to read it everytime we send
    mPeerName = [PersistentStorage readPeerNameFromPersistentStorage];
    
//    if (![mMediaRecorderSocket beginReceiving:&error])
//    {
//        DDLogInfo(@"\nMediaRecorder: Error starting server (recv): %@", error);
//        [mMediaRecorderSocket close];
//        return BM_ERROR_FAIL;
//    }
    
    return BM_ERROR_NONE;
}

- (void)dealloc
{
  //  DDLogInfo(@"\nMediaRecorder: deallocing self");
    //[mAQRecorder release];
    //mAQRecorder = nil;
}

- (BMErrorCode) StopRecording
{
    DDLogInfo(@"\nMediaRecorder: StopRecording");
    @synchronized(self)
    {
        mAQRecorder.mIsOkToRecordAndSend = NO;
        [self stopMediaStreamActivityWatchTimer];
        [mAQRecorder StopRecord];

        [self.mMediaRecorderSocket close];
    }
    return BM_ERROR_NONE;
}

- (BMErrorCode)StartRecording
{
    if (mAQRecorder.mAQRecorderState == BM_AR_PLAYING) // If we are currently recording, stop and save the file.
	{
		[self StopRecording];
	}
	else // If we're not recording, start.
    {	
        //NSError* socketError = nil;
        //[mMediaRecorderSocket connectToHost:mPeerName onPort:[self getSocketPort] error:&socketError];
        
		// Start the recorder
        self.mAQRecorder.mRecorderDelegate = self;
        
		[mAQRecorder StartRecord];
        
        [self startMediaStreamActivityWatchTimer];
    }	

    return BM_ERROR_NONE;    
}

- (BMErrorCode) sendRecordedMediaPacket:(void *)packet withSize:(UInt32)sizeInBytes
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(!mAQRecorder.mIsOkToRecordAndSend)
    {
        DDLogInfo(@"Not ok to Record and Send Media");
        return BM_ERROR_FAIL;
    }
    
    NSData* data = [NSData dataWithBytes:packet length:sizeInBytes];
    if(!data)
    {
        DDLogInfo(@"\nMediaRecorder: ERROR Unable to create NSData from voice packet");
        return BM_ERROR_FAIL;
    }
    
   // DDLogInfo(@"\nMediaRecorder: Sending data");
    [mMediaRecorderSocket sendData:data
                            toHost:mPeerName
                              port:[self getSocketPort]
                       withTimeout:-1
                               tag:0];
    
//    [mMediaRecorderSocket sendData:data 
//                       withTimeout:-1
//                               tag:0];
//    
    //DDLogInfo(@"\nMediaRecorder: Sent data with size %lu", sizeInBytes);
    return error;
}

- (BMErrorCode)PauseRecording
{
    if([mAQRecorder pauseRecord] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nMediaRecorder: Error Pausing the AQ Recorder");
        return BM_ERROR_FAIL;
    }
    
    [self stopMediaStreamActivityWatchTimer];
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) ResumeRecording
{
    if([mAQRecorder resumeRecord] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nMediaRecorder: Error Resuming the AQ Recorder");
        return BM_ERROR_FAIL;
    }
    
    [self startMediaStreamActivityWatchTimer];
    
    return BM_ERROR_NONE;
}

-(void) startMediaStreamActivityWatchTimer
{
    if(mMediaStreamActivityWatchTimer)
        [self stopMediaStreamActivityWatchTimer];
    
    mNumOfMediaPacketSendTimeoutMissed = 0;
    mMediaStreamActivityWatchTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                                      target:self 
                                                                    selector:@selector(mediaStreamActivityTimerFired:) 
                                                                    userInfo:nil 
                                                                     repeats:YES];
    
  //  DDLogInfo(@"\nMediaRecorder: Started MediaStreamActivityWatchTimer");
}

-(void) stopMediaStreamActivityWatchTimer
{
    if(mMediaStreamActivityWatchTimer)
        [mMediaStreamActivityWatchTimer invalidate];
    
    mMediaStreamActivityWatchTimer = nil;
    
    mNumOfMediaPacketSendTimeoutMissed = 0;
    
  //  DDLogInfo(@"\nMediaRecorder: Stopped MediaStreamActivityWatchTimer");
}

-(void) mediaStreamActivityTimerFired:(NSTimer*) timer
{
    if(mNumOfMediaPacketSendTimeoutMissed > 0)
    {        
//        DDLogInfo(@"\nMediaRecorder: Has not yet Sent media packet mNumOfMediaPacketSendTimeoutMissed = %d",
//              mNumOfMediaPacketSendTimeoutMissed);
        
        if(mNumOfMediaPacketSendTimeoutMissed > MAX_NUM_OF_MEDIA_PACKET_SEND_TIMEOUT_ACCEPTABLE)
        {
            if(mMediaRecorderDelegate && 
               [mMediaRecorderDelegate respondsToSelector:@selector(sendMediaPacketTimeoutMaxed)])
            {
                [mMediaRecorderDelegate sendMediaPacketTimeoutMaxed];
            }
            
            [self stopMediaStreamActivityWatchTimer];
        }
    }
    else 
    {
        mNumOfMediaPacketSendTimeoutMissed++;
    }
}


/////////////////////////////////////DELEGATE FUNCTIONS///////////////////////

-(void) udpSocket:(GCDAsyncUdpSocket*) sock didSendDataWithTag:(long)tag
{
    //DDLogInfo(@"\nMediaRecorder: didSendDataWithTag");
    mNumOfMediaPacketSendTimeoutMissed = 0;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    DDLogInfo(@"\nMediaRecorder: didNotSendDataWithTag error %@", error);
    mNumOfMediaPacketSendTimeoutMissed++;
	// You could add checks here
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    DDLogInfo(@"\nMediaRecorder: didConnectToAddress %@", address);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error
{
   // DDLogInfo(@"\nMediaRecorder: didNotConnect %@", error);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
   // DDLogInfo(@"\nMediaRecorder: udpSocketDidClose error %@ %d", error, error.code);
    
    if(mAQRecorder.mAQRecorderState == BM_AR_PLAYING && error && error.code == ENETUNREACH)
    {
        if(mMediaRecorderDelegate &&
           [mMediaRecorderDelegate respondsToSelector:@selector(socketCloseDueToNetworkConnectionLoss)])
        {
            [self stopMediaStreamActivityWatchTimer];
            [mMediaRecorderDelegate socketCloseDueToNetworkConnectionLoss];
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    DDLogInfo(@"\nMediaRecorder: didReceiveData");
}

@end
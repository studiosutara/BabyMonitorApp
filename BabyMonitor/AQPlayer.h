//
//  AQPlayer.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 12/15/11.
//  Copyright (c) 2011 Studio Sutara LLC. All rights reserved.
//

/*#include <stdio.h>
 #include <string.h>
 #include <netdb.h>
 #include <netinet/in.h>
 #include <unistd.h>*/
#include <pthread.h>
#include "BMUtility.h"
#include <AudioToolbox/AudioToolbox.h>
#include "MediaPacket.h"
#include "CAStreamBasicDescription.h"
#include "CAXException.h"


#define PRINTERROR(LABEL)	printf("%s err %4.4s %d\n", LABEL, &err, err)
#define kBufferDurationSeconds .5

typedef enum
{
    BM_AS_INITIALIZED = 0,
    BM_AS_STARTING_FILE_THREAD, //1
    BM_AS_WAITING_FOR_DATA,  //2
    BM_AS_WAITING_FOR_QUEUE_TO_START, //3
    BM_AS_PLAYING,  //4
    BM_AS_BUFFERING,  //5
    BM_AS_WAITING_FOR_QUEUE_TO_STOP,  //6
    BM_AS_STOPPED,  //7
    BM_AS_WAITING_FOR_QUEUE_TO_PAUSE, //8
    BM_AS_PAUSED  //9
} AudioStreamerState;

typedef enum
{
    BM_AS_NO_STOP = 0,
    BM_AS_STOPPING_EOF,
    BM_AS_STOPPING_USER_ACTION,
    BM_AS_STOPPING_ERROR,
    BM_AS_STOPPING_TEMPORARILY
} AudioStreamerStopReason;

//const int port = 51515;			// the port we will use

const unsigned int kNumAQBufs = 3;			// number of audio queue buffers we allocate
const size_t kAQBufSize = 1024*2; 		// number of bytes in each audio queue buffer
const size_t kAQMaxPacketDescs = 512;		// number of packet descriptions in our array

/*static void AQBufferCallback
(
 void*	inClientData, 
 AudioQueueRef inAQ,
 AudioQueueBufferRef	inBuffer
 );

static void AQInterruptionListenerCallback
(
 void *                  inClientData,
 UInt32                  inInterruptionState
 );


static void AudioQueuePropertyListenerCallback
(
 void* inUserData, 
 AudioQueueRef inAQ,     
 AudioQueuePropertyID inID
 );

static void AudioQueueBufferAvailableCallback
(
 void* inClientData, 
 AudioQueueRef inAQ, 
 AudioQueueBufferRef inBuffer
 );*/


@interface AQPlayer : NSObject
{
    AudioQueueRef mAudioQueue;								// the audio queue
	AudioQueueBufferRef mAudioQueueBuffer[kNumAQBufs];		// audio queue buffers
	
    CAStreamBasicDescription	mRecordFormat;
	
	unsigned int mFillBufferIndex;	// the index of the audioQueueBuffer that is being filled
	size_t mBytesFilled;				// how many bytes have been filled
    
	bool mInuse[kNumAQBufs];			// flags to indicate that a buffer is still in use
    
    //The AQPlayer can start playing only if this bool is true
    //Even though we are receiving data, if the SM think we should not be playing, 
    //we are not allowed to play
    bool mIsOkToStartPlaying;        
    
    NSInteger mBuffersUsed;
    
    AudioStreamerState mAQPlayerState;
	AudioStreamerStopReason mStopReason;
	BMErrorCode mErrorCode;
    
    //pthread_mutex_t mQueueBuffersMutex;			// a mutex to protect the inuse flags
	//pthread_cond_t mQueueBufferReadyCondition;	// a condition varable for handling the inuse flags
    NSCondition*  mQueueBufferReadyCondition;
    
    dispatch_queue_t mPlayerQueue;
    
}

-(void) setMIsOkToStartPlaying:(bool) newVal;
-(bool) mIsOkToStartPlaying;

-(void) CalculateBytesForTime:(Float64)inSeconds bufferSz:(UInt32*) outBufferSize;
-(void) SetupQueue;
-(void)handlePropertyListenerCallbackWithQueue:(AudioQueueRef) inAQ property:(AudioQueuePropertyID)inID;
-(void) failWithErrorCode:(BMErrorCode) anErrorCode;
-(void) printState;
-(void) EnqueueBuffer;
-(void) printinuse;
-(void) SetupAudioFormat:(UInt32) inFormatID;
-(void) StreamDataAvailable:(MediaPacket*) packet;
-(void) HandleAQBufferCallBack:(AudioQueueRef)inAQ buffer:(AudioQueueBufferRef)inBuffer;
-(void) StopPlaying;
-(BMErrorCode) pausePlaying;
-(BMErrorCode) resumePlaying;


@property (nonatomic) AudioStreamerState mAQPlayerState;
@property (nonatomic, assign) bool       mIsOkToStartPlaying;
@property (nonatomic) AudioQueueRef      mAudioQueue;
@property (nonatomic) dispatch_queue_t   mPlayerQueue;
@end

//#endif

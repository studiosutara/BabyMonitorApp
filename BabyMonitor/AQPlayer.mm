//
//  AQPlayer.mm
//  BabyMonitor
//
//  Created by Shilpa Modi on 12/15/11.
//  Copyright (c) 2011 Studio Sutara LLC. All rights reserved.
//

#include <iostream>
#include "AQPlayer.h"
#import "Utilities.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

void AQBufferCallback
(	
 void*					inClientData, 
 AudioQueueRef			inAQ, 
 AudioQueueBufferRef		inBuffer
 )
{
    //printf("********AQPlayer::AQBufferCallback\n");

    AQPlayer* player = (__bridge AQPlayer*) inClientData;
    if(!player)
        return;
    
    [player HandleAQBufferCallBack:inAQ buffer:inBuffer];
}

@implementation AQPlayer

@synthesize mAQPlayerState;
@synthesize mAudioQueue;
@synthesize mPlayerQueue;

//@synthesize mIsOkToStartPlaying;

-(id) init
{
    //DDLogInfo(@"\nAQPlayer: init...");
    //pthread_mutex_init(&mQueueBuffersMutex, NULL);
	//pthread_cond_init(&mQueueBufferReadyCondition, NULL);
    mQueueBufferReadyCondition = [[NSCondition alloc] init];
    
    [self SetupQueue];
    
    mBytesFilled = 0;
    mFillBufferIndex = 0;
    mErrorCode = BM_ERROR_NONE;
    mBuffersUsed = 0;
    
    for(int i=0; i<= kNumAQBufs; i++)
        mInuse[i] = 0;
    
    mPlayerQueue = nil;
        
     return self;
}

-(void) setMIsOkToStartPlaying:(bool) newVal
{
    mIsOkToStartPlaying  = newVal;
}

-(bool) mIsOkToStartPlaying
{
    return mIsOkToStartPlaying;
}

-(void) SetupQueue
{
    OSStatus error = 0;
    self.mAQPlayerState = BM_AS_INITIALIZED;
    
    //pthread_mutex_init(&mQueueBuffersMutex, NULL);
    //pthread_cond_init(&mQueueBufferReadyCondition, NULL);
    
    [self SetupAudioFormat:kAudioFormatLinearPCM];
    
    error = AudioQueueNewOutput(  &mRecordFormat, 
                        AQBufferCallback, 
                        (__bridge void*)self, 
                        NULL, 
                        NULL, 
                        0, 
                        &mAudioQueue);
    if(error)
    {
        DDLogInfo(@"\nAQPlayer: AudioQueueNewOutput error");
    }
    
    UInt32 bufferSize = kAQBufSize;
    //CalculateBytesForTime(kBufferDurationSeconds, &bufferSize);
    
    // allocate audio queue buffers
    for (unsigned int i = 0; i < kNumAQBufs; ++i)
    {
        error = AudioQueueAllocateBuffer(mAudioQueue, bufferSize, &mAudioQueueBuffer[i]); //kAQBufSize, &mAudioQueueBuffer[i]);
        if (error)
        {
            printf("AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED");
            return;
        }
    }
    
    // start the queue if it has not been started already
    // listen to the "isRunning" property
    error = AudioQueueAddPropertyListener(mAudioQueue, kAudioQueueProperty_IsRunning, AudioQueuePropertyListenerCallback, (__bridge void*)self);
    if (error)
    {
        [self failWithErrorCode:BM_AS_AUDIO_QUEUE_ADD_LISTENER_FAILED];
        return;
    }
}

-(void) failWithErrorCode:(BMErrorCode) anErrorCode
{
    if (mErrorCode != BM_ERROR_NONE)
    {
        // Only set the error once.
        return;
    }
    
    mErrorCode = anErrorCode;
    
  //  DDLogInfo(@"AQPlayer: Error %d", mErrorCode);
}

-(void) printState
{
    UInt32 queueState;
    UInt32 propertySize = sizeof(queueState);
    AudioQueueGetProperty(mAudioQueue, kAudioQueueProperty_IsRunning, &queueState,
                          &propertySize);
    
//    DDLogInfo(@"\nAudioQueuePlayer: IsRUnningProperty=%lu", queueState);
    
    switch ( self.mAQPlayerState) 
    {
        case BM_AS_BUFFERING:
            printf("\nAQPlayer state is BM_AS_BUFFERING");
            break;
            
        case BM_AS_PAUSED:
            printf("\nAQPlayer state is BM_AS_PAUSED");
            break;
            
        case BM_AS_INITIALIZED:
            printf("\nAQPlayer state is BM_AS_INITIALIZED");
            break;
            
        case BM_AS_PLAYING:
            printf("\nAQPlayer state is BM_AS_PLAYING");
            break;
            
        case BM_AS_STARTING_FILE_THREAD:
            printf("\nAQPlayer state is BM_AS_STARTING_FILE_THREAD");
            break;
            
        case BM_AS_STOPPED:
            printf("\nAQPlayer state is BM_AS_STOPPED");
            break;
            
        case BM_AS_WAITING_FOR_QUEUE_TO_STOP:
            printf("\nAQPlayer state is BM_AS_WAITING_FOR_QUEUE_TO_STOP");
            break;
            
        case BM_AS_WAITING_FOR_DATA:
            printf("\nAQPlayer state is BM_AS_WAITING_FOR_DATA");
            break;
            
        case BM_AS_WAITING_FOR_QUEUE_TO_START:
            printf("\nAQPlayer state is BM_AS_WAITING_FOR_QUEUE_TO_START");
            break;
            
        default:
            break;
    }
}

-(void) SetupAudioFormat:(UInt32) inFormatID
{
    //printf("\nAQPlayer::SetupAudioFormat\n");
	memset(&mRecordFormat, 0, sizeof(mRecordFormat));
    
    // Describe format
    mRecordFormat.mSampleRate			= 44100.00;
    mRecordFormat.mFormatID			    = kAudioFormatLinearPCM;
    mRecordFormat.mFormatFlags		    = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    mRecordFormat.mFramesPerPacket	    = 1;
    mRecordFormat.mChannelsPerFrame	    = 1;
    mRecordFormat.mBitsPerChannel		=  16;
    mRecordFormat.mBytesPerPacket		= 2;
    mRecordFormat.mBytesPerFrame		= 2;
    
   /*  printf("\nmRecordFormat.mSampleRate=%f", mRecordFormat.mSampleRate);
     printf("\nmRecordFormat.mFormatID = %lu", mRecordFormat.mFormatID);
     printf("\nmRecordFormat.mFormatFlags = %lu", mRecordFormat.mFormatFlags);
     printf("\nmRecordFormat.frameperpacket = %lu", mRecordFormat.mFramesPerPacket);
     printf("\nmRecordFormat.mChannelsPerFrame=%lu", mRecordFormat.mChannelsPerFrame);
     printf("\nmRecordFormat.mBitsPerChannel=%lu", mRecordFormat.mBitsPerChannel);
     printf("\nmRecordFormat.mBytesPerPacket = %lu", mRecordFormat.mBytesPerPacket);
     printf("\nmRecordFormat.mBytesPerFrame=%lu", mRecordFormat.mBytesPerFrame);*/
}

-(void) StreamDataAvailable:(MediaPacket*) packet
{
   // DDLogInfo(@"\nAQplayer: StreamDataAvailable, mfillbifIndex = %d mBuffersUsed= %d numBytes = %lu",
     //         mFillBufferIndex, mBuffersUsed, packet->msizeInBytes);
    
    if(!packet || !packet->mVoiceData || mAQPlayerState == BM_AS_WAITING_FOR_QUEUE_TO_STOP)
    {
        return;
    }
    
    if(mBuffersUsed == kNumAQBufs)
    {
        DDLogInfo(@"\nAQPlayer: No free buffers, dropping this packet");
        return;
    }
    
    void* inInputData = packet->mVoiceData;

    if(self.mAQPlayerState == BM_AS_INITIALIZED)
        self.mAQPlayerState = BM_AS_WAITING_FOR_DATA;
        
     // copy data to the audio queue buffer
     AudioQueueBufferRef fillBuf = mAudioQueueBuffer[mFillBufferIndex];
     memcpy((char*)fillBuf->mAudioData, (const char*)(inInputData), kAQBufSize);
            
    [self EnqueueBuffer];     

    free(packet->mVoiceData);
    packet->mVoiceData = nil;
    
    free(packet);
    packet = nil;      
}

-(void) EnqueueBuffer
{
    //DDLogInfo(@"\nAQPlayer: Enqueuebuffer: mFillBufferIndex = %d, mBuffersUsed = %d", mFillBufferIndex, mBuffersUsed );

	@synchronized(self)
	{
		mInuse[mFillBufferIndex] = true;		// set in use flag
		mBuffersUsed++;
     
		// enqueue buffer
		AudioQueueBufferRef fillBuf = mAudioQueueBuffer[mFillBufferIndex];
		fillBuf->mAudioDataByteSize = kAQBufSize; //mBytesFilled;
		
		OSStatus err = AudioQueueEnqueueBuffer(mAudioQueue, fillBuf, 0, NULL);
				
		if (err)
		{
			[self failWithErrorCode:BM_AS_AUDIO_QUEUE_ENQUEUE_FAILED];
            [Utilities print4char_errorcode:err];
			return;
		}
        
		if (mAQPlayerState == BM_AS_WAITING_FOR_DATA)
		{
            self.mAQPlayerState = BM_AS_WAITING_FOR_QUEUE_TO_START;
            
            err = AudioQueueStart(mAudioQueue, NULL);
            if (err)
            {
                DDLogInfo(@"\nAQPlayer: AudioQueueStart failed");
                if( BM_ERROR_NONE != [self doError])
                {
                    [self failWithErrorCode:BM_AS_AUDIO_QUEUE_START_FAILED];
                    [Utilities print4char_errorcode:err];
                    return;
                }
            }
        }
    }
        
    // go to next buffer
    if(++mFillBufferIndex >= kNumAQBufs) 
        mFillBufferIndex = 0;

    mBytesFilled = 0;		// reset bytes filled
	    
    //DDLogInfo(@"\nAQPlayer: Enqueuebuffer: mFillBufferIndex = %d, mBuffersUsed = %d", mFillBufferIndex, mBuffersUsed );
	// wait until next buffer is not in use
	//pthread_mutex_lock(&mQueueBuffersMutex);
    [mQueueBufferReadyCondition lock];
    
	while (mInuse[mFillBufferIndex])
	{
        [mQueueBufferReadyCondition wait];
		//pthread_cond_wait(&mQueueBufferReadyCondition, &mQueueBuffersMutex);
	}
    
    [mQueueBufferReadyCondition unlock];
	//pthread_mutex_unlock(&mQueueBuffersMutex);
    
}

-(BMErrorCode) doError
{
    DDLogInfo(@"\nAQPlayer: Do Error");
    UInt32 sessionCategory = 0;
    
    sessionCategory = kAudioSessionCategory_RecordAudio;
    
    OSStatus error = AudioSessionSetProperty (
                                              kAudioSessionProperty_AudioCategory,
                                              sizeof (sessionCategory),
                                              &sessionCategory
                                              );
    if(error)
    {
        DDLogInfo(@"\nAQPlayer: Error AudioSessionSetProperty kAudioSessionCategory_RecordAudio kAudioSessionProperty_AudioCategory: ");
        [Utilities print4char_errorcode:error];
    }
    else
    {
        sessionCategory = kAudioSessionCategory_PlayAndRecord;
        
        error = AudioSessionSetProperty (
                                         kAudioSessionProperty_AudioCategory,
                                         sizeof (sessionCategory),
                                         &sessionCategory
                                         );
        if(error)
        {
            DDLogInfo(@"\nAQPlayer: Error AudioSessionSetProperty kAudioSessionCategory_PlayAndRecord kAudioSessionProperty_AudioCategory: ");
            [Utilities print4char_errorcode:error];
        }
//        else
//            DDLogInfo(@"\nAQPlayer: category set to kAudioSessionCategory_PlayAndRecord");

        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
        error = AudioSessionSetProperty (
                                         kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                         sizeof (audioRouteOverride),                                      // 3
                                         &audioRouteOverride                                               // 4
                                         );
        if(error)
        {
            DDLogInfo(@"\nAQPlayer: AudioSessionSetProperty kAudioSessionProperty_OverrideAudioRoute error");
        }
        
        OSStatus err = AudioQueueStart(mAudioQueue, NULL);
        if(err)
        {
            DDLogInfo(@"\nAQPlayer AudioQueueStart error=%ld\n", err);
            [Utilities print4char_errorcode:err];
            return BM_ERROR_FAIL;
        }
        else
        {
           // DDLogInfo(@"\nAQPlayer: AQRecorder started");
        }
    }
    
    return BM_ERROR_NONE;
}

-(void) HandleAQBufferCallBack:(AudioQueueRef)inAQ buffer:(AudioQueueBufferRef)inBuffer
{
    unsigned int bufIndex = -1;
	for (unsigned int i = 0; i < kNumAQBufs; ++i)
	{
		if (inBuffer == mAudioQueueBuffer[i])
		{
			bufIndex = i;
			break;
		}
	}
	
	if (bufIndex == -1)
	{
        DDLogInfo(@"\nAQPlayer Error: Buffer index = -1");
		[self failWithErrorCode:BM_AS_AUDIO_QUEUE_BUFFER_MISMATCH];
		//pthread_mutex_lock(&mQueueBuffersMutex);
        [mQueueBufferReadyCondition lock];
        
		//pthread_cond_signal(&mQueueBufferReadyCondition);
        [mQueueBufferReadyCondition signal];
        
		//pthread_mutex_unlock(&mQueueBuffersMutex);
        [mQueueBufferReadyCondition unlock];
		return;
	}
	
    //DDLogInfo(@"\nAQPlayer: HandleAQBufferCallBack Before LOCK freeing buffer %d. Number of buffers used = %d", bufIndex,mBuffersUsed);

	// signal waiting thread that the buffer is free.
    
	//pthread_mutex_lock(&mQueueBuffersMutex);
    [mQueueBufferReadyCondition lock];
    
   // @synchronized(self)
    {
        mInuse[bufIndex] = false;
        mBuffersUsed--;
    }
    
    if(mBuffersUsed == 0)
    {
        //DDLogInfo(@"\nAQPlayer: feedSilenceToQueue filbufindex = %d, mbuffersUSed = %d", mFillBufferIndex,mBuffersUsed);

        [self feedSilenceToQueue];
    }
    
	
	//pthread_cond_signal(&mQueueBufferReadyCondition);
    [mQueueBufferReadyCondition signal];
    
	//pthread_mutex_unlock(&mQueueBuffersMutex);
    [mQueueBufferReadyCondition unlock];
    
}

-(void) feedSilenceToQueue
{
    if(!mPlayerQueue)
        return;
    
    dispatch_async(mPlayerQueue, ^{
        
        @autoreleasepool
        {
            @synchronized(self)
            {
                AudioQueueBufferRef fillBuf = mAudioQueueBuffer[mFillBufferIndex];
                memset((char*)fillBuf->mAudioData, 0, kAQBufSize);
                
                [self EnqueueBuffer];
            }
        }
    });
    
}

-(BMErrorCode) pausePlaying
{
    if(self.mAQPlayerState != BM_AS_PLAYING)
    {
      //  DDLogInfo(@"\nAQPlayer: cannot pausePlaying, in state %d", self.mAQPlayerState);
        return BM_ERROR_FAIL;
    }
    
    @synchronized(self)
    {
        OSStatus err = AudioQueuePause(mAudioQueue);
        if(err)
        {
            DDLogInfo(@"\nAQPlayer: Playing paused failed");
            [Utilities print4char_errorcode:err];
            return BM_ERROR_FAIL;
        }
        
        self.mAQPlayerState = BM_AS_PAUSED;
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) resumePlaying
{
    if(self.mAQPlayerState != BM_AS_PAUSED)
    {
        DDLogInfo(@"\nAQPlayer: Cannot resume, not paused");
        return BM_ERROR_FAIL;
    }
    
    OSStatus err = AudioQueueStart(mAudioQueue, nil);
    if (err)
    {
        [self failWithErrorCode:BM_AS_AUDIO_QUEUE_START_FAILED];
        return BM_ERROR_FAIL;
    }
    else 
    {
        self.mAQPlayerState = BM_AS_PLAYING;
    }
    
    return BM_ERROR_NONE;
}

-(void) StopPlaying
{
    if(mAQPlayerState != BM_AS_PAUSED && mAQPlayerState != BM_AS_PLAYING)
    {
        DDLogInfo(@"\nAQPlayer: StopPlaying error: player is not in paused or playing state");
        return;
    }
    
    // enqueue last buffer
    //[self EnqueueBuffer];
    
    //printf("flushing\n");
    OSStatus err = AudioQueueFlush(mAudioQueue);
    if (err) 
    { 
        printf("\nAQPlayer: AudioQueueFlush failed"); 
        return; 
    }	
    
    self.mAQPlayerState = BM_AS_WAITING_FOR_QUEUE_TO_STOP;
    
    err = AudioQueueStop(mAudioQueue, false);
    if (err) 
    { 
        printf("AQPlayer: AudioQueueStop failed"); 
        return; 
    }
    
   // mPlayerQueue = nil;
}

-(void) dealloc
{
    
  //  DDLogInfo(@"\nAQPlayer: deallocing called");
    
	AudioQueueDispose(mAudioQueue, TRUE);
}

-(void) CalculateBytesForTime:(Float64)inSeconds bufferSz:(UInt32*) outBufferSize
{
    UInt32 inMaxPacketSize = 2;
    
	// we only use time here as a guideline
	// we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it
	static const int maxBufferSize = 0x10000; // limit size to 64K
	static const int minBufferSize = 0x4000; // limit size to 16K
	
	if (mRecordFormat.mFramesPerPacket) 
    {
		Float64 numPacketsForTime = mRecordFormat.mSampleRate / mRecordFormat.mFramesPerPacket * inSeconds;
		*outBufferSize = numPacketsForTime * inMaxPacketSize;
	} 
    else 
    {
		// if frames per packet is zero, then the codec has no predictable packet == time
		// so we can't tailor this (we don't know how many Packets represent a time period
		// we'll just return a default buffer size
		*outBufferSize = maxBufferSize > inMaxPacketSize ? maxBufferSize : inMaxPacketSize;
	}
	
	// we're going to limit our size to our default
	if (*outBufferSize > maxBufferSize && *outBufferSize > inMaxPacketSize)
		*outBufferSize = maxBufferSize;
	else 
    {
		// also make sure we're not too small - we don't want to go the disk for too small chunks
		if (*outBufferSize < minBufferSize)
			*outBufferSize = minBufferSize;
	}
}

void AudioQueuePropertyListenerCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    AQPlayer* player = (__bridge AQPlayer*) inUserData;
    
    if(player)
    {
       // NSLog(@"\nAQplayer: AudioQueuePropertyListenerCallback in state %d", player.mAQPlayerState);

        [player handlePropertyListenerCallbackWithQueue:inAQ property:inID];
    }
    
}

-(void)handlePropertyListenerCallbackWithQueue:(AudioQueueRef) inAQ property:(AudioQueuePropertyID)inID
{
   // DDLogInfo(@"\nAQPlayer: handlePropertyListenerCallback in state %d", mAQPlayerState);
    
    @synchronized(self)
    {
        @autoreleasepool
        {
        
            if(inID == kAudioQueueProperty_IsRunning)
            {
                if(self.mAQPlayerState == BM_AS_WAITING_FOR_QUEUE_TO_START)
                {
                   // DDLogInfo(@"\n\nAQPlayer:AudioQueue is  STARTED\n");
                    self.mAQPlayerState = BM_AS_PLAYING;
                }
                else if(self.mAQPlayerState == BM_AS_WAITING_FOR_QUEUE_TO_STOP) 
                {
                    DDLogInfo(@"\n\nAQPlayer:AudioQueue is  STOPPED\n");
                    self.mAQPlayerState = BM_AS_STOPPED;
                }
                else if(self.mAQPlayerState == BM_AS_WAITING_FOR_QUEUE_TO_PAUSE)
                {
                    DDLogInfo(@"\n\nAQPlayer:AudioQueue is  PAUSED\n");
                    self.mAQPlayerState = BM_AS_PAUSED;
                }
            }
            else 
            {
               // DDLogInfo(@"\n\nAudioQueuePropertyListenerProc ID = %lu\n", inID);
            }
        }
    }
    
    return;
}

-(void) printinuse
{
    DDLogInfo(@"\n");
    for(int i=0; i<kNumAQBufs; i++)
        DDLogInfo(@"%d", mInuse[i]);
    
}


@end

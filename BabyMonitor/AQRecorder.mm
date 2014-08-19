/*
 
    File: AQRecorder.mm
Abstract: n/a
 Version: 2.4

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2009 Apple Inc. All Rights Reserved.

 
*/

#include "AQRecorder.h"
#include "Utilities.h"
#import "DDLog.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation AQRecorder

@synthesize mAQRecorderState;
@synthesize mRecorderDelegate;
@synthesize mQueue;


// ____________________________________________________________________________________
// Determine the size, in bytes, of a buffer necessary to represent the supplied number
// of seconds of audio data.
-(int)	ComputeRecordBufferSizeForFormat:(const AudioStreamBasicDescription *)format time:(float) seconds
{
	int packets, frames, bytes = 0;
	try {
		frames = (int)ceil(seconds * format->mSampleRate);

		if (format->mBytesPerFrame > 0)
        {
			bytes = frames * format->mBytesPerFrame;
        }
		else 
        {
			UInt32 maxPacketSize;
			if (format->mBytesPerPacket > 0)
				maxPacketSize = format->mBytesPerPacket;	// constant packet size
			else {
				UInt32 propertySize = sizeof(maxPacketSize);
				XThrowIfError(AudioQueueGetProperty(mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
												 &propertySize), "couldn't get queue's maximum output packet size");
			}
			if (format->mFramesPerPacket > 0)
				packets = frames / format->mFramesPerPacket;
			else
				packets = frames;	// worst-case scenario: 1 frame in a packet
			if (packets == 0)		// sanity check
				packets = 1;
			bytes = packets * maxPacketSize;
        }
	}
    
    catch (CAXException e)
    {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		return 0;
	}
    
	return bytes;
}

////////////////////BEGIN TEST CODE////////////////////

static void printchar_errorcode(int code) 
{
//    int c1 = (code >> 24) & 0xFF;
//    int c2 = (code >> 16) & 0xFF; 
//    int c3 = (code >> 8) & 0xFF;
//    int c4 = code & 0xFF; 
//    
    char str[16];
    
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(code);
    
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) 
    {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } 
    else
        // no, format it as an integer
        sprintf(str, "%d", (int)code);

    NSLog(@"\nError: %s", str);
    
    //printf("code = %c%c%c%c", c1, c2, c3, c4);
}
/////////////////////END TEST CODE////////////////////

-(void) setMIsOkToRecordAndSend:(bool) newVal
{
    //DDLogInfo(@"\nAQRecorder: Setting the bool setMIsOkToRecordAndSend newval = %d", newVal);
    mIsOkToRecordAndSend  = newVal;
}

-(bool) mIsOkToRecordAndSend
{
    return mIsOkToRecordAndSend;
}

-(void) printState
{
    UInt32 queueState;
    UInt32 propertySize = sizeof(queueState);
    AudioQueueGetProperty(mQueue, kAudioQueueProperty_IsRunning, &queueState,
                          &propertySize);
    
    DDLogInfo(@"\nAudioQueueRecorder: IsRUnningProperty=%lu", queueState);
    
    switch(self.mAQRecorderState) 
    {
        case BM_AR_BUFFERING:
            printf("\nAQRecorder state is BM_AR_BUFFERING");
            break;
            
        case BM_AR_PAUSED:
            printf("\nAQRecorder state is BM_AR_PAUSED");
            break;
            
        case BM_AR_INITIALIZED:
            printf("\nAQRecorder state is BM_AR_INITIALIZED");
            break;
            
        case BM_AR_PLAYING:
            printf("\nAQRecorder state is BM_AR_PLAYING");
            break;
            
        case BM_AR_STOPPED:
            printf("\nAQRecorder state is BM_AR_STOPPED");
            break;
            
        case BM_AR_WAITING_FOR_QUEUE_TO_START:
            printf("\nAQRecorder state is BM_AR_WAITING_FOR_QUEUE_TO_START");
            break;
 
        default:
            break;
    }
}

// ____________________________________________________________________________________
// AudioQueue callback function, called when an input buffers has been filled.
void MyInputBufferHandler
(	
    void *								inUserData,
	AudioQueueRef						inAQ,
	AudioQueueBufferRef					inBuffer,
	const AudioTimeStamp *				inStartTime,
	UInt32								inNumPackets,
	const AudioStreamPacketDescription*	inPacketDesc
)
{
	AQRecorder *aqr = (__bridge AQRecorder *)inUserData;
    
   // DDLogInfo(@"\nAQRecorder: MyInputBufferHandler");
    [aqr HandleInputBufferFilledCallbackWithData:inUserData 
                                      audioQueue:inAQ 
                                          buffer:inBuffer 
                                      numPackets:inNumPackets];
};

-(void) HandleInputBufferFilledCallbackWithData:(void *)inUserData
                                     audioQueue:(AudioQueueRef)inAQ
                                         buffer:(AudioQueueBufferRef)inBuffer
                                     numPackets:(UInt32)inNumPackets
{
//    if(!self.mIsOkToRecordAndSend)
//    {
//        DDLogInfo(@"\nAQRecorder: Recorded packet available, but SM not ready to send");
//        return;
//    }
    
    @autoreleasepool
    {
       if (inNumPackets > 0)
        {
            if(mRecorderDelegate &&
              [mRecorderDelegate respondsToSelector:@selector(sendRecordedMediaPacket:withSize:)])
            {
                if([mRecorderDelegate sendRecordedMediaPacket:inBuffer->mAudioData 
                                                     withSize:inBuffer->mAudioDataByteSize] != BM_ERROR_NONE)
                {
                    DDLogInfo(@"\nAQRecorder: Error sending the media packet");
                    return;
                }
            }
        }
    }
    
    // if we're not stopping, re-enqueue the buffer so that it gets filled again
    if (self.mAQRecorderState != BM_AR_STOPPED)
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

-(id) init
{    

    //DDLogInfo(@"\nAQRecorder: init...");
    self.mAQRecorderState = BM_AR_INITIALIZED;
    
    //pthread_mutex_init(&mMutex, NULL);

    return self;
}


-(void) dealloc
{
    //DDLogInfo(@"\nAQRecorder: deallocing self");
	AudioQueueDispose(mQueue, TRUE);
}

-(void) printFormat
{
    /*printf("\nmRecordFormat.mSampleRate=%f", mRecordFormat.mSampleRate);
    printf("\nmRecordFormat.mFormatID = %lu", mRecordFormat.mFormatID);
    printf("\nmRecordFormat.mFormatFlags = %lu", mRecordFormat.mFormatFlags);
    printf("\nmRecordFormat.frameperpacket = %lu", mRecordFormat.mFramesPerPacket);
    printf("\nmRecordFormat.mChannelsPerFrame=%lu", mRecordFormat.mChannelsPerFrame);
    printf("\nmRecordFormat.mBitsPerChannel=%lu", mRecordFormat.mBitsPerChannel);
    printf("\nmRecordFormat.mBytesPerPacket = %lu", mRecordFormat.mBytesPerPacket);
    printf("\nmRecordFormat.mBytesPerFrame=%lu", mRecordFormat.mBytesPerFrame);*/
}

-(void)	SetupAudioFormat:(UInt32) inFormatID
{
    DDLogInfo(@"\nAQRecorder: SetupAudioFormat");
	memset(&mRecordFormat, 0, sizeof(mRecordFormat));

	UInt32 size = sizeof(mRecordFormat.mSampleRate);
	XThrowIfError(AudioSessionGetProperty(	kAudioSessionProperty_CurrentHardwareSampleRate,
										&size, 
										&mRecordFormat.mSampleRate), "couldn't get hardware sample rate");

    mRecordFormat.mFormatID = inFormatID;
   
    mRecordFormat.mChannelsPerFrame = 1;
			
	if (inFormatID == kAudioFormatLinearPCM)
	{
		// if we want pcm, default to signed 16-bit little-endian
		mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		mRecordFormat.mBitsPerChannel = 16;
		mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame = (mRecordFormat.mBitsPerChannel / 8) * mRecordFormat.mChannelsPerFrame;
        mRecordFormat.mFramesPerPacket = 1;
	}
    
    [self printFormat];
}

-(void)	StartRecord
{
	int i, bufferByteSize;
	UInt32 size;
	//CFURLRef url;
	
    DDLogInfo(@"\nAQRecorder::StartRecord");
    // specify the recording format
    [self SetupAudioFormat:kAudioFormatLinearPCM];
    
    // create the queue
    OSStatus err = AudioQueueNewInput(&mRecordFormat,
                       MyInputBufferHandler,
                       (__bridge void*)self /* userData */,
                       NULL /* run loop */, NULL /* run loop mode */,
                       0 /* flags */, &mQueue);
    if(err)
    {
        DDLogInfo(@"\nAQRecorder: Error getting new inut audio queue");
        [Utilities print4char_errorcode:err];
    }
    // get the record format back from the queue's audio converter --
    // the file may require a more specific stream description than was necessary to create the encoder.

    size = sizeof(mRecordFormat);
    err = AudioQueueGetProperty(mQueue,
                          kAudioQueueProperty_StreamDescription,	
                          &mRecordFormat, 
                          &size);
    if(err)
    {
        DDLogInfo(@"\nAQRecorder: Error getting property kAudioQueueProperty_StreamDescription");
        [Utilities print4char_errorcode:err];
    }
    
    // allocate and enqueue buffers
    bufferByteSize = 1024*2; //ComputeRecordBufferSize(&mRecordFormat, kBufferDurationSeconds);	// enough bytes for half a second
    
    /*int frames = 0;
    
    frames = (int)ceil(kBufferDurationSeconds * mRecordFormat.mSampleRate);
    
    if (mRecordFormat.mBytesPerFrame > 0)
        bufferByteSize = frames * mRecordFormat.mBytesPerFrame;*/
    

    for (i = 0; i < kNumberRecordBuffers; ++i) 
    {
        AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]);
        //DDLogInfo(@"Audioqueue buffer size %d", bufferByteSize);
        AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }

    AudioQueueAddPropertyListener(mQueue, kAudioQueueProperty_IsRunning, AudioQueuePropertyListenerCallback, (__bridge void*)self);
    
    //pthread_mutex_lock(&mMutex);
    
    @synchronized(self)
    {
        // start the queue
        OSStatus err = AudioQueueStart(mQueue, NULL);
        if(err)
        {
            DDLogInfo(@"\n AudioQueueStart error=%ld\n", err);
            [Utilities print4char_errorcode:err];
            [self doError];
        }
        else 
        {
            DDLogInfo(@"\nAQRecorder: AQRecorder started");
            self.mAQRecorderState = BM_AR_WAITING_FOR_QUEUE_TO_START;
        }
    }
    
    //pthread_mutex_unlock(&mMutex);
}

-(void) doError
{
    DDLogInfo(@"\nAqRecorder: Do Error");
    UInt32 sessionCategory = 0;
    
   /* OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_AudioCategory,&size,&sessionCategory);
    
    if(error)
    {
        DDLogInfo(@"\nBMVC: Error AudioSessionSetProperty kAudioSessionProperty_AudioCategory: ");
        [Utilities print4char_errorcode:error];
    }
    else
    {
        NSLog(@"\nAQRecorder: Audio Category: %ld", sessionCategory);
        [Utilities print4char_errorcode:sessionCategory];
    }*/
    
    sessionCategory = kAudioSessionCategory_RecordAudio;
    
    OSStatus error = AudioSessionSetProperty (
                                     kAudioSessionProperty_AudioCategory,
                                     sizeof (sessionCategory),
                                     &sessionCategory
                                     );
    if(error)
    {
        DDLogInfo(@"\nAQRecorder: Error AudioSessionSetProperty kAudioSessionCategory_RecordAudio kAudioSessionProperty_AudioCategory: ");
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
            DDLogInfo(@"\nAQRecorder: Error AudioSessionSetProperty kAudioSessionCategory_PlayAndRecord kAudioSessionProperty_AudioCategory: ");
            [Utilities print4char_errorcode:error];
        }
//        else
//            DDLogInfo(@"\nAQRecorder: category set to kAudioSessionCategory_PlayAndRecord");
        
        OSStatus err = AudioQueueStart(mQueue, NULL);
        if(err)
        {
            DDLogInfo(@"\nAQRecorder AudioQueueStart error=%ld\n", err);
            [Utilities print4char_errorcode:err];
        }
        else
        {
           // DDLogInfo(@"\nAQRecorder: AQRecorder started");
            self.mAQRecorderState = BM_AR_WAITING_FOR_QUEUE_TO_START;
        }
    }
}

void AudioQueuePropertyListenerCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
 //   NSLog(@"\nAQRecorder: AudioQueuePropertyListenerCallback called");

    AQRecorder* recorder = (__bridge AQRecorder*) inUserData;
        
    [recorder handlePropertyListenerCallbackWithQueue:inAQ property:inID];
}

-(void)handlePropertyListenerCallbackWithQueue:(AudioQueueRef) inAQ property:(AudioQueuePropertyID)inID
{
  //  DDLogInfo(@"\nAQRecorder: handlePropertyListenerCallbackWithQueue current state = %d", mAQRecorderState);
    //pthread_mutex_lock(&mMutex);
    @synchronized(self)
    {
        @autoreleasepool
        {
            
            if(inID == kAudioQueueProperty_IsRunning)
            {
                if(self.mAQRecorderState == BM_AR_WAITING_FOR_QUEUE_TO_START)
                {
                  //  DDLogInfo(@"\nAQRecorder: AudioQueue is started");
                    self.mAQRecorderState = BM_AR_PLAYING;
                }
                else if(self.mAQRecorderState == BM_AR_WAITING_FOR_QUEUE_TO_STOP)
                {
                   // DDLogInfo(@"\nAQRecorder: AudioQueue is stopped");
                    self.mAQRecorderState = BM_AR_STOPPED;
                }
                else if(self.mAQRecorderState == BM_AR_WAITING_FOR_QUEUE_TO_PAUSE)
                {
                 //   DDLogInfo(@"\nAQRecorder: AudioQueue is paused");
                    self.mAQRecorderState = BM_AR_PAUSED;
                }
            }
            else 
            {
               // DDLogInfo(@"\n\nAQRecorder: AudioQueuePropertyListenerProc ID = %lu\n", inID);
            }
        }
    }
    //pthread_mutex_unlock(&mMutex);
    return;
}

-(BMErrorCode) pauseRecord
{
    if(self.mAQRecorderState != BM_AR_PLAYING)
        return BM_ERROR_FAIL;
  
    @synchronized(self)
    {
        OSStatus err = AudioQueuePause(mQueue);
        if(err)
        {
            DDLogInfo(@"\nAQRecorder: Recording paused failed");
            return BM_ERROR_FAIL;
        }
        
        self.mAQRecorderState = BM_AR_PAUSED;
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) resumeRecord
{
    if(self.mAQRecorderState != BM_AR_PAUSED)
    {
        DDLogInfo(@"\nAQRecorder: Cannot resume, not paused");
        return BM_ERROR_FAIL;
    }
    
    OSStatus err = AudioQueueStart(mQueue, nil);
    if (err)
    {
        DDLogInfo(@"\nAQRecorder: error resuming record");
        return BM_ERROR_FAIL;
    }
    
    return BM_ERROR_NONE;
}

-(void) StopRecord
{
	// end recording    
    if(self.mAQRecorderState != BM_AR_PAUSED && self.mAQRecorderState != BM_AR_PLAYING)
    {
        DDLogInfo(@"\nAQRecorder: StopRecording error: recorder is not in paused or recording state");
        return;
    }
    
   //printf("flushing\n");
    OSStatus err = AudioQueueFlush(mQueue);
    if (err) 
    { 
        DDLogInfo(@"\nAQRecorder:  AudioQueueFlush failed"); 
        return; 
    }	
    
    self.mAQRecorderState = BM_AR_WAITING_FOR_QUEUE_TO_STOP;

    err = AudioQueueStop(mQueue, false);
    if (err) 
    { 
        DDLogInfo(@"\nAQRecorder: AudioQueueStop failed"); 
        return; 
    }	


	//AudioQueueDispose(mQueue, true);
    
}

@end

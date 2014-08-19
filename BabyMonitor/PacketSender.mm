//
//  PacketSender.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "PacketSender.h"
#import "ControlPacket.h"
#include <stdlib.h>
#include <stdio.h>
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation PacketSender

@synthesize mInitialized;

-(BMErrorCode) setupControlStream:(NSOutputStream *)_outControlStream
{
    if(!_outControlStream)
    {
        DDLogInfo(@"\nopenControlStream: Error, invalid i/p param _outControlStream");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }
    
    if (_outControlStream != mPSOutControlStream)
    {
        mPSOutControlStream = _outControlStream;
    }

    mPSOutControlStream.delegate = self; 
    [mPSOutControlStream scheduleInRunLoop:[NSRunLoop currentRunLoop] 
                                                  forMode:NSDefaultRunLoopMode];
    [mPSOutControlStream open];
    
    //[mPSOutControlStream setProperty: NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
    
    //DDLogInfo(@"\nPacketSender: Control Stream Status = %d",[mControlStream streamStatus]);
    
    return BM_ERROR_NONE;

}


-(void) setproperties
{
    if(![mPSOutControlStream setProperty: NSStreamNetworkServiceTypeVoice forKey:NSStreamNetworkServiceType])
        DDLogInfo(@"\nPacketSender: error setting NSStreamNetworkServiceTypeVoice property");
    
    //if(![mPSOutControlStream setProperty: NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType])
      //  DDLogInfo(@"\nPacketReceiver: error setting NSStreamNetworkServiceTypeVoIP property");
}


-(BMErrorCode) shutdownControlStream
{
    //@synchronized(self)
    {
        if(mPSOutControlStream)
        {
            [mPSOutControlStream close];
            [mPSOutControlStream removeFromRunLoop:[NSRunLoop currentRunLoop] 
                                                          forMode:NSDefaultRunLoopMode];
            [mPSOutControlStream setDelegate:nil];
            mPSOutControlStream = nil;
        }
    }
    
    DDLogInfo(@"\nPacketSender: ControlStream closed");
    
    return BM_ERROR_NONE;
}

-(bool) isControlStreamReady
{
    if(!mPSOutControlStream)
        return NO;
    
    if( [mPSOutControlStream streamStatus] == NSStreamStatusOpen )
        return YES;
    else 
        return NO;
}

-(BMErrorCode) sendControlPacket:(const ControlPacket*) packet
{
    if(!packet)
    {
        DDLogInfo(@"\n Packet sender: Did not attempt send, invalid packet or length");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }
    
    if(!mPSOutControlStream)
    {
        DDLogInfo(@"\n Packet sender: Control stream not setup");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }
    
    __block NSInteger  error = 0;
    
    NSData* archivedPacket = [NSKeyedArchiver archivedDataWithRootObject:packet];
    
    if (!archivedPacket) 
    {
        DDLogInfo(@"\nPacketSender: Error archiving control packet before sending");
        return BM_ERROR_FAIL;
    }
    
    //DDLogInfo(@"\nPacketSender:sending packet length %d", [archivedPacket length]);
    
    dispatch_async(mBackgroundqueue, ^{
        
        @autoreleasepool {
            error = [mPSOutControlStream write:(uint8_t*)[archivedPacket bytes]
                                     maxLength:[archivedPacket length]];
        }
    });
    
    if(error == -1)
    {
        DDLogInfo(@"\nPacketSender:Failed sending control packet across to peer. Stream status = %d",
              [mPSOutControlStream streamStatus]);
        return BM_ERROR_FAIL;
    }
    
    return BM_ERROR_NONE;
}

-(void) dealloc
{
  //  DDLogInfo(@"\nPacketSender: deallocing PacketSender");
}
       
-(id) init
{
  //  DDLogInfo(@"\nPacketSender init...");
    mPSOutControlStream = nil;
    
    mIsOKForPacketSenderToSendMediaPackets = NO;
    
    //mNumOfMediaPacketSendTimeoutMissed = 0;

    mBackgroundqueue =  dispatch_queue_create("BackgroundQueue", NULL);
    if(!mBackgroundqueue)
        DDLogInfo(@"\nPacketSender: ERROR creating backgound queue");
    
    mPacketCountForDebug = 0;
    
    return self;
}

#pragma mark protocol functions

@end

#pragma mark -
@implementation PacketSender (NSStreamDelegate)

- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    /*DDLogInfo(@"\nPacket Sender Ctrl stream: %x, Media Stream: %x  stream: %x", 
          (unsigned int)mControlStream, 
          (unsigned int)mMediaStream, 
          (unsigned int)stream);*/
    
   // DDLogInfo(@"\nHandle event called with evetcode %d", eventCode);
    
    if(stream != mPSOutControlStream)
    {
        DDLogInfo(@"\nPacket Sender handle event: invalid Stream. Control Stream: %x, Input Stream: %x", 
              (unsigned int)mPSOutControlStream, 
              (unsigned int)stream);
        return;
    }
    
    switch(eventCode) 
    {
		case NSStreamEventOpenCompleted:
		{        
            if(stream == mPSOutControlStream)
            {
              // DDLogInfo(@"\nPacketSender: posting kNotificationPacketSenderToPMOutControlStreamOpenComplete");
                [[NSNotificationCenter defaultCenter] 
                 postNotificationName:kNotificationPacketSenderToPMOutControlStreamOpenComplete object:nil];
            }
            //DDLogInfo(@"\nPacketSender: NSStreamEventOpenCompleted code %d", eventCode);
            break;
		}
            
		case NSStreamEventHasBytesAvailable:
		{
//            DDLogInfo(@"\nPacketSender: NSStreamEventHasBytesAvailable code %d", eventCode);
            break;
		}
            
		case NSStreamEventErrorOccurred:
		{
            //TODO: we need to send an event to the SM/BMVC here so that the applicable error 
            //handling can be done
            NSError *theError = [stream streamError];
            NSString *str;
            if(stream == mPSOutControlStream)
            {
                [NSString stringWithFormat:@"PS COntrol Stream Error %i: %@",
                 [theError code], [theError localizedDescription]];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToSMControlStreamErrorOrEndOccured 
                                                                    object:nil];

                DDLogInfo(@"\nPacketSender: Control stream NSStreamEventErrorOccurred %@", str);
            }
        
            break;
		}
			
		case NSStreamEventEndEncountered:
		{
            //TODO: we need to send an event to the SM/BMVC here so that the applicable  
            //handling can be done
            if(stream == mPSOutControlStream)
           {               
               [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToSMControlStreamErrorOrEndOccured 
                                                                   object:nil];
           }
            DDLogInfo(@"\nPacketSender: NSStreamEventEndEncountered code %d", eventCode);
            break;
		}
            
        case NSStreamEventHasSpaceAvailable:
        {
            if(stream == mPSOutControlStream)
            {
                //DDLogInfo(@"\nPacketSender: kNotificationPacketSenderToPMControlStreamHasSpaceAvailable");
                [[NSNotificationCenter defaultCenter] 
                 postNotificationName:kNotificationPacketSenderToPMControlStreamHasSpaceAvailable object:nil];
            }
            break;
        }
            
        default:
        {
            DDLogInfo(@"\nPacketSender: Unhandled Event code is %d",eventCode);
            break;
        }
	}
}

@end

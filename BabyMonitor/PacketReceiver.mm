//
//  PacketReceiver.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "PacketReceiver.h"
#import "Utilities.h"
#import "ControlPacket.h"
#import "MediaPacket.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation PacketReceiver

//static PacketReceiver* sharedPacketReceiver = nil;

@synthesize mPRInControlStream;
@synthesize mInitialized;
@synthesize mControlPacketReceivedDelegate;
@synthesize mBackgroundqueue;

static const int NUMBER_OF_MEDIA_PACKET_BYTES_TO_BUFFER = 1024*2;


-(BMErrorCode) setupControlStream:(NSInputStream *)_outControlStream
{
    if(!_outControlStream)
    {
        DDLogInfo(@"\nPacketReceiver:invalid Control outstream to setup");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }
    
    //DDLogInfo(@"\nPacketReceiver: setupControlStream");
    if (mPRInControlStream != _outControlStream)
    {
        mPRInControlStream = _outControlStream;
    }
    
    mPRInControlStream.delegate = self; 
    
    //PM will turn the flag on whenever it is ready
    
    //[mPRInControlStream setProperty: NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
    
    [mPRInControlStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[mPRInControlStream open];
    
    return BM_ERROR_NONE;

}

-(void) setproperties
{
    if(![mPRInControlStream setProperty: NSStreamNetworkServiceTypeVoice forKey:NSStreamNetworkServiceType])
        DDLogInfo(@"\nPacketReceiver: error setting NSStreamNetworkServiceTypeVoice property");
    
    //if(![mPRInControlStream setProperty: NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType])
      //  DDLogInfo(@"\nPacketReceiver: error setting NSStreamNetworkServiceTypeVoIP property");

}

-(BMErrorCode) shutdownControlStream
{
    //@synchronized(self)
    {
        [mPRInControlStream close];
        [mPRInControlStream removeFromRunLoop:[NSRunLoop currentRunLoop] 
                                                      forMode:NSDefaultRunLoopMode];
        [mPRInControlStream setDelegate:nil];
        mPRInControlStream = nil;
    }
    
    DDLogInfo(@"\nPacketReceiver: ControlStream closed");
    return BM_ERROR_NONE;
}

-(bool) isControlStreamReady
{
    if(!mPRInControlStream)
        return NO;
    
    if( [mPRInControlStream streamStatus] == NSStreamStatusOpen )
        return YES;
    else 
        return NO;
}

-(void) dealloc
{
    //DDLogInfo(@"\nPacketReceiver: deallocing PacketReceiver");
}


-(id) init
{
 //   DDLogInfo(@"\nPacketReceiver init...");

    mNumberOfControlPacketBytesRemainingToBeRead = CTRL_PACKET_SIZE;
    mPRInControlStream = nil;
        
    mBackgroundqueue =  dispatch_queue_create("BackgroundQueue", NULL);
    
    if(!mBackgroundqueue)
        DDLogInfo(@"\nPacketReceiver: ERROR creating backgound queue");
    
    return self;
}

#pragma mark protocol functions


#pragma mark -
-(void) handleReadControlPacket
{
    if(!mPRInControlStream || [mPRInControlStream streamStatus] != NSStreamStatusOpen)
    {
        DDLogInfo(@"\nPacketReceiver: handleReadControlPacket error, no stream or not open");
        return;
    }

    if(mNumberOfControlPacketBytesRemainingToBeRead <= 0 )
    {
        //something went wrong here, we should have had outstanding bytes to be read by now
        DDLogInfo(@"\nPacketReceiver:handleReadControlPacket no bytes expected at this point");
        return;        
    }

    char bufferToReadInto[CTRL_PACKET_SIZE];
    NSInteger numberOfBytesRead = 0;
    NSData* controlPacketData;
        
    memset(bufferToReadInto, 0, CTRL_PACKET_SIZE);
    
    //read from stream
    numberOfBytesRead = [mPRInControlStream read:(uint8_t*)bufferToReadInto maxLength:CTRL_PACKET_SIZE];
    //DDLogInfo(@"\nPacketReceiver: numberOfBytesRead = %d", numberOfBytesRead);
    
    if(numberOfBytesRead > 0)
        controlPacketData = [NSData dataWithBytes:bufferToReadInto length:numberOfBytesRead];
    
    if(!numberOfBytesRead || !controlPacketData)
    {
        DDLogInfo(@"\nPacketReceiver: something went wrong with creating NSData");
        return;
    }
    
    [self handleControlPacketReadComplete:controlPacketData];
}

-(BMErrorCode) handleControlPacketReadComplete:(NSData*) controlPacketData
{
    //if the complete packet was read, go ahead and process it
    //DDLogInfo(@"\nPacketReceiver:handleControlPacketReadComplete");
    
    if(!controlPacketData || ![controlPacketData length])
    {
        DDLogInfo(@"\nPacketReceiver: No data to decode the control packet");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }

    ControlPacket *packet = [[ControlPacket alloc] init];
    
    @try 
    {
        packet = [NSKeyedUnarchiver unarchiveObjectWithData:controlPacketData];
        if(!packet)
        {
            [Utilities showAlert:@"Error receiving control packet"];
            return BM_ERROR_FAIL;
        }
    }
    @catch (NSException *exception) 
    {
        DDLogInfo(@"PacketReceiver: Caught %@: %@", [exception name], [exception reason]);
    }
    
    //DDLogInfo(@"\n PacketReceiver: Peer name in the control packet = %@", packet.mHostName);
    if(mControlPacketReceivedDelegate &&
       [mControlPacketReceivedDelegate respondsToSelector:@selector(didReceiveControlPacket:)])
    {
        [mControlPacketReceivedDelegate didReceiveControlPacket:packet];
    }
    
    //DDLogInfo(@"\n end handleControlPacketReadComplete");
    return BM_ERROR_NONE;
}

-(void) handleControlStreamEventWithCode:(NSStreamEvent)eventCode
{
    switch(eventCode) 
    {
		case NSStreamEventOpenCompleted:
		{
            DDLogInfo(@"\nPacketReceiver: ControlStream NSStreamEventOpenCompleted ");
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPacketReceiverToPmInControlStreamOpenComplete
                                                                object:nil];
            break;
		}
        
		case NSStreamEventHasBytesAvailable:
		{
            //DDLogInfo(@"\nPacketReceiver ControlStream NSStreamEventHasBytesAvailable");
            [self handleReadControlPacket];
            break;
		}
            
		case NSStreamEventErrorOccurred:
		{
            DDLogInfo(@"\nPacketReceiver:ControlStream NSStreamEventErrorOccurred code %d", eventCode);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToSMControlStreamErrorOrEndOccured 
                                                                object:nil];
            break;
		}
            
		case NSStreamEventEndEncountered:
		{
           // DDLogInfo(@"\nPacketReceiver: ControlStream NSStreamEventEndEncountered code %d", eventCode);
            
//            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToSMControlStreamErrorOrEndOccured 
//                                                                object:nil];
            break;
		}
            
        case NSStreamEventHasSpaceAvailable:
        {
            //DDLogInfo(@"\nPacketReceiver ControlStream NSStreamEventHasSpaceAvailable eventcode %d", eventCode);
            break;
        }
            
        default:
        {
            DDLogInfo(@"\nPacketReceiver ControlStream Event code is %d",eventCode);
            break;
        }
	}
    
}

@end 

@implementation PacketReceiver (NSStreamDelegate)

- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    /*DDLogInfo(@"\nPacketReceiver: handleEvent stream media: %x, control: %x, stream: %x",  
          (unsigned int)mPRInMediaStream, 
          (unsigned int)mPRInControlStream, 
          (unsigned int)stream);*/
    
    @synchronized(self)
    {       
        /*
        DDLogInfo(@"\nPacketReceiver: Media stream status: %d, Control Stream status: %d",  
              (unsigned int)[mPRInMediaStream streamStatus], 
              (unsigned int)[mPRInControlStream streamStatus]);*/
        
        if(mPRInControlStream && stream == mPRInControlStream)
        {
            [self handleControlStreamEventWithCode:eventCode];
        }
        else 
        {
            DDLogInfo(@"\nPacketReceiver: handle event: invalid stream Control Stream: %x, stream: %x", 
                  (unsigned int)mPRInControlStream, 
                  (unsigned int)stream);
            return;
        }
    }
}
@end

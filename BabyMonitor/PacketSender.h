//
//  PacketSender.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Utilities.h"
#import "BMUtility.h"
#import "ControlPacket.h"
#import "MediaPacket.h"
#import "AQRecorder.h"

@interface PacketSender : NSObject <NSStreamDelegate>
{
    NSOutputStream*		mPSOutControlStream;
    bool                mIsOKForPacketSenderToSendMediaPackets;
    
    dispatch_queue_t    	          mBackgroundqueue;    
    int                               mPacketCountForDebug;
}

-(BMErrorCode) setupControlStream:(NSOutputStream*)controlStream;
-(BMErrorCode) sendControlPacket:(const ControlPacket*) packet;
-(BMErrorCode) shutdownControlStream;

-(bool) isControlStreamReady;
-(void) setproperties;

@property  bool mInitialized;
@end

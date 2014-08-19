//
//  PacketReceiver.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Utilities.h"
#import "BMUtility.h"
#import "MediaPacket.h"
#import "dispatch/dispatch.h"
#import "ControlPacket.h"

@class PacketReceiver;

@protocol PacketReceiverDelegate <NSObject>
@optional
// This method will be invoked when a packet is received. Te delegate can be either the PM in case of a
//control packet or the Media Player in case of a media packet
- (void) didReceiveControlPacket:(ControlPacket *)packet;
@end

@interface PacketReceiver : NSObject <NSStreamDelegate>
{
        //Control stream related
    NSInputStream*		      	       mPRInControlStream;
    int              	               mNumberOfControlPacketBytesRemainingToBeRead;
    __weak id<PacketReceiverDelegate>  mControlPacketReceivedDelegate;
    dispatch_queue_t    	           mBackgroundqueue;
}

-(BMErrorCode) setupControlStream:(NSInputStream*)controlStream;
-(void) handleControlStreamEventWithCode:(NSStreamEvent)eventCode;
-(BMErrorCode) handleControlPacketReadComplete:(NSData*) controlPacketData;
-(void) handleReadControlPacket;
-(BMErrorCode) shutdownControlStream;
-(bool) isControlStreamReady;
-(void) setproperties;

@property (nonatomic, weak) id<PacketReceiverDelegate> mControlPacketReceivedDelegate;
@property (nonatomic) NSInputStream*                   mPRInControlStream;
@property                     bool                     mInitialized;
@property (nonatomic) dispatch_queue_t                 mBackgroundqueue;
@end

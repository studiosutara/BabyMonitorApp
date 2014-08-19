//
//  ProtocolManager.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PacketSender.h"
#import "PacketReceiver.h"
#import "Utilities.h"

@class ProtocolManager;

@protocol ProtocolManagerDelegate <NSObject>
@required
// This method will be invoked when a packet is received. Te delegate can be either the PM in case of a
//control packet or the Media Player in case of a media packet
-(BMErrorCode) OKToProcessControlPacketReceivedWithPacket:(ControlPacket*)packet;
@end

@interface ProtocolManager : NSObject <PacketReceiverDelegate, NSNetServiceDelegate> 
{
    __weak id<ProtocolManagerDelegate>  mPMDelegate;

    PacketSender*   mPacketSender;
    PacketReceiver* mPacketReceiver;
   
    bool            mInControlStreamReady;
    bool            mInMediaStreamReady;
    
    bool            mOutControlStreamReady;
    bool            mOutMediaStreamReady;
    
    bool            mSenderControlStreamHasSpace;
    bool            mSenderMediaStreamHasSpace;
    
    bool            mInitialized;
    
    //This is the netservice we are going to construct from the peer that sent us the handshake request
    // we will use this to resolve and opne the meida stream when the monitoring request is started 
    //from the peer that did not initiate the initial handshake.
    NSNetService*   mCurrentPeerToResolve;
}

-(BMErrorCode) setUpControlStreams:(NSNetService*) netService;
-(bool) areControlStreamsSetup;

-(BMErrorCode) assignAndOpenStreamsIn:(NSInputStream*)_inStream outStream:(NSOutputStream*)_outStream;
-(BMErrorCode) assignAndOpenControlStreamsIn:(NSInputStream*)_inStream outStream:(NSOutputStream*)_outStream;
-(BMErrorCode) resolvePeerAndOpenControlStreams:(NSString*) hostName;

- (void) controlStreamOpen:(NSNotification*) notification;
- (BMErrorCode) getPacketAndSendOfType:(ControlPacketType) type andError:(BMErrorCode) error;
-(void) shutdownControlStreams;
-(void) dissolveConnection;

- (BMErrorCode) getInitialHandshakePacketAndSendWithMode:(MonitorMode)mode;
- (BMErrorCode) getInitialHandshakeACKPacketAndSend:(BMErrorCode) error;

- (BMErrorCode) getStopMonitoringPacketAndSend;
- (BMErrorCode) getStopMonitoringACKPacketAndSend;

- (BMErrorCode) getStartMonitoringPacketAndSendWithPortNumber:(uint16_t)portnum;
- (BMErrorCode) getStartMonitoringACKPacketAndSendWithPortNumber:(uint16_t) portnum;

- (BMErrorCode) getChangeModePacketAndSend;
- (BMErrorCode) getPauseOnInterruptPacketAndSend;

-(BMErrorCode) getResumeAfterInterruptPacketAndSend;
-(BMErrorCode) getResumeAfterInterruptACKPacketAndSend;

-(BMErrorCode) getTalkToBabyStartPacketAndSendWithPortNumber:(uint16_t) portnum;
-(BMErrorCode) getTalkToBabyStartACKPacketAndSend;
-(BMErrorCode) getTalkToBABYEndPacketAndSend;
-(BMErrorCode) getTalkToBABYEndACKPacketAndSend;

-(BMErrorCode) getBatteryLevelPacketAndSend;

-(BMErrorCode) getPingPeerPacketAndSend;

-(void) processResumeAfterInterruptPacket:(ControlPacket*) packet;
-(void) processResumeAfterInterruptACKPacket:(ControlPacket*) packet;
-(void) processPauseOnInterruptPacket:(ControlPacket*) packet;

-(void) processTalkToBabyStartPacket:(ControlPacket*) packet;
-(void) processTalkToBabyStartACKPacket:(ControlPacket*) packet;
-(void) processTalkToBabyEndPacket:(ControlPacket*) packet;
-(void) processTalkToBabyEndACKPacket:(ControlPacket*) packet;

-(void) didReceiveControlPacket:(ControlPacket*)packet;
-(void) processDisconnectACKPacket:(ControlPacket*) packet;

-(void) processDisconnectPacket:(ControlPacket*) packet;

-(void) processToggleModePacket:(ControlPacket*) packet;
-(void) processToggleModeACKPacket:(ControlPacket*) packet;

-(void) processStopMonitoringPacket:(ControlPacket*) packet;
-(void) processStopMonitoringACKPacket:(ControlPacket*) packet;

-(void) processInitialHandshakeReqReceivedFromPeerWithPacket:(ControlPacket*) packet;
-(void) processInitialHandshakeACKReceivedFromPeer:(ControlPacket*) packet;

-(void) processPingReceivedFromPeer:(ControlPacket*) packet;
-(void) processPingACKReceivedFromPeer:(ControlPacket*) packet;

//-(BMErrorCode) composeAndSendMediaPacketWithData:(void*)mediaData withSize:(UInt32) sizeInBytes;

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict;
- (void)netServiceDidResolveAddress:(NSNetService *)service;

@property (nonatomic, weak)   id<ProtocolManagerDelegate> mPMDelegate;
@property (nonatomic, strong) PacketSender*               mPacketSender;
@property (nonatomic, strong) PacketReceiver*             mPacketReceiver;

@property                     bool                        mInControlStreamReady;
@property                     bool                        mInMediaStreamReady;

@property                     bool                        mOutControlStreamReady;
@property                     bool                        mOutMediaStreamReady;

@property                     bool                        mSenderControlStreamHasSpace;
@property                     bool                        mSenderMediaStreamHasSpace;

@property                     bool                        mInitialized;

@property (nonatomic, strong) NSNetService*               mCurrentPeerToResolve;
@end

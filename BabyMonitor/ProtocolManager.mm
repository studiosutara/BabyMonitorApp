//
//  ProtocolManager.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "ProtocolManager.h"
#import "ControlPacket.h"
#import "MediaPacket.h"
#import "PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation ProtocolManager

@synthesize mPacketSender;
@synthesize mPacketReceiver;
@synthesize mInControlStreamReady;
@synthesize mInMediaStreamReady;

@synthesize mOutControlStreamReady;
@synthesize mOutMediaStreamReady;

@synthesize mSenderControlStreamHasSpace;
@synthesize mSenderMediaStreamHasSpace;

@synthesize mInitialized;
@synthesize mPMDelegate;

@synthesize mCurrentPeerToResolve;

/******************************************************************************************************
 ******************************************************************************************************
                        SINGLETON CLASS RELATED FUNCTIONS
 ******************************************************************************************************
 *****************************************************************************************************/

-(void) dealloc
{
   // DDLogInfo(@"\nPM: deallocing ProtocolManager");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:nil];
}

-(id) init
{
  //  DDLogInfo(@"\nPM: ProtocolManager init...");
    mInControlStreamReady = NO;
    mInMediaStreamReady = NO;

    mOutControlStreamReady = NO;
    mOutMediaStreamReady = NO;

    mSenderControlStreamHasSpace = NO;
    mSenderMediaStreamHasSpace = NO;

    mInitialized = YES;

    mCurrentPeerToResolve = nil;
    mPacketSender = nil;
    mPacketReceiver = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receivedInitialHandshakeReq:)
                                                 name:kNotificationPacketReceiverToPMReceivedInitialHandshakeRequest
                                               object:nil];
    
    return self;
}


#pragma mark protocol functions

-(BMErrorCode) setUpControlStreams:(NSNetService*) netService
{

    NSInputStream		*_inControlStream;
    NSOutputStream		*_outControlStream;

    if (![netService getInputStream:&_inControlStream outputStream:&_outControlStream]) 
    {
        [Utilities showAlert:@"Failed to get control packets stream"];
        return BM_ERROR_NETSERVICE_STREAM_FAIL;
    }
//    DDLogInfo(@"\nFirst call to get CONTROL streams: %x and %x", 
//          (unsigned int)_inControlStream, 
//          (unsigned int)_outControlStream);
    
    if([self assignAndOpenControlStreamsIn:_inControlStream
                                               outStream:_outControlStream] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nCall to ProtocolManager assignAndOpenStreamsIn failed");
        return BM_ERROR_FAIL;
    }

    return BM_ERROR_NONE;
}

-(bool) areControlStreamsSetup
{
    if(!mPacketSender || !mPacketReceiver)
        return NO;
    
    return ([self.mPacketSender isControlStreamReady] && 
            [self.mPacketReceiver isControlStreamReady]);
}

-(BMErrorCode) assignAndOpenStreamsIn:(NSInputStream*)_inStream outStream:(NSOutputStream*)_outStream
{
    //we don't have the control streams setup yet. this is the first set of streams being setup
    if(![self areControlStreamsSetup])
    {
        return [self assignAndOpenControlStreamsIn:_inStream outStream:_outStream];
    }
            
    return BM_ERROR_NONE;
}

-(BMErrorCode) assignAndOpenControlStreamsIn:(NSInputStream*)_inStream outStream:(NSOutputStream*)_outStream
{
    if(!_inStream || !_outStream)
    {
        DDLogInfo(@"\nAssignAndOpenControlStreamsIn:outStream: invalid parameter");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }
    
    if([self areControlStreamsSetup])
    {
        DDLogInfo(@"\nError: Control stream alreeady setup");
        return BM_ERROR_FAIL;
    }
     
    if(!self.mPacketSender)
        self.mPacketSender = [[PacketSender alloc] init];

    if(!self.mPacketReceiver)
        self.mPacketReceiver = [[PacketReceiver alloc ] init ];

    if(!self.mPacketReceiver || !self.mPacketSender)
    {
        DDLogInfo(@"\nNo packet receiver!! or Sender!!");
        return BM_ERROR_FAIL;
    }
    
    //control stream for sender open 
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controlStreamOpen:)
                                                 name:kNotificationPacketSenderToPMOutControlStreamOpenComplete
                                               object:nil];
    
    //sender's control stream has space available
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controlStreamOpen:)
                                                 name:kNotificationPacketSenderToPMControlStreamHasSpaceAvailable
                                               object:nil];
       
    //Control stream for receiver open
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controlStreamOpen:)
                                                 name:kNotificationPacketReceiverToPmInControlStreamOpenComplete
                                               object:nil];
          
    DDLogInfo(@"\nSetting up control streams for the sender and the receiver");
    [self.mPacketReceiver setupControlStream:_inStream];
    [self.mPacketSender setupControlStream: _outStream];
        
    self.mPacketReceiver.mControlPacketReceivedDelegate = self;
    
  //  DDLogInfo(@"PM: assignAndOpenControlStreamsIn END");
    return BM_ERROR_NONE;
}

-(BMErrorCode) resolvePeerAndOpenControlStreams:(NSString*) hostName
{
    //NSNetService* netService 
    self.mCurrentPeerToResolve = [[NSNetService alloc] initWithDomain:@"local" 
                                                               type:[Utilities getBonjourType] 
                                                               name:hostName];
    
    [self.mCurrentPeerToResolve setDelegate:self];
    [self.mCurrentPeerToResolve resolveWithTimeout:1.0];
    
//    DDLogInfo(@"\nPM: Attempting to resolve name:%@ hostname:%@", 
//          [self.mCurrentPeerToResolve name], 
//          [self.mCurrentPeerToResolve hostName]);
//    
//    DDLogInfo(@"\nNetservice is %@", [self.mCurrentPeerToResolve description]);

    
    return BM_ERROR_NONE;
}

- (void) controlStreamOpen:(NSNotification*) notification
{
   // DDLogInfo(@"\nProtocolManager: ControlStreamOpen complete name is %@", [notification name]);
    if( [[notification name] isEqualToString:kNotificationPacketReceiverToPmInControlStreamOpenComplete] )
    {
        self.mInControlStreamReady = YES;
        //DDLogInfo(@"\nStreamOpen inControlStreamReady");
    }
    else if( [[notification name] isEqualToString:kNotificationPacketSenderToPMOutControlStreamOpenComplete] )
    {
        self.mOutControlStreamReady = YES;
        //DDLogInfo(@"\nStreamOpen OutControlStreamReady");
    }
    else if( [[notification name] isEqualToString:kNotificationPacketSenderToPMControlStreamHasSpaceAvailable] )
    {
        self.mSenderControlStreamHasSpace = YES;
        //DDLogInfo(@"\nStreamOpen mSenderControlStreamHasSpace");
    }
    
    if(self.mInControlStreamReady &&
       self.mOutControlStreamReady && 
       self.mSenderControlStreamHasSpace)
    {
     //   DDLogInfo(@"\nControl streams open and ready!!");
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToStateMachineControlStreamsOpen
                                                            object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                        name:kNotificationPacketSenderToPMControlStreamHasSpaceAvailable object:nil];
         [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                        name:kNotificationPacketReceiverToPmInControlStreamOpenComplete object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                        name:kNotificationPacketSenderToPMOutControlStreamOpenComplete object:nil];
    }
}

- (BMErrorCode) getPacketAndSendOfType:(ControlPacketType) type andError:(BMErrorCode) error
{
    if(type <= CONTROL_PACKET_TYPE_INVALID || type >= CONTROL_PACKET_TYPE_MAX ||
       error <= BM_ERROR_MIN_INVALID || error >= BM_ERROR_MAX)
        return BM_ERROR_INVALID_INPUT_PARAM;
    
    ControlPacket* packet = [ControlPacket getNewControlPacketWithType:type withError:error];
    
    if(!packet)
        return BM_ERROR_OUT_OF_MEMORY;
    
    if([self.mPacketSender sendControlPacket:(const ControlPacket*) packet] != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send packet");
        return BM_ERROR_FAIL;
    }
    
    packet = nil;
    
    return BM_ERROR_NONE;
}

-(void) shutdownControlStreams
{
    DDLogInfo(@"\nPM: shutting down control streams");
    self.mInControlStreamReady = NO;
    self.mOutControlStreamReady = NO;
    self.mSenderControlStreamHasSpace = NO;    
    
    [self.mPacketSender shutdownControlStream];
    [self.mPacketReceiver shutdownControlStream];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kNotificationPacketSenderToPMControlStreamHasSpaceAvailable object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kNotificationPacketReceiverToPmInControlStreamOpenComplete object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kNotificationPacketSenderToPMOutControlStreamOpenComplete object:nil];

}

-(void) dissolveConnection
{
    [self shutdownControlStreams];
    self.mPacketReceiver = nil;
    self.mPacketSender = nil;
}

- (BMErrorCode) getInitialHandshakePacketAndSendWithMode:(MonitorMode)mode
{
    //now send the initial handshake packet to the peer 
    ControlPacket* packet = [ControlPacket getNewHandshakePacketWithMode:mode];
    
    if(!packet)
        return BM_ERROR_OUT_OF_MEMORY;
    
    if([self.mPacketSender sendControlPacket:(const ControlPacket*)packet] != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST packet");
        return BM_ERROR_FAIL;
    }
    else 
    {
       // DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST packet");
    }
    
    packet = nil;
    
    return BM_ERROR_NONE;
}

- (BMErrorCode) getInitialHandshakeACKPacketAndSend:(BMErrorCode) errorACK
{
    ControlPacket* packet = [ControlPacket getNewHandshakeACKPacketWithError:errorACK];
    
    if(!packet)
        return BM_ERROR_OUT_OF_MEMORY;
    
    if([self.mPacketSender sendControlPacket:(const ControlPacket*)packet] != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK packet");
        [self shutdownControlStreams];
        return BM_ERROR_FAIL;
    }
    else
    {
      //  DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK packet");
    }
    
    packet = nil;
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) getStopMonitoringPacketAndSend
{
   // DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_STOP_MONITORING packet");

    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_STOP_MONITORING 
                                                andError:BM_ERROR_NONE];
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_STOP_MONITORING packet");

    }
    else 
    {
       // DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_STOP_MONITORING packet");
    }
    
    return error;
}

-(BMErrorCode) getStopMonitoringACKPacketAndSend
{
    
    return BM_ERROR_NONE;
}

- (BMErrorCode) getStartMonitoringPacketAndSendWithPortNumber:(uint16_t)portnum
{
    ControlPacket* packet = [ControlPacket
                             getNewStartMonPacketWithMode:[PersistentStorage readSMModeFromPersistentStorage]
                              andPortNum:portnum];
    
    if(!packet)
        return BM_ERROR_OUT_OF_MEMORY;
    
    BMErrorCode error = BM_ERROR_NONE;        
    error = [self.mPacketSender sendControlPacket:(const ControlPacket*) packet];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_START_MONITORING packet");
        
    }
    else 
    {
      //  DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_START_MONITORING packet");
        return error;
    }
    
    return BM_ERROR_NONE;
}

- (BMErrorCode) getStartMonitoringACKPacketAndSendWithPortNumber:(uint16_t) portnum
{
    ControlPacket* packet = [ControlPacket getNewStartMonACKPacketWithPortNum:portnum];
    
    if(!packet)
        return BM_ERROR_OUT_OF_MEMORY;

    BMErrorCode error = BM_ERROR_NONE;
    error = [self.mPacketSender sendControlPacket:(const ControlPacket*) packet];

    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_START_MONITORING_ACK packet");
    }
    else 
    {
       // DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_START_MONITORING_ACK packet");
    }
    
    return error;
}

-(BMErrorCode) getChangeModePacketAndSend
{
    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_TOGGLE_MODE
                                                andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_TOGGLE_MODE packet");
        
    }
    else 
    {
       // DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_TOGGLE_MODE packet");
    }
    
    return error;
}

-(BMErrorCode) getPauseOnInterruptPacketAndSend
{
    BMErrorCode error =   [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT
                               andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT packet");
        
    }
    else 
    {
     //   DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT packet");
    }
    
    return error;

}

-(BMErrorCode) getResumeAfterInterruptPacketAndSend
{
    BMErrorCode error =   [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT
                               andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT packet");
        
    }
    else 
    {
     //   DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT packet");
        
    }
    
    return error;

}

-(BMErrorCode) getResumeAfterInterruptACKPacketAndSend
{
    DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK packet");
    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK
                               andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK packet");
        
    }
    else 
    {
        DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK packet");
        
    }
    
    return error;
}

-(BMErrorCode) getTalkToBabyStartPacketAndSendWithPortNumber:(uint16_t) portnum
{
    ControlPacket* packet = [ControlPacket getNewStarTalkToBabyPacketWithMode:[PersistentStorage readSMModeFromPersistentStorage]
                                                             andPortNum:portnum];
    if(!packet)
        return BM_ERROR_OUT_OF_MEMORY;
    
    BMErrorCode error = BM_ERROR_NONE;        
    error = [self.mPacketSender sendControlPacket:(const ControlPacket*) packet];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_TALK_TO_BABY_START packet");
        
    }
    else 
    {
     //   DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_TALK_TO_BABY_START packet");
        return error;
    }
    
    return error;
}

-(BMErrorCode) getTalkToBabyStartACKPacketAndSend
{
    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK
                                             andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK packet");
        
    }
    else 
    {
     //   DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK packet");
    }
    
    return error;
}

-(BMErrorCode) getTalkToBABYEndPacketAndSend
{
    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_TALK_TO_BABY_END
                                             andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_TALK_TO_BABY_END packet");
        
    }
    else 
    {
      //  DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_TALK_TO_BABY_END packet");
    }
    
    return error;
}

-(BMErrorCode) getBatteryLevelPacketAndSend
{
    ControlPacket* packet = [ControlPacket getNewBatteryLevelPacketWithCurrentLevel];
    
    if(!packet)
    {
        return BM_ERROR_FAIL;
    }
    BMErrorCode error = [self.mPacketSender sendControlPacket:packet];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_BATTERY_LEVEL_INFO packet");
        
    }
    else
    {
     //   DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_BATTERY_LEVEL_INFO packet");
    }
    
    return error;

}

-(BMErrorCode) getTalkToBABYEndACKPacketAndSend
{
    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_TALK_TO_BABY_END_ACK
                                             andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_TALK_TO_BABY_END_ACK packet");
        
    }
    else 
    {
      //  DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_TALK_TO_BABY_END_ACK packet");
    }
    
    return error;
}

-(BMErrorCode) getPingPeerPacketAndSend
{
    BMErrorCode error =  [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_PING_PEER
                                             andError:BM_ERROR_NONE];
    
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"PM: Error: PacketSender failed to send CONTROL_PACKET_TYPE_PING_PEER packet");
        
    }
    else 
    {
       // DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_PING_PEER packet");
    }
    
    return error;
}
/////////////////////PacketReceiverDelgate functions//////////////////////////////////////////////////

- (void) didReceiveControlPacket:(ControlPacket*)packet
{
   // DDLogInfo(@"\ndidReceiveControlPacket");

    if(!packet)
    {
        DDLogInfo(@"\n PM: INVALID CONTROL PACKET RECEIVED");
        return;
    }
    
    if(!mInitialized)
    {
        DDLogInfo(@"\nPM: PM is uninitialized");
        return;
    }
    
    ControlPacketType ctrlCode = [packet getControlCode];
    
    switch (ctrlCode) 
    {
        case CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST:
          //  DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST packet");
            [self processInitialHandshakeReqReceivedFromPeerWithPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK packet");
            
            [self processInitialHandshakeACKReceivedFromPeer:packet];
            break;
            
        case CONTROL_PACKET_TYPE_START_MONITORING:
          //  DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_START_MONITORING packet");
            
            [self processStartMonitoringPacket:packet];             
            break;
       
        case CONTROL_PACKET_TYPE_START_MONITORING_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_START_MONITORING_ACK packet");
            
            [self processStartMonitoringACKPacket:packet];             
            break;

        case CONTROL_PACKET_TYPE_STOP_MONITORING:
            DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_STOP_MONITORING packet");
            
            [self processStopMonitoringPacket:packet];             
            break;
            
        case CONTROL_PACKET_TYPE_STOP_MONITORING_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_STOP_MONITORING_ACK packet");
            [self processStopMonitoringACKPacket:packet];             
            break;
            
        case CONTROL_PACKET_TYPE_TOGGLE_MODE:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_TOGGLE_MODE packet");
            [self processToggleModePacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_TOGGLE_MODE_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_TOGGLE_MODE_ACK packet");
            [self processToggleModeACKPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER:
        //    DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER packet");
            [self processDisconnectPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER_ACK:
          //  DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER_ACK packet");
            [self processDisconnectACKPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT packet");
            [self processPauseOnInterruptPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT:
           // DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT packet");
            [self processResumeAfterInterruptPacket:packet];
            break;
        
        case CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK:
           // DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK packet");
            [self processResumeAfterInterruptACKPacket:packet];
            break;

        case CONTROL_PACKET_TYPE_TALK_TO_BABY_START:
        //    DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_TALK_TO_BABY_START packet");
            [self processTalkToBabyStartPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK packet");
            [self processTalkToBabyStartACKPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_TALK_TO_BABY_END:
          //  DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_TALK_TO_BABY_END packet");
            [self processTalkToBabyEndPacket:packet];
            break;
            
        case CONTROL_PACKET_TYPE_TALK_TO_BABY_END_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_TALK_TO_BABY_END_ACK packet");
            break;
            
        case CONTROL_PACKET_TYPE_PING_PEER:
            [self processPingReceivedFromPeer:packet];
            break;
            
        case CONTROL_PACKET_TYPE_PING_PEER_ACK:
         //   DDLogInfo(@"\nPM: Received CONTROL_PACKET_TYPE_PING_PEER_ACK packet");
            [self processPingACKReceivedFromPeer:packet];
            break;
            
        case CONTROL_PACKET_TYPE_BATTERY_LEVEL_INFO:
            [self processBatteryLevelUpdateReceived:packet];
            break;
            
        default:
         //   [Utilities showAlert:@"PM: RECIEVED INVALID CONTROL PACKET"];
            break;
    }
}
 
-(void) processResumeAfterInterruptPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the pause on interrupt packet");
        }
        else 
        {
            [self getResumeAfterInterruptACKPacketAndSend];
        }
    }
}

-(void) processResumeAfterInterruptACKPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the pause on interrupt packet");
        }
    }
}

-(void) processTalkToBabyStartPacket:(ControlPacket *)packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the Start Takl to Baby packet");
        }
        else 
        {
            [self getTalkToBabyStartACKPacketAndSend];
        }
    }
}

-(void) processTalkToBabyStartACKPacket:(ControlPacket *)packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the Start Talk to Baby ACK packet");
        }
    }
}

-(void) processTalkToBabyEndPacket:(ControlPacket *)packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the End talk to Baby  packet");
        }
//        else 
//        {
//            [self getTalkToBABYEndACKPacketAndSend];
//        }
    }
}

-(void) processTalkToBabyEndACKPacket:(ControlPacket *)packet
{
//    BMErrorCode error = BM_ERROR_NONE;
//    
//    if(mPMDelegate &&
//       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
//    {
//        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
//        //If the SM is OK receiving this packet, go ahead and finish up from PM side
//        if(error != BM_ERROR_NONE)
//        {
//            DDLogInfo(@"\nPM: SM not ready to process the End Talk to Baby ACK packet");
//        }
//    }
}

-(void) processPauseOnInterruptPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];
        
              //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the pause on interrupt packet");
        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToMainViewPeerPausedOnCallInterrupt
                                                                object:nil];
        }
    }
}


-(void) processDisconnectPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //IF the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error == BM_ERROR_NONE)
        {
            //We do not want to leave the send of the ACK to the PM just in this case.
            //As we need to make sure that the send is complete before we go ahead and close the streams.
            error = [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER_ACK 
                                        andError:error];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error sending disconnect ACK to the peer");
            }
            
            [self dissolveConnection];
            
        }
        else 
        {
            DDLogInfo(@"\nPM: SM not ready to disconnect. Sending error ACK");
        }
        
    }
}

-(void) processDisconnectACKPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        //If the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nPM: SM not ready to process the disconnect ACK packet");
        }
    }
}

-(void) processToggleModePacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];        
        
        //IF the SM is OK receiving this packet, go ahead and finish up from PM side
//        if(error == BM_ERROR_NONE)
//            DDLogInfo(@"\nPM:Sent CONTROL_PACKET_TYPE_TOGGLE_MODE_ACK success packet");
//        else 
//            DDLogInfo(@"\nPM:Sent CONTROL_PACKET_TYPE_TOGGLE_MODE_ACK error packet");
        
        [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_TOGGLE_MODE_ACK andError:error];
    }
}

-(void) processToggleModeACKPacket:(ControlPacket*) packet
{
    UIAlertView* alertView = nil;
    NSString* desc = nil;
    
    if(packet.mControlAckErrorCode == BM_ERROR_NONE)
    {
        desc = [NSString stringWithFormat:@"Peer changed mode successfully"];
    }
    else 
    {
        desc = [NSString stringWithFormat:@"Error changing peer's mode"];

        alertView = [[UIAlertView alloc] initWithTitle:Nil 
                                               message:desc 
                                              delegate:self 
                                     cancelButtonTitle:@"OK" 
                                     otherButtonTitles:nil];
        [alertView show];
    }
    
}

//This func is called when the peer asks us to stop by sending us a STOP packet
-(void) processStopMonitoringPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];        
        
        //IF the SM is OK receiving this packet, go ahead and finish up from PM side
        if(error == BM_ERROR_NONE)
        {            
        //    DDLogInfo(@"\nPM:Sent CONTROL_PACKET_TYPE_STOP_MONITORING_ACK packet");
            [self getPacketAndSendOfType:CONTROL_PACKET_TYPE_STOP_MONITORING_ACK andError:BM_ERROR_NONE];
        }
            
    }
}

-(void) processStopMonitoringACKPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];   
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nProtocolManager: SM is not ok to process STOP MON ACK packet");
        }
    }
}

-(void) processStartMonitoringPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];  
    }
}

-(void) processStartMonitoringACKPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];  
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nProtocolManager: SM is not ok to process START MON ACK packet");
        }
    }
}

-(void) processInitialHandshakeReqReceivedFromPeerWithPacket:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;

    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        DDLogInfo(@"\nPM: peer name that sent packet = %@", packet.mHostName);
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];        
  
        //If the stream open is pending, then we will be sending the ACK packet later
        if(error == BM_ERROR_SM_STREAM_OPEN_PENDING)
        {
            // DDLogInfo(@"\nReceived initial handshake req frm peer, but waiting for streams to open");
        }
        else 
        {
            ControlPacket* initialHandshakeACKPacket = [ControlPacket getNewHandshakeACKPacketWithError:error];

            if(!initialHandshakeACKPacket)
            {
                DDLogInfo(@"\nPM: Unable to get the initial handshake ACK packet");
                return;
            }
            
         //   DDLogInfo(@"\nSending initial handshake ACK packet with code %d", error);
            [self.mPacketSender sendControlPacket:(const ControlPacket*)initialHandshakeACKPacket];
            
            initialHandshakeACKPacket = nil;

        }
        
        if(error == BM_ERROR_SM_STREAM_OPEN_PENDING || error == BM_ERROR_NONE)
        {
           // NSLog(@"\nPM: Battery level = %@", [NSNumber numberWithInt:packet.mBatteryLevel]);

            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToMainViewPeerBatteryLevelUpdate
                                                                object:[NSNumber numberWithInt:packet.mBatteryLevel]];
            
        }
        //If the handshake req failed, then shutdown the control streams
        else 
        {
            [self shutdownControlStreams];
        }                
    }      
}


-(void) processInitialHandshakeACKReceivedFromPeer:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {        
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];        
        
        //We just received an ACK from the peer for a handshake req we sent
        //and the statemachine is OK with it
        if(error == BM_ERROR_NONE)
        {
            //if the ACK is success, then we are connected to a peer and OK to go
            //notify UI to mark as connected 
            if(packet.mControlAckErrorCode == BM_ERROR_NONE)
            {
             //   NSLog(@"\nPM: Battery level = %@", [NSNumber numberWithInt:packet.mBatteryLevel]);
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToMainViewPeerBatteryLevelUpdate
                                                                    object:[NSNumber numberWithInt:packet.mBatteryLevel]];

             //   DDLogInfo(@"\nPM: connection to peer successful");
            }
            else if(packet.mControlAckErrorCode == BM_ERROR_SM_PEER_NOT_IN_EXPECTED_MODE)
            {
              //  DDLogInfo(@"\nPM: Peer not in the opposite mode. Change and try again");
                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Error" 
                                                       message:@"Peer not in the opposite mode. Change and try again"
                                                      delegate:self 
                                             cancelButtonTitle:@"OK" 
                                             otherButtonTitles:nil];
                [alertView show];
            }
            else 
            //if the ACK was a failure, then the connection req failed throw an error
            {
                DDLogInfo(@"\nPM: Peer not in the opposite mode. Change and try again");
                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Error" 
                                                                    message:@"Failed to connect with peer"
                                                                   delegate:self 
                                                          cancelButtonTitle:@"OK" 
                                                          otherButtonTitles:nil];
                [alertView show];

            }
        }
        //SM thinks for some reason that it is not in the right state to receive the ACK packet
        else
        {
            ControlPacket* unexpectedPacket = [ControlPacket getNewControlPacketWithType:CONTROL_PACKET_TYPE_UNEXPECTED_PACKET_RECEIVED
                                                                               withError:error];
            if(!unexpectedPacket)
                return;
            
        //    DDLogInfo(@"\nSending Unexpected packet received");
            [self.mPacketSender sendControlPacket:(const ControlPacket*)unexpectedPacket];

            unexpectedPacket = nil;
            
          //  [Utilities showAlert:@"Not OK to process packet received"];
           // DDLogInfo(@"\nNot OK to process packet received");
        }
        
    }      
}

-(void) processPingReceivedFromPeer:(ControlPacket*) packet
{
    if([self getPacketAndSendOfType:CONTROL_PACKET_TYPE_PING_PEER_ACK andError:BM_ERROR_NONE] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nPM: Failed to send the CONTROL_PACKET_TYPE_PING_PEER_ACK packet");
    }
    else 
    {
   //     DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_PING_PEER_ACK packet");
    }
}

-(void) processPingACKReceivedFromPeer:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mPMDelegate &&
       [mPMDelegate respondsToSelector:@selector(OKToProcessControlPacketReceivedWithPacket:)])
    {
        error = [mPMDelegate OKToProcessControlPacketReceivedWithPacket:packet];  
    }
}

-(void) processBatteryLevelUpdateReceived:(ControlPacket*) packet
{
 //   DDLogInfo(@"\nPM: processBatteryLevelUpdateReceived");
   // NSLog(@"\nPM: Battery level = %@", [NSNumber numberWithInt:packet.mBatteryLevel]);

    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToMainViewPeerBatteryLevelUpdate
                                                        object:[NSNumber numberWithInt:packet.mBatteryLevel]];
}

///NSNetServiceDelegate

// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict 
{
  //  DDLogInfo(@"\nPM: Netservice for peer did not resolve %@", [errorDict objectForKey:NSNetServicesErrorCode]);
    
    if(![self areControlStreamsSetup])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPMToSMControlStreamOpenFailed 
                                                            object:nil];
    }
    
    [self.mCurrentPeerToResolve stop];
	 self.mCurrentPeerToResolve = nil;
}

- (void)netServiceDidResolveAddress:(NSNetService *)service 
{
  //  DDLogInfo(@"\nPM: Netservice for peer did resolve");
    
    if(![self areControlStreamsSetup])
    {
        [self setUpControlStreams:service];
    }
}

@end

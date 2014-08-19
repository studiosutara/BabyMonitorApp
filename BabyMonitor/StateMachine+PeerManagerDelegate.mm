//
//  StateMachine+PeerManagerDelegate.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/9/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+PeerManagerDelegate.h"
#import "DDLog.h"
#import "PersistentStorage.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (PeerManagerDelegate)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (BMErrorCode) peerCameOnline:(NSNetService*) netService
{
    BMErrorCode error = BM_ERROR_NONE;
    
    //Do nothing here for now.
    //The peer that is coming back online should be handling this case
    
  //  DDLogInfo(@"\nStateMachine: Peer came online in state %@", [mReadableStateTable objectAtIndex:self.mCurrentState]);
    
    return error;
}

- (BMErrorCode) peerWentOffline:(NSNetService*) netService
{
    BMErrorCode error = BM_ERROR_NONE;
    
    DDLogInfo(@"StateMachine: peerWentOffline in state %@", [mReadableStateTable objectAtIndex:self.mCurrentState]);
    
    if(self.mCurrentState == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING)
        return BM_ERROR_NONE;
    
    //if we are currently monitoring?
    if( (self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE && 
         self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)  ||
       
        (self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE &&
            self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA) )
    {
        [self userWantsToStopMonitoring:NO];
        
        [NSTimer scheduledTimerWithTimeInterval:1
                                         target:self
                                       selector:@selector(showLostConnectionAlertWithSound)
                                       userInfo:nil
                                        repeats:NO];
        

    }

    //if we are connected but not monitoring
    //shut down streams
    [self.mProtocolManager shutdownControlStreams];
    //mark as not connected
    
    NSLog(@"Before disconnectComplete");
    [self disconnectComplete];
    //if we are not connected, then we should not even be getting this callback??
    
    return error;
}

- (BMErrorCode) requestInitialHandshakeAfterResolve:(NSNetService*) netService
{
    
    DDLogInfo(@"\nrequestInitialHandshakeAfterResolve");
    //validate netservice first
    
    if(!netService)
    {
  //      DDLogInfo(@"\nStateMachine: NetService invalid");
        return BM_ERROR_INVALID_INPUT_PARAM;
    }
        
    return [self initiateInitialHandShakeWithPeer:netService];
}

-(BMErrorCode) initiateInitialHandShakeWithPeer:(NSNetService*) data
{
    BMErrorCode error = BM_ERROR_NONE;
    
//    DDLogInfo(@"\nStateMachine: initiateInitialHandShakeWithPeer mCurrentState=%@",
//              [mReadableStateTable objectAtIndex:mCurrentState]);
    NSNetService* netService = (NSNetService*) data;

    switch(self.mCurrentState)
    {
        //We will get here only when we are restarting the app, after having been previously connected
        case STATE_INITIALIZED:
        {
            self.mPeerManager.mCurrentlyConnectedPeer = netService;
            
            if(netService)
            {
                error = [self.mProtocolManager setUpControlStreams:netService];
            }
            else
            {
                error = [self.mProtocolManager
                         resolvePeerAndOpenControlStreams:[PersistentStorage readPeerNameFromPersistentStorage]];
            }
            
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error: opening control streams");
                return error;
            }
            else
            {
                //Wait till the streams are open
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(controlStreamsOpenCallback)
                                                             name:kNotificationPMToStateMachineControlStreamsOpen
                                                           object:nil];
                
                self.mCurrentState = STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ;
            }
            
           break;
        }
            
        case STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING:
        {
      //      DDLogInfo(@"\nStateMachine: initiateInitialHandshake hostname = %@",
                 // self.mPeerManager.mCurrentPeerHostName);
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(controlStreamsOpenCallback)
                                                         name:kNotificationPMToStateMachineControlStreamsOpen
                                                       object:nil];
            error = [self.mProtocolManager 
                     resolvePeerAndOpenControlStreams:[PersistentStorage readPeerNameFromPersistentStorage]];
            
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error: opening control streams");
                return error;
            }
            else
            {
                //Wait till the streams are open
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(controlStreamsOpenCallback)
                                                             name:kNotificationPMToStateMachineControlStreamsOpen
                                                           object:nil];
                
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(controlStreamOrResolveFailed)
                                                             name:kNotificationPMToSMControlStreamOpenFailed
                                                           object:nil];

                
                self.mCurrentState = STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ;
            }

            break;
        }
            
        case STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED:
        {
          //  DDLogInfo(@"\nStateMachine: PM to send the initial handshake packet");
            error = [self.mProtocolManager getInitialHandshakePacketAndSendWithMode:self.mCurrentBabyMonitorMode];
            if(error == BM_ERROR_NONE)
            {
                self.mCurrentState = STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING;
                [self startHandshakeReqResponseTimer];
                return error;
            }
            
            break;
        }
              
        case STATE_CONNECTED_TO_PEER:
        {
            //we are currently connected to another, or possibly the same peer.
            break;
        }
            
        default:
            DDLogInfo(@"\nStateMachine: BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD");
            error = BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD;
            break;
            
    }
    
    return error;
}

- (void) receiveMediaPacketTimeoutMaxed
{
    //if we are monitoring indeed and are in parent mode, then this timeout might mean that the connection with peer 
    //is lost. If the peer lost wi-fi then the peer manager will not know about it
    //this is one way to know about it.
 
  //  DDLogInfo(@"\nStateMachine: receiveMediaPacketTimeoutMaxed");

    if(self.mCurrentState == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING ||
       self.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY ||
       self.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT)
        return;
    
    self.mCurrentState = STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING;
    [self pingPeerAndWaitForResponse];
    //treat this as stop monitoring
    //[self userWantsToStopMonitoring:YES];
}

- (void) sendMediaPacketTimeoutMaxed
{
   // DDLogInfo(@"\nStateMachine: sendMediaPacketTimeoutMaxed in state %@", [mReadableStateTable objectAtIndex:self.mCurrentState]);
    [self pingPeerResponseTimerFired];
}

- (void) socketCloseDueToNetworkConnectionLoss
{
    [self networkConnectionLost];
}

-(void) pingPeerAndWaitForResponse
{
    if([self.mProtocolManager getPingPeerPacketAndSend] != BM_ERROR_NONE)
    {
     //   DDLogInfo(@"\nStateMachine: Failed to send Ping Packet to peer. Assuming connection is dead");
    }
    else 
    {
        [self startPingPeerResponseTimer];
        //start a timer so we know if the peer does not respond
    }
}

-(BMErrorCode) receivedPingAckFromPeer
{
    if(self.mCurrentState == STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING)
    {
      //  DDLogInfo(@"\nStateMachine: The peer is still alive but we are not receiving any packets.");
        
        if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
            self.mCurrentState = STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA;
        else if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
            self.mCurrentState = STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA;
    }
    else 
    {
//        DDLogInfo(@"\nStateMachine: Received Ping ACK from peer in worng state %@", 
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);
    }
    
    [self stopPingPeerResponseTimer];
    
    return BM_ERROR_NONE;
}

-(void) startPingPeerResponseTimer
{
    DDLogInfo(@"\nStateMachine: Starting wait for PingPeerResponseTimer");
    if(mPingPeerResponseTimer)
    {
        [mPingPeerResponseTimer invalidate];
        mPingPeerResponseTimer = nil;
    }
    
    ///wait for the peer to get back connection
    mPingPeerResponseTimer = [NSTimer scheduledTimerWithTimeInterval:1 
                                                              target:self 
                                                            selector:@selector(pingPeerResponseTimerFired) 
                                                            userInfo:nil                                                                
                                                             repeats:YES];
}

-(void) stopPingPeerResponseTimer
{
    if(mPingPeerResponseTimer)
    {
        [mPingPeerResponseTimer invalidate];
        mPingPeerResponseTimer = nil;
    }     
}

-(void) pingPeerResponseTimerFired
{

    if(self.mCurrentState == STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING)
    {
       // DDLogInfo(@"\nStateMachine: Timeout: No Response to Ping from Peer.");
        [self userWantsToStopMonitoring:NO];

        if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
        {
            [NSTimer scheduledTimerWithTimeInterval:1
                                             target:self
                                           selector:@selector(showLostConnectionAlertWithSound)
                                           userInfo:nil
                                            repeats:NO];
        }

        [self disconnectComplete];
    }
    else 
    {
//        DDLogInfo(@"\nStateMachine: Ping Response timer fired while in in worng state %@", 
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);
    }
    
    [self stopPingPeerResponseTimer];
}

-(void) reachabilityChanged:(NetworkStatus)status
{
    if(status == NotReachable)
    {
        [self networkConnectionLost];
    }
    else if(status == ReachableViaWiFi)
    {
      //  DDLogInfo(@"\nStateMachine: Now reachable via Wifi");
        [self networkConnectionRegained];
    }
}

-(void) networkConnectionLost
{
    if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA ||
       self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
       self.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY)
    {
        DDLogInfo(@"\nStateMachine: Wi-fi connection lost while monitoring");
        if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
        {
            [mMediaRecorder StopRecording];
        }
        else if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE) 
        {
            [NSTimer scheduledTimerWithTimeInterval:1
                                             target:self
                                           selector:@selector(showLostConnectionAlertWithSound)
                                           userInfo:nil
                                            repeats:NO];
            [mMediaPlayer StopPlaying];
        }
        
        [self.mPeerManager.mPeerManagerServer disableBonjour];

        self.mCurrentState = STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING;
    }
}

-(void) networkConnectionRegained
{
   // DDLogInfo(@"StateMachine: networkConnectionRegained");
    
    if(![self.mPeerManager.mPeerManagerServer enableBonjourWithDomain:@"local" 
                                                  applicationProtocol:[Utilities getBonjourType] 
                                                                 name:nil]) 
    {
       // DDLogInfo(@"\nStateMachine: networkConnectionRegained: Failed advertising server");
        return;
    }
    
    if(self.mCurrentState == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING)
    {
        if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
        {
            [self restartMonitoringAfterInterrupt];
            
            if(![self.mPeerManager.mPeerManagerServer enableBonjourWithDomain:@"local"
                                                          applicationProtocol:[Utilities getBonjourType]
                                                                         name:nil])
            {
                DDLogInfo(@"\nStateMachine: Failed advertising server");
            }
        }
        else
        {
        //    DDLogInfo(@"\nStateMachine: regained connection while receiving media.");
            BMErrorCode error = [self.mProtocolManager resolvePeerAndOpenControlStreams:[PersistentStorage readPeerNameFromPersistentStorage]];

            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error: Opening the media streams for sender and receiver");
                return;
            }
            
            self.mCurrentState = STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA;
        }
    }
}

#pragma clang diagnostic pop

@end

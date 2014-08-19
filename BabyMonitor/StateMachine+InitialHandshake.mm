//
//  StateMachine+InitialHandshake.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/25/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+InitialHandshake.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (InitialHandshake)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

-(BMErrorCode) isOKToProcessHandshakeRequestFromPeer:(ControlPacket*) packet
{
    BMErrorCode error = BM_ERROR_NONE;
   // DDLogInfo(@"StateMachine isOKToProcessHandshakeRequestFromPeer mCurrentState=%d", mCurrentState);
    
    switch(self.mCurrentState)
    {

            //the stream is unopen. the PM will have to wait till both the streams are open
            //before continuing any further
        case STATE_CONTROL_STREAM_OPEN_PENDING:
        {
            self.mCurrentState = STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK;
           // DDLogInfo(@"\nStateMachine: telling PM that stream is not open");
            self.mPeerManager.mCurrentPeerHostName = packet.mHostName;
            mPeerServiceName = packet.mHostService;

            [self writePeerNameToPersistentStrorage];
            
            error = BM_ERROR_SM_STREAM_OPEN_PENDING;
        }
            break;
          
       case STATE_INITIALIZED:
        {
            DDLogInfo(@"STATE_INITIALIZED_STREAMS_UNOPEN");
            self.mCurrentState = STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK;
            self.mPeerManager.mCurrentPeerHostName = packet.mHostName;
            mPeerServiceName = packet.mHostService;

            [self writePeerNameToPersistentStrorage];
            break;
        }
            
            //The control streams are open. We ahve now received a connect request from the peer
            //it is OK to go ahead and set to CONNECTED
            
            //TODO: here we are assuming that the ACK send is successful in the PM
            //if not the PM needs to update the SM that it failed so SM can revert this state
            //For now we are assuming that it will always go through
        case STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED:
        {
            DDLogInfo(@"STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED");  
            if(error == BM_ERROR_NONE)
            {
             //   DDLogInfo(@"\nStateMachine: we are now connected to peer");
                self.mPeerManager.mCurrentPeerHostName = packet.mHostName;
                mPeerServiceName = packet.mHostService;

                @synchronized(self)
                {
                    self.mCurrentState = STATE_CONNECTED_TO_PEER;
                    [self writeStateToPersistentStrorage];
                    [self writePeerNameToPersistentStrorage];
                }
                
                if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
                {
                    //connex
                    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
                }

                
                if(self.mDelegate && 
                   [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
                {
                    [self.mDelegate connectionStatusChanged:YES 
                                                   withPeer:mPeerManager.mCurrentPeerHostName 
                                                 isIncoming:YES];
                    
                    //[self.mDelegate incomingConnectionToPeerComplete:mPeerManager.mCurrentPeerHostName];
                };
                

            }
            else 
            {
              //  DDLogInfo(@"\nStateMachine: Not connecting to Peer. Sending ACK error %d", error);
                @synchronized(self)
                {
                    self.mCurrentState = STATE_INITIALIZED;
                    [self writeStateToPersistentStrorage];
                }
                
                if(self.mDelegate && 
                   [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
                {
                    [self.mDelegate connectionStatusChanged:NO 
                                                   withPeer:nil 
                                                 isIncoming:NO];

                };
            }

            self.mACKErrorCode = BM_ERROR_NONE;

            break;
        }
            
        default:
          //  DDLogInfo(@"\nStateMachine: BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD");
            return BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD;
    }
    
    
    //If we do not have a mode assigned or if we are in the same mode, so ahead and set it to the 
    //appropriate mode
    if( (packet.mPeerMonitorMode == self.mCurrentBabyMonitorMode) ||
            self.mCurrentBabyMonitorMode == INVALID_MODE)
    {
        @synchronized(self)
        {
            self.mCurrentBabyMonitorMode = (packet.mPeerMonitorMode == BABY_OR_TRANSMITTER_MODE) ?
                                            PARENT_OR_RECEIVER_MODE: BABY_OR_TRANSMITTER_MODE;
            [self writeModeToPersistentStrorage];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToBMVCSMModeChanged 
                                                                           object:[NSNumber numberWithInt:self.mCurrentBabyMonitorMode]];
    }
    
    if(error != BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD)
    {
        if(self.mDelegate && 
           [self.mDelegate respondsToSelector:@selector(inComingConnectionRequestFrom:)])
        {
            [self.mDelegate inComingConnectionRequestFrom:packet.mHostName];
        }
    }
    
    return error;
}


-(BMErrorCode) isOKToProcessHandshakeACKReceivedFromPeerWithError:(bool) withError
{
    BMErrorCode error = BM_ERROR_NONE;
    
   // DDLogInfo(@"StateMachine isOKToProcessHandshakeACKReceivedFromPeerWithError mCurrentState=%d", mCurrentState);
    switch (self.mCurrentState) 
    {
            
        case STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING:
            if(!withError)
            {
           //     DDLogInfo(@"\nStateMachine: we are connected to peer");

                @synchronized(self)
                {
                    self.mCurrentState = STATE_CONNECTED_TO_PEER;
                    [self writeStateToPersistentStrorage];
                   // [self writePeerNameToPersistentStrorage];
                }
                
                if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
                {
                                        //connex
                    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
                }

                if(self.mDelegate && 
                   [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
                {
                    [self.mDelegate connectionStatusChanged:YES 
                                                   withPeer:mPeerManager.mCurrentPeerHostName 
                                                 isIncoming:NO];
                    
                    //[self.mDelegate outgoingConnectionToPeerComplete:mPeerManager.mCurrentPeerHostName];
                }
                else 
                {
              //      DDLogInfo(@"\nStateMachine: Connected. no delegate for connectionStatusChanged");
                }
                
            }
            //We do not return an error here as it is OK to receive this packet in this state
            //Although the ACK itself was an error
            else
            {
              //  DDLogInfo(@"\nStateMachine: We received an ACK error %d for handshake req", withError);
                [self.mProtocolManager shutdownControlStreams];
                
                @synchronized(self)
                {
                    self.mCurrentState = STATE_INITIALIZED;
                    [self writeStateToPersistentStrorage];
                }
                
                if(self.mDelegate && 
                   [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
                {
                    [self.mDelegate connectionStatusChanged:NO withPeer:nil isIncoming:NO];
                };
            }
            
            [self stopHandShakeReqResponseTimer];
            
            error = BM_ERROR_NONE;
            break;
            
        case STATE_CONNECTED_TO_PEER:
        case STATE_INITIALIZED:
        case STATE_CONTROL_STREAM_OPEN_PENDING:
        case STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ:
        case STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK:
        case STATE_CONTROL_STREAM_OPEN_FAILED:
        case STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED:
        default:
          //  DDLogInfo(@"\nStateMachine: BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD");
            error = BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD;
            break;   
    }
    
    return error;
}

-(BMErrorCode) userWantsToDisconnectWithPeer
{
   // DDLogInfo(@"\nSM: userWantsToDisconnectWithPeer");
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mCurrentState == STATE_INITIALIZED)
    {
        //we are not connected the peer right now. No point sending the disconnect packet
        //do eveything else
     //   DDLogInfo(@"\nStateMachine: Not connected to peer currently. Doing the needful to disconnect");
        self.mPeerManager.mCurrentPeerHostName = nil;
        [self disconnectComplete];
    }
    
    else if(mCurrentState == STATE_CONNECTED_TO_PEER)
    {
        if(![mProtocolManager areControlStreamsSetup])
        {
      //      DDLogInfo(@"\nStateMachine: User wants to disconnect, but control streams are not setup!!!");
            return BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
        }
        
        //Get the disconnect packet and send. Do the rest of the disconnect after we get an ACK.
        error = [mProtocolManager getPacketAndSendOfType:CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER 
                                                andError:BM_ERROR_NONE];
        
        if(error != BM_ERROR_NONE)
        {
        //    DDLogInfo(@"\nStateMachine: Error sending the disconnet packet to peer");
            return  error;
        }
        
        self.mCurrentState = STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING;
    }
    else 
    {
      //  DDLogInfo(@"\nStateMachine: We are not currently connected to any peer, nothing to disconnect");
        return BM_ERROR_SM_NOT_CONNECTED_TO_PEER;
    }
    
    return error;
}

-(BMErrorCode) completeUserDisconnectWithPeerAfterACKWasReceived
{
   // DDLogInfo(@"\nSM: completeUserDisconnectWithPeerAfterACKWasReceived");
    if(mCurrentState == STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING)
    {
        //have the PM do the needful, including closign the stream etc and sending the ACK
        [self.mProtocolManager dissolveConnection];

        [self disconnectComplete];

         return BM_ERROR_NONE;
    }
    
    
//    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToBMVDisconnectedWithPeer 
//                                                        object:nil];
    
    return BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
}

-(BMErrorCode) peerWantsToDisconnectWithUs
{
  //  DDLogInfo(@"\nSM: peerWantsToDisconnectWithUs");
    
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mCurrentState != STATE_CONNECTED_TO_PEER)
    {
     //   DDLogInfo(@"\nStateMachine: We are not currently connected to any peer, nothing to disconnect");
        
        return BM_ERROR_SM_NOT_CONNECTED_TO_PEER;
    }
    else 
    {
        [self disconnectComplete];
    }

    return error;
}

-(void) disconnectComplete
{
    DDLogInfo(@"\nSM: disconnectComplete");
    @synchronized(self)
    {
        self.mCurrentState = STATE_INITIALIZED;
        [self writeToPersistentStrorage];
    }

    if(self.mDelegate && 
       [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
    {
        [self.mDelegate connectionStatusChanged:NO withPeer:nil isIncoming:NO];
    };
    
    self.mMediaRecorder = nil;
    self.mMediaPlayer = nil;
    
    self.mReceivedTCPHandleRequest = NO;
}

#pragma clang diagnostic pop
@end

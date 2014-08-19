//
//  StateMachine+ControlMediaStreams.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/25/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+ControlMediaStreams.h"
#import "DDLog.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (ControlMediaStreams)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

-(void) startHandshakeReqResponseTimer
{
  //  DDLogInfo(@"\nStateMachine: Starting wait for HandshakeReqResponse");
    if(mHandshakeReqResponseTimer)
    {
        [mHandshakeReqResponseTimer invalidate];
        mHandshakeReqResponseTimer = nil;
    }
    
    mHandshakeReqResponseTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                                      target:self 
                                                                    selector:@selector(handshakeReqResponseTimerFired) 
                                                                    userInfo:nil                                                                
                                                                   repeats:YES];
}

-(void) stopHandShakeReqResponseTimer
{
    if(mHandshakeReqResponseTimer)
    {
        [mHandshakeReqResponseTimer invalidate];
        mHandshakeReqResponseTimer = nil;
    }     
}

-(void) handshakeReqResponseTimerFired
{
  //  DDLogInfo(@"\nStateMachine: No Response to handshake req. Disconnecting");
    [self.mProtocolManager shutdownControlStreams];    
    [self disconnectComplete];

    if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
    {
        [self.mDelegate connectionStatusChanged:NO withPeer:self.mPeerManager.mCurrentPeerHostName isIncoming:NO];
    }
    
    [self stopHandShakeReqResponseTimer];
}

-(void) controlStreamOrResolveFailed
{
   // DDLogInfo(@"\nStateMachine: controlStreamOrResolveFailed");
    
   /* if(self.mCurrentState == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING ||
       self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA||
       self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
        return;*/
    
    @synchronized(self)
    {
        self.mCurrentState = STATE_INITIALIZED;
        [self writeStateToPersistentStrorage];
    }

    [self.mProtocolManager shutdownControlStreams];
    
    if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
    {
        [self.mDelegate connectionStatusChanged:NO withPeer:self.mPeerManager.mCurrentPeerHostName isIncoming:NO];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kNotificationPMToStateMachineControlStreamsOpen 
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNotificationPMToSMControlStreamOpenFailed
                                                  object:nil];
}

-(void) controlStreamsOpenCallback
{
   // DDLogInfo(@"\ncontrolStreamsOpenCallback state is %d", mCurrentState);
    BMErrorCode error = BM_ERROR_NONE;
    //if we are in this state then we must've explicitly tried to open the 
    //streams. 
    if(self.mCurrentState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ)
    {
        DDLogInfo(@"controlStreamsOpenCallback current state is STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ");
        DDLogInfo(@"\nStateMachine: PM to send initial handshake packet");
         error = [self.mProtocolManager getInitialHandshakePacketAndSendWithMode:self.mCurrentBabyMonitorMode];
        if(error == BM_ERROR_NONE)
        {
            //we just sent a handshake req, we now have to wait to get a response to it
            self.mCurrentState = STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING;
            [self startHandshakeReqResponseTimer];
        }
        else
        {
            self.mCurrentState = STATE_CONTROL_STREAM_OPEN_FAILED;
            [Utilities showAlert:@"StateMachine: Error Opening i/p and o/p streams"];
        }
    }
    //the SM and the PM have been waiting for one or more of the streams to open in order to 
    //continue responding to the handshake req it had received.
    else if(self.mCurrentState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK)
    {
        DDLogInfo(@"controlStreamsOpenCallback current state is STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK");
        
         error = [self.mProtocolManager getInitialHandshakeACKPacketAndSend:self.mACKErrorCode];
        if(error == BM_ERROR_NONE)
        {
            if(mACKErrorCode == BM_ERROR_NONE)
            {
                //THe other device had initiated a connect, we ar only responding to it.
                //update the UI that we are connected
          //      DDLogInfo(@"\nStateMachine: We are now connected to peer, PM to send handshake ACK packet with code %d", self.mACKErrorCode);
                @synchronized(self)
                {
                    self.mCurrentState = STATE_CONNECTED_TO_PEER;
                    [self writeStateToPersistentStrorage];
                    [self writePeerNameToPersistentStrorage];
                }
                                                
                if(self.mDelegate && 
                   [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
                {
                    [self.mDelegate connectionStatusChanged:YES 
                                                   withPeer:mPeerManager.mCurrentPeerHostName 
                                                 isIncoming:YES];
                    //[self.mDelegate incomingConnectionToPeerComplete:mPeerManager.mCurrentPeerHostName];
                }
            }
            else 
            {
                DDLogInfo(@"\nStateMachine: We are NOT connecting, PM to send handshake ACK ERROR packet with code %d", self.mACKErrorCode);
                @synchronized(self)
                {
                    self.mCurrentState = STATE_INITIALIZED;
                    [self writeStateToPersistentStrorage];
                }
                
                if(self.mDelegate && 
                   [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:)])
                {
                    [self.mDelegate connectionStatusChanged:NO withPeer:nil isIncoming:NO];
                };
            }
            
            //reset so the  next req is not confused
            self.mACKErrorCode = BM_ERROR_NONE;

            //TODO, we are yet to handle the case where we may get a "unexpected packet"
            //msg from the peer. For whatever reason, the peer thinks it does not need/expect an ACK
            //then we need to figure out a way to backtrack from/correct the connection
        }
        else
        {
            self.mCurrentState = STATE_CONTROL_STREAM_OPEN_FAILED;
            [Utilities showAlert:@"StateMachine: Error: Opening i/p and o/p streams"];
        }
    }
    else if(self.mCurrentState == STATE_CONTROL_STREAM_OPEN_PENDING)
    {
        self.mCurrentState = STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED;
    }
    else if(self.mCurrentState == STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET)
    {
      //  DDLogInfo(@"\nStateMachine: Control Streams now open. Need to send start mon packet.");
        if( [self SetupAndSendStartMONPacket] != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nStateMachine: Error sending start MON packet");
        }
        else
        {
//            DDLogInfo(@"\nStateMachine: sent CONTROL_PACKET_TYPE_START_MONITORING with port number: %d",
//                      [self.mMediaRecorder getSocketPort]);
        }
        
        [self startStartMonitorReqResponseTimer];
        
        self.mCurrentState = STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING;
    }
//        else 
//        {
//            DDLogInfo(@"\nStateMachine: Error: State is in BABY MODE, but SM is not! State: %@", 
//                  [self.mReadableStateTable objectAtIndex:mCurrentState]);
//        }
    
    //else someone must've tried to connect with us, which initiated a 
    //stream open request. Not much else to do, don't do anything, this might be a duplicate event.
    else
    {
        DDLogInfo(@"\nControlStreamsOpenCallback Unexpected: current state is %d", self.mCurrentState);
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kNotificationPMToStateMachineControlStreamsOpen 
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kNotificationPMToSMControlStreamOpenFailed
                                                  object:nil];
  
    return;
}

#pragma clang diagnostic pop
@end

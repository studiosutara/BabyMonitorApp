//
//  StateMachine+TCPServerDelegate.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/25/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+TCPServerDelegate.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (TCPServerDelegate)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (void) serverDidEnableBonjour:(NSNetService*)service withName:(NSString *)string
{
    mOwnName = string;
    
    //if we were waiting for the service to publish before we re-started to connect or to monitor,
    //then check the state here and do the needful
    
    if(self.mCurrentState == STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING)
    {
        [self completeResumeMonitor];
    }
    else if(self.mCurrentState == STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING)
    {
//        NSNetService* service =    [[NSNetService alloc] initWithDomain:@"local" 
//                                                                           type:[Utilities getBonjourType] 
//                                                                           name:self.mPeerManager.mCurrentPeerHostName];
        
        BMErrorCode error = [self initiateInitialHandShakeWithPeer:nil]; //self.mPeerManager.mCurrentlyConnectedPeer];
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nStateMachine:Error starting initiateInitialHandShakeWithPeer");
            
            [self disconnectComplete];
        }
    }
}

- (bool) isOkToAcceptNewConnection
{
//    DDLogInfo(@"\nStateMachine: isOkToAcceptNewConnection. State = %@, control streams = %d",
//          [self.mReadableStateTable objectAtIndex:self.mCurrentState], [self.mProtocolManager areControlStreamsSetup]);
    
    if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA ||
         self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
      self.mCurrentState ==  STATE_CONTROL_STREAM_OPEN_PENDING ||
       self.mCurrentState ==  STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ ||
       self.mCurrentState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK ||
       self.mCurrentState == STATE_CONTROL_STREAM_OPEN_FAILED ||
       self.mCurrentState ==  STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED ||
       self.mCurrentState == STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING)
    {
//        DDLogInfo(@"\nStateMachine: Not ready to accept new TCP connection in state %@",
//                  [mReadableStateTable objectAtIndex:self.mCurrentState]);
         return NO;
    }
    
  //  DDLogInfo(@"\nStateMachine: isOkToAcceptNewConnection, for handshake. State = %d", self.mCurrentState);
    return YES;
}

-(void) didAcceptConnectionForServer:(PeerManagerServer*)server 
                         inputStream:(NSInputStream*)readStream 
                        outputStream:(NSOutputStream*)writeStream
{
    DDLogInfo(@"\nStateMachine: didAcceptConnectionForServer state = %d", self.mCurrentState);
	if (!readStream || !writeStream || !server)
        return;
    
    //else, this is a request for connecting with the peer.
    // so we are the ones getting the TCP connection request
    mReceivedTCPHandleRequest = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controlStreamsOpenCallback)
                                                 name:kNotificationPMToStateMachineControlStreamsOpen
                                               object:nil];
    
    self.mCurrentState = STATE_CONTROL_STREAM_OPEN_PENDING;

    [self.mProtocolManager assignAndOpenControlStreamsIn:readStream outStream:writeStream];     
}

- (void) server:(PeerManagerServer*)server didNotEnableBonjour:(NSDictionary *)errorDict
{
    DDLogInfo(@"\nStateMachine: Error: didNotEnableBonjour");
}

#pragma clang diagnostic pop

@end

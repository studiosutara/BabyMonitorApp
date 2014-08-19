//
//  StateMachine.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/18/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine.h"
#include <netinet/in.h>
#include <arpa/inet.h>
#import "PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine

@synthesize mCurrentBabyMonitorMode;
@synthesize mPeerManager;
@synthesize mProtocolManager;
@synthesize mOwnName;
@synthesize mCurrentState;
@synthesize mTogglePeerModeAlert;
@synthesize mToggleModeAlert;
@synthesize mACKErrorCode;

@synthesize mReceivedTCPHandleRequest;

@synthesize mDelegate;

@synthesize mMediaPlayer;
@synthesize mMediaRecorder;

@synthesize mReadableStateTable;

#pragma mark initialization functions

-(void) setMCurrentState:(StateMachineStates)state
{    
    @synchronized(self)
    {
        if(state == STATE_INITIALIZED)
        {
            if([self isAConnectingState:mCurrentState])
            {
                [self startRetryConnectionTimer];
            }
        }
        mCurrentState = state;
        
        [self notifyUIOfStateChange:state];
        
        if([StateMachine isATransientState:self.mCurrentState])
        {
            [self startTransientStateTimer];
        }
        else
        {
            [self stopTransientStateTimer];
        }
    }
    
    DDLogInfo(@"\nStateMachine: NEW state = %@", [mReadableStateTable objectAtIndex:mCurrentState]);
}

-(StateMachineStates) mCurrentState
{
    return mCurrentState;
}

-(void) startRetryConnectionTimer
{
    if(mNumOfConnectionRetries >=3)
        return;
    
    NSInteger randomNumber = arc4random() % 4;
    
   // NSLog(@"\nStateMachine: startRetryConnectionTimer in %d secs", randomNumber);
    [NSTimer scheduledTimerWithTimeInterval:randomNumber
                                     target:self
                                   selector:@selector(retryConnecting)
                                   userInfo:nil
                                    repeats:NO];
}

-(void) retryConnecting
{
  //  NSLog(@"\nStateMachine: retryConnecting");
    mNumOfConnectionRetries ++;
    BMErrorCode error = [self initiateInitialHandShakeWithPeer:nil];
    if(error != BM_ERROR_NONE)
    {
    //    DDLogInfo(@"\nStateMachine:Error starting initiateInitialHandShakeWithPeer");
        
        [self disconnectComplete];
    }
}

-(bool) isAConnectingState:(StateMachineStates)newState
{
    if(newState == STATE_CONTROL_STREAM_OPEN_PENDING ||
       newState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ ||
       newState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK ||
       newState == STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED ||
       newState == STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING)
    {
        return YES;
    }
    
    return NO;
}

-(void) notifyUIOfStateChange:(StateMachineStates) newState
{
    NSLog(@"notifyUIOfStateChange %@", mReadableStateTable[newState]);
    @synchronized(self)
    {
       if(newState == STATE_INITIALIZED ||
          newState == STATE_INVALID)
       {
           [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                               object:[NSNumber numberWithInt:NOT_CONNECTED]];
       }
            
        else if(newState == STATE_CONTROL_STREAM_OPEN_PENDING ||
                newState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ ||
                newState == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK ||
                newState == STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED ||
                newState == STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING ||
                newState == STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                                object:[NSNumber numberWithInt:CONNECTING]];
        }
        else if(newState == STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING ||
                newState == STATE_WAITING_TO_RECEIVE_MEDIA ||
                newState == STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                                object:[NSNumber numberWithInt:STARTING_MONITOR]];
        }
        else if(newState == STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET ||
                newState == STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                                object:[NSNumber numberWithInt:RESTARTING]];
        }
        else if(newState == STATE_CONNECTED_TO_PEER)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                                object:[NSNumber numberWithInt:CONNECTED_NOT_MONITORING]];
        }
        else if(newState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
                newState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                                object:[NSNumber numberWithInt:MONITORING]];
        }
        else if(newState == STATE_BABYMODE_LISTENING_TO_PARENT ||
                newState == STATE_PARENTMODE_TALKING_TO_BABY)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToUIStateChangeUpdate
                                                                object:[NSNumber numberWithInt:LISTENING_OR_TALKING]];
        }
    }
}

+(bool) isATransientState:(StateMachineStates) state
{
    if(state == STATE_INITIALIZED || 
       state == STATE_CONNECTED_TO_PEER ||
        state == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
         state == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA ||
       state == STATE_BABYMODE_LISTENING_TO_PARENT ||
       state == STATE_PARENTMODE_TALKING_TO_BABY ||
        state == STATE_INVALID ||
       state == STATE_STOPALL_AND_RESTART_MONITORING)
    {
        return FALSE;
    }
    else 
    {
        return TRUE;
    }
}

+(bool) isAConnectedState:(StateMachineStates) state
{
    if( state == STATE_INITIALIZED ||
    state == STATE_CONTROL_STREAM_OPEN_PENDING      ||                                
    state == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ ||
    state == STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK ||
    state == STATE_CONTROL_STREAM_OPEN_FAILED ||
    state == STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED ||
    state == STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING ||
    
    state == STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET ||    
    
    state == STATE_STOPALL_AND_RESTART_MONITORING ||
    state == STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING ||
    state == STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING ||
    
    state == STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING ||
    
    state == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING ||
    state == STATE_INVALID)          
    {
        return FALSE;
    }
    else 
    {
        return TRUE;
    }
}

-(void) setupReadableStateTable
{
    mReadableStateTable = [[NSMutableArray alloc] initWithCapacity:STATE_INVALID +1];
   
    [mReadableStateTable insertObject:@"STATE_INITIALIZED" 
                              atIndex:STATE_INITIALIZED];                   //0

    [mReadableStateTable insertObject:@"STATE_CONTROL_STREAM_OPEN_PENDING" 
                              atIndex:STATE_CONTROL_STREAM_OPEN_PENDING];   //1
    
    [mReadableStateTable insertObject:@"STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ" 
                              atIndex:STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ];    //2
    
    [mReadableStateTable insertObject:@"STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK" 
                              atIndex:STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK];    //3

    [mReadableStateTable insertObject:@"STATE_CONTROL_STREAM_OPEN_FAILED" 
                              atIndex:STATE_CONTROL_STREAM_OPEN_FAILED];    //4

    [mReadableStateTable insertObject:@"STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED" 
                              atIndex:STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED];    //5
    
    [mReadableStateTable insertObject:@"STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING" 
                              atIndex:STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING];    //6

    [mReadableStateTable insertObject:@"STATE_CONNECTED_TO_PEER" 
                              atIndex:STATE_CONNECTED_TO_PEER];                         //7

    [mReadableStateTable insertObject:@"STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET" 
                              atIndex:STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET];    //8

    [mReadableStateTable insertObject:@"STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING" 
                              atIndex:STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING];             //9
    
    [mReadableStateTable insertObject:@"STATE_WAITING_TO_RECEIVE_MEDIA" 
                              atIndex:STATE_WAITING_TO_RECEIVE_MEDIA];                       //10
        
    [mReadableStateTable insertObject:@"STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING" 
                              atIndex:STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING];    //11

    [mReadableStateTable insertObject:@"STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA"
                              atIndex:STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA];                 //12

    [mReadableStateTable insertObject:@"STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA" 
                              atIndex:STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA];                    //13

    [mReadableStateTable insertObject:@"STATE_STOPALL_AND_RESTART_MONITORING" 
                              atIndex:STATE_STOPALL_AND_RESTART_MONITORING];                           //16

    [mReadableStateTable insertObject:@"STATE_PEER_PAUSED_ON_INTERRUPT" 
                              atIndex:STATE_PEER_PAUSED_ON_INTERRUPT];                                              //21

    [mReadableStateTable insertObject:@"STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING" 
                              atIndex:STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING];    //22
    
    [mReadableStateTable insertObject:@"STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING" 
                              atIndex:STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING];    //23
    
    [mReadableStateTable insertObject:@"STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING" 
                              atIndex:STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING];    //24
    
    [mReadableStateTable insertObject:@"STATE_BABYMODE_LISTENING_TO_PARENT" 
                              atIndex:STATE_BABYMODE_LISTENING_TO_PARENT];    //25
    
    [mReadableStateTable insertObject:@"STATE_PARENTMODE_WAITING_FOR_TALK_TO_BABY_START_ACK" 
                              atIndex:STATE_PARENTMODE_WAITING_FOR_TALK_TO_BABY_START_ACK];    //26

    [mReadableStateTable insertObject:@"STATE_PARENTMODE_TALKING_TO_BABY" 
                              atIndex:STATE_PARENTMODE_TALKING_TO_BABY];    //27
     
    [mReadableStateTable insertObject:@"STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING" 
                              atIndex:STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING];    //28
    
    [mReadableStateTable insertObject:@"STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING"
                              atIndex:STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING];         //29
    
    [mReadableStateTable insertObject:@"STATE_INVALID"
                              atIndex:STATE_INVALID];  //30
}

-(void) dealloc
{
   // DDLogInfo(@"\nBMVC: deallocing StateMachine");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:nil];
}


-(id) init
{
   // DDLogInfo(@"\nStateMachine init....");
    //read the mode from the user defaults and populate it here
    //if there was no saved setting, then use Baby mode as default and
    //let the view controller know about it
    [self setupReadableStateTable];

    mPeerManager = nil;
    mProtocolManager = nil;
    mPeerManager. mCurrentPeerHostName = nil;
    self.mCurrentState = STATE_INVALID;
    
    mCurrentBabyMonitorMode = INVALID_MODE;
    
    mMediaPlayer = nil;
    mMediaRecorder = nil;
    
    
    mReceivedTCPHandleRequest = NO;
    mACKErrorCode  = BM_ERROR_NONE;
    
    mHandshakeReqResponseTimer = nil;
    mStartMonitorReqResponseTimer = nil;
    mPingPeerResponseTimer = nil;
    mTransientStateTimer = nil;
    
    mTTBWhileMonitoring = NO;
    return self;
}

-(void) start
{
 //   DDLogInfo(@"\nStatemachine: start...");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:nil];
    
    mProtocolManager = nil;
    mProtocolManager = [[ProtocolManager alloc] init];
    mProtocolManager.mPMDelegate = self;
    
    mPeerManager = nil;
    mPeerManager = [[PeerManager alloc] init];
    [mPeerManager start]; //:mCurrentBabyMonitorMode];
    mPeerManager.mPeerManagerDelegate = self;

    mPeerManager.mPeerManagerServer.delegate = self;
    
    mNumOfConnectionRetries = 0;
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(controlStreamOrResolveFailed) 
                                                 name:kNotificationPMToSMControlStreamErrorOrEndOccured 
                                               object:nil];
}

-(void) startTransientStateTimer
{    
    @synchronized(self)
    {
        if(mTransientStateTimer)
        {
            [mTransientStateTimer invalidate];
            mTransientStateTimer = nil;
        }
        
        
        //exclude the following states as they have their own timers
        if(self.mCurrentState == STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING &&
           self.mCurrentState == STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING &&
           self.mCurrentState == STATE_PARENTMODE_WAITING_FOR_TALK_TO_BABY_START_ACK &&
           self.mCurrentState == STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING &&
           self.mCurrentState == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING)
        {
            return;
        }
        else
        {
         //   DDLogInfo(@"\nStateMachine: Starting startTransientStateTimer");

            mTransientStateTimer = [NSTimer scheduledTimerWithTimeInterval:4
                                                                    target:self
                                                                  selector:@selector(transientStateTimerFired)
                                                                  userInfo:nil
                                                                   repeats:NO];
        }
    }
}

-(void) showLostConnectionAlertWithSound

{
  //  DDLogInfo(@"\nStateMachine: Playing beep Sound");
    if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
    {
        NSString* message = @"Connection appears to be lost. Monitoring stopped.";
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateBackground)
        {
            NSLog(@"In Background");
            UILocalNotification* notice = [[UILocalNotification alloc] init];
            notice.fireDate = [NSDate date];
            notice.alertBody = message;
            [[UIApplication sharedApplication] scheduleLocalNotification:notice];
        }
        else
        {
            [Utilities showAlert:message];
        }
        
        [Utilities playBeepSound];
    }
}

-(void) stopTransientStateTimer
{
   // DDLogInfo(@"\nStateMachine: stopTransientStateTimer called");
    if(mTransientStateTimer)
    {
     //   DDLogInfo(@"\nStateMachine: TransientStateTimer invalidated");
        [mTransientStateTimer invalidate];
        mTransientStateTimer = nil;
    }
}

-(void) transientStateTimerFired
{
    DDLogInfo(@"\nStateMachine: transientStateTimerFired in state %@", [mReadableStateTable objectAtIndex:self.mCurrentState]);
   
    if([StateMachine isAConnectedState:self.mCurrentState])
    {
        self.mCurrentState = STATE_CONNECTED_TO_PEER;
        
        if(self.mMediaPlayer)
        {
            [mMediaPlayer stopMediaStreamActivityWatchTimer];
        }
        if(self.mMediaRecorder)
        {
            [mMediaRecorder stopMediaStreamActivityWatchTimer];
        }
    }
    else
    {
        [self.mProtocolManager shutdownControlStreams];
        [self disconnectComplete];
        self.mCurrentState = STATE_INITIALIZED;
        
        if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
        {
            [self.mDelegate connectionStatusChanged:NO withPeer:self.mPeerManager.mCurrentPeerHostName isIncoming:NO];
        }
    }
    
    mTransientStateTimer = nil;
}

#pragma mark main run loop

-(BMErrorCode) runStateMachine:(StateMachineEvents)event withData:(id) data
{
    switch (event) 
    {
       case E_INITIAL_HANDSHAKE_ACK_SUCCESS_RECEIVED_FROM_PEER:
        {
            ControlPacket* packet = (ControlPacket*) data;
            if(packet)
            {
                self.mPeerManager.mCurrentPeerHostName = packet.mHostName;
                mPeerServiceName = packet.mHostService;
                
                [self writePeerNameToPersistentStrorage];

                return [self isOKToProcessHandshakeACKReceivedFromPeerWithError:false];
            }
            DDLogInfo(@"\nStateMachine: E_INITIAL_HANDSHAKE_ACK_SUCCESS_RECEIVED_FROM_PEER");
        }
            
        case E_INITIAL_HANDSHAKE_ACK_ERROR_RECEIVED_FROM_PEER:
        {
            ControlPacket* packet = (ControlPacket*) data;
            if(packet)
            {
                DDLogInfo(@"\nStateMachine: E_INITIAL_HANDSHAKE_ACK_ERROR_RECEIVED_FROM_PEER");
                return [self isOKToProcessHandshakeACKReceivedFromPeerWithError:true];
            }
        }
            
        //were we expecting a handshake/connection request from a peer?
        case E_INITIAL_HANDSHAKE_REQ_RECEIVED_FROM_PEER:
        {
            DDLogInfo(@"\nStateMachine: E_INITIAL_HANDSHAKE_REQ_RECEIVED_FROM_PEER");
            ControlPacket* packet = (ControlPacket*) data;
            
            if(packet)
                return [self isOKToProcessHandshakeRequestFromPeer:packet];
            else 
            {
                DDLogInfo(@"\nStateMachine: Error: received initial handshake req but packet is nil");
                return BM_ERROR_INVALID_INPUT_PARAM;
            }
            break;
        }
            
        case E_START_MONITORING_PACKET_RECEIVED_FROM_PEER:
        {
            ControlPacket* packet = (ControlPacket*) data;
            if(packet)
                return [self receivedStartMonitoringPacketFromPeerWithPortNum:packet.mPortNum];
            else 
            {
                DDLogInfo(@"\nStateMachine: Error: received START MON but packet is nil");
                return BM_ERROR_INVALID_INPUT_PARAM;
            }

            break;
        }
            
        case E_START_MONITORING_ACK_PACKET_RECEIVED_FROM_PEER:
        {
            ControlPacket* packet = (ControlPacket*) data;
            if(packet)
                return [self receivedStartMonitoringACKPacketFromPeerWithError:packet.mControlAckErrorCode
                                                                    andPortNum:packet.mPortNum];
            else 
            {
                DDLogInfo(@"\nStateMachine: Error: received START MON ACK but packet is nil");
                return BM_ERROR_INVALID_INPUT_PARAM;
            }
            break;
        }
        
        case E_STOP_MONITORING_PACKET_RECEIVED_FROM_PEER:
        {
            return [self receivedStopMonitoringPacketFromPeer];
            break; 
        }

        case E_STOP_MONITORING_ACK_PACKET_RECEIVED_FROM_PEER:
        {
            return [self receivedStopMonitoringACKPacketFromPeer];
            break; 
        }

        default:
            break;
    }
    
    return BM_ERROR_NONE;
}


#pragma mark state machine functions

-(bool) isCurrentlyRecording
{
    return (self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA);
}

-(bool) isCurrentlyPlaying
{
    return (self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    //DDLogInfo(@"\nStateMachine:Received observeValueForKeyPath");
    if ([keyPath isEqual:@"mAQPlayerState"]) 
    {
        AudioStreamerState state = (AudioStreamerState)[[change objectForKey:NSKeyValueChangeNewKey] intValue];
       
        [self playerStateChangedTo:state];
    }
    else if([keyPath isEqualToString:@"mAQRecorderState"])
    {
        //DDLogInfo(@"\nStateMachine: MediaRecorder state changed");
        AudioRecorderState state = (AudioRecorderState) [[change objectForKey:NSKeyValueChangeNewKey] intValue];
        [self recorderStateChangedTo:state];
    }
}

- (void) playerStateChangedTo:(AudioStreamerState) newState
{
//    DDLogInfo(@"\nStatemachine: playerStateChangedTo newState = %d, SM State = %@", newState, 
//          [mReadableStateTable objectAtIndex:self.mCurrentState]);
    
    if(newState == BM_AS_PLAYING)
    {
        if(self.mCurrentState == STATE_WAITING_TO_RECEIVE_MEDIA && 
           self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
        {
            self.mCurrentState = STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA;
            if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStartAnimation)])
            {
                [self.mDelegate SMStartAnimation];
            }
            
            [self writeStateToPersistentStrorage];
            
            if(mDelegate && [mDelegate respondsToSelector:@selector(monitoringStatusChanged:)])
            {
                [mDelegate monitoringStatusChanged:YES];
            }        
            
            DDLogInfo(@"\nStateMachine:AQPlayer started, SM state updated");
        }
        else if(self.mCurrentState == STATE_WAITING_TO_RECEIVE_MEDIA &&
                self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
        {
            self.mCurrentState = STATE_BABYMODE_LISTENING_TO_PARENT;
            [self writeStateToPersistentStrorage];
            
            if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStartAnimation)])
            {
                [self.mDelegate SMStartAnimation];
            }
            
            if(mDelegate && [mDelegate respondsToSelector:@selector(talkingToBaby:)])
            {
                [mDelegate talkingToBaby:YES];
            }
            
            DDLogInfo(@"\nStateMachine: We are now listening to the parent");
        }
        else 
        {
            DDLogInfo(@"\nStateMachine: AQplayer is playing, but SM not in expected state");
            return;
        }
    }
    else if(newState == BM_AS_STOPPED)
    {
        DDLogInfo(@"\nStateMachine: Recording Audio Queu Stopped");
    }
    else if(newState == BM_AR_PAUSED)
    {
   //     DDLogInfo(@"\nStateMachine: AQPlayer is PAUSED!");
    }
}

-(void) recorderStateChangedTo:(AudioRecorderState) newState
{    
    if(newState == BM_AR_PLAYING)
    {
//        DDLogInfo(@"\nStateMachine: Recorder is BM_AR_PLAYING, SM state is %@",  
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);

        if(self.mCurrentState == STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING)
        {
            if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
            {
                @synchronized(self)
                {
                    self.mCurrentState = STATE_PARENTMODE_TALKING_TO_BABY;
                    [self writeToPersistentStrorage];
                }
                
                if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStartAnimation)])
                {
                    [self.mDelegate SMStartAnimation];
                }
                
                if(mDelegate && [mDelegate respondsToSelector:@selector(talkingToBaby:)])
                {
                    [mDelegate talkingToBaby:YES];
                }  
                
                DDLogInfo(@"\nStateMachine:We are now Talking to Baby");
                
                return;
            }
            else if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
            {
                @synchronized(self)
                {
                    self.mCurrentState = STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA;
                    
                    if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStartAnimation)])
                    {
                        [self.mDelegate SMStartAnimation];
                    }
                    
                    [self writeStateToPersistentStrorage];
                }
                
                if(mDelegate && [mDelegate respondsToSelector:@selector(monitoringStatusChanged:)])
                {
                    [mDelegate monitoringStatusChanged:YES];
                }
                
      //          DDLogInfo(@"\nStateMachine:Started monitoring in Baby mode, SM state updated");
            }
        }
        else 
        {
           // DDLogInfo(@"\nStateMachine: AQRecorder is recording, but SM not in expected state");
            return;
        }
    }
    else if(newState == BM_AR_STOPPED)
    {
        DDLogInfo(@"\nStateMachine: Playing audio queue stopped");
    }
    else if(newState == BM_AR_PAUSED)
    {
//        DDLogInfo(@"\nStateMachine: Recorder is BM_AR_PAUSED, SM state is %@",  
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);
    }
    else 
    {
//        DDLogInfo(@"\nStateMachine: Recorder is %d, SM state is %@",  newState,
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);
    }
}

-(BMErrorCode) changedBabyMonitorModeTo:(MonitorMode) newMode;
{
    if(newMode == mCurrentBabyMonitorMode)
    {
        DDLogInfo(@"\nStateMachine:changedBabyMonitorModeTo:Error: New mode is same as the old");
        return BM_ERROR_SM_WRONG_MODE_CHANGE;
    }
    
    @synchronized(self)
    {
        mCurrentBabyMonitorMode = newMode;
        
        [self writeModeToPersistentStrorage];
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) StopMediaPlayer
{    
    BMErrorCode error = BM_ERROR_NONE;
    
    @synchronized(self)
    {
        if(mMediaPlayer && mMediaPlayer.mAQPlayer)
        {
            error = [mMediaPlayer StopPlaying];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: error, media player unable to stop playing");
            }
            
            if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStopAnimation)])
            {
                [self.mDelegate SMStopAnimation];
            }
            
            [mMediaPlayer.mAQPlayer setMIsOkToStartPlaying:NO];
            [self.mMediaPlayer.mAQPlayer removeObserver:self 
                                             forKeyPath:@"mAQPlayerState"];
        }
    }
    
    self.mMediaPlayer = nil;
        
    return error;
}

-(BMErrorCode) StopMediaRecorder
{
    BMErrorCode error = BM_ERROR_NONE;
   // DDLogInfo(@"\nStateMachine: StopMediaRecorder");
    
    @synchronized(self)
    {
        if(self.mMediaRecorder && mMediaRecorder.mAQRecorder)
        {
            [self.mMediaRecorder.mAQRecorder removeObserver:self
                                                 forKeyPath:@"mAQRecorderState"];

            error = [mMediaRecorder StopRecording];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: error, media recorder unable to stop playing");
            }
            
            if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStopAnimation)])
            {
                [self.mDelegate SMStopAnimation];
            }
            
            mMediaRecorder.mAQRecorder.mIsOkToRecordAndSend = NO;
        }
    }
    
    self.mMediaRecorder = nil;
    return error;
}

-(BMErrorCode) userWantsToMuteVolume
{
    BMErrorCode error = BM_ERROR_NONE;
    
    //if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE &&
      // self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
    {
        error = [mMediaPlayer muteAudio];
    }
    
    return error;
}

@end


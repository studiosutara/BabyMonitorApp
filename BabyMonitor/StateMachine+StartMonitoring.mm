//
//  StateMachine+StartMonitoring.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/25/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+StartMonitoring.h"
#import "DDLog.h"
#import "PersistentStorage.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (StartMonitoring)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

-(void) startStartMonitorReqResponseTimer
{
   // DDLogInfo(@"\nStateMachine: Starting wait for startStartMonitorReqResponseTimer");
    if(mStartMonitorReqResponseTimer)
    {
        [mStartMonitorReqResponseTimer invalidate];
        mStartMonitorReqResponseTimer = nil;
    }
    
    mStartMonitorReqResponseTimer = [NSTimer scheduledTimerWithTimeInterval:3 
                                                                  target:self 
                                                                selector:@selector(startMonitorReqResponseTimerFired) 
                                                                userInfo:nil                                                                
                                                                 repeats:YES];
}

-(void) stopStartMonitorReqResponseTimer
{
    if(mStartMonitorReqResponseTimer)
    {
        [mStartMonitorReqResponseTimer invalidate];
        mStartMonitorReqResponseTimer = nil;
    }     
}

-(void) startMonitorReqResponseTimerFired
{
   // DDLogInfo(@"\nStateMachine: No Response to start monitor req. resetting");
        
    self.mCurrentState = STATE_CONNECTED_TO_PEER;
    [self writeStateToPersistentStrorage];
    
    [self stopStartMonitorReqResponseTimer];
}

-(BMErrorCode) receivedStartMonitoringPacketFromPeerWithPortNum:(uint16_t) portnum
{
    BMErrorCode error = BM_ERROR_NONE;
    
    DDLogInfo(@"\nStateMachine Received CONTROL_PACKET_TYPE_START_MONITORING with portnum %d in state %@",
              portnum,
          [mReadableStateTable objectAtIndex:self.mCurrentState]);
    
    if(self.mCurrentState == STATE_CONNECTED_TO_PEER ||
       self.mCurrentState == STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED || 
       self.mCurrentState == STATE_CONTROL_STREAM_OPEN_PENDING ||
       self.mCurrentState == STATE_PEER_PAUSED_ON_INTERRUPT)
    {
        error = [Utilities activateAudioSession];
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nStateMachine: receivedStartMonitoringPacketFromPeerWithPortNum: Error activiating audioSession. Returning");
            return BM_ERROR_FAIL;
        }
        
        [self.mProtocolManager.mPacketReceiver setproperties];
        [self.mProtocolManager.mPacketSender setproperties];
//        else
//            DDLogInfo(@"\nStateMachine: AudioSession Activated");

        
        if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
        {
          //  DDLogInfo(@"\nStateMachine: received START_MONITORING in parent mode, readying to play");
            
            [self setupMediaPlayerWithPortNumber:portnum];
            
            //This is not really an error, we just wait for the streams to open
            //It's ok for the player to start playing. If is getting data, then teh streams must be open
            @synchronized(self)
            {
                self.mCurrentState = STATE_WAITING_TO_RECEIVE_MEDIA;
                [self writeStateToPersistentStrorage];
            }
            
            [mMediaPlayer startMediaStreamActivityWatchTimer];
        }
        else if(mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
        {
            [self setupMediaRecorderWithPortNum:portnum];
            portnum = [self.mMediaRecorder getSocketPort];
            self.mCurrentState = STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING;
            error = [mMediaRecorder StartRecording];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error starting media recorder for starting monitor");
            }
            else 
            {
               // DDLogInfo(@"\nStateMachine: Starting recorder and Sending media");
            }
        }
        else 
        {
            DDLogInfo(@"StateMachine: Error, receiving START_MONITORING packet in an invalid mode");
            error = BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
        }
    }
    
    //we also need to let the UI know that ew are effectively connected right now as we received something on 
    //the control stream
    if(self.mDelegate && 
       [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
    {
        [self.mDelegate connectionStatusChanged:YES 
                                       withPeer:mPeerManager.mCurrentPeerHostName 
                                     isIncoming:YES];
    }
    else 
    {
      //  DDLogInfo(@"\nStateMachine: No delegate set or no delegate function defined for connectionStatusChanged");
    }
    
    if(self.mDelegate && 
       [self.mDelegate respondsToSelector:@selector(monitoringStatusChanged:)])
    {
        [self.mDelegate monitoringStatusChanged:YES];
    }
    
    if([self.mProtocolManager getStartMonitoringACKPacketAndSendWithPortNumber:portnum])
    {
        DDLogInfo(@"\nPM: Failed to send the CONTROL_PACKET_TYPE_ABOUT_TO_START_MONITORING_ACK packet");
    }
    else
    {
         DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_START_MONITORING_ACK packet with port %d", portnum);
    }

    //PM needs this to be true to send an ACK
    return error;
}

-(BMErrorCode) receivedStartMonitoringACKPacketFromPeerWithError:(BMErrorCode) errorCode
                                                      andPortNum:(uint16_t) portNum
{
    if(errorCode == BM_ERROR_NONE)
    {
        if(self.mCurrentState == STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING)
        {
            if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
            {
                @synchronized(self)
                {
                    self.mCurrentState = STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING;
                    [self writeStateToPersistentStrorage];

                    [mMediaRecorder StartRecording];
                }
            }
            else if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
            {
                @synchronized(self)
                {
                    [self setupMediaPlayerWithPortNumber:portNum];
                    self.mCurrentState = STATE_WAITING_TO_RECEIVE_MEDIA;
                    [self writeStateToPersistentStrorage];
                }
                [mMediaPlayer startMediaStreamActivityWatchTimer];
            }
        }
    }
    else 
    {
        DDLogInfo(@"\nStateMachine: Error, peer does not want to accept start mon");
        //TODO: need to update UI here if needed!
    }
    
    [self stopStartMonitorReqResponseTimer];
    
    return BM_ERROR_NONE;
}

-(bool) isTalkingToBaby
{
    if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE &&
       self.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY)
        return YES;
    else 
        return NO;
}

-(bool) isListeningToParent
{
    if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE &&
       self.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT)
        return YES;
    else 
        return NO;
}

-(bool) isReadyToStartRecordingAndSending
{
    return (self.mCurrentState == STATE_CONNECTED_TO_PEER);
}

-(bool) isReadyToStartReceivingAndPlaying
{
    return (self.mCurrentState == STATE_CONNECTED_TO_PEER);
}


//If we are here, then we are trying to start monitoring
//If the peer tried to start from it's side, then we will be starting as a response to
//a control packet received
- (BMErrorCode) userWantsToStartMonitoring
{
    if(self.mCurrentState != STATE_CONNECTED_TO_PEER)
    {
       // DDLogInfo(@"\nStateMachine: NOT STATE_CONNECTED_TO_PEER");
        return BM_ERROR_SM_NOT_CONNECTED_TO_PEER;
    }
    
    BMErrorCode error = BM_ERROR_NONE;
    
    if( ![mProtocolManager areControlStreamsSetup] )
    {
        DDLogInfo(@"\nStateMachine: Control stream not setup, but trying to start monitoring. Will open now...");
        //shutdown old stream before that
        [mProtocolManager shutdownControlStreams];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(controlStreamsOpenCallback)
                                                     name:kNotificationPMToStateMachineControlStreamsOpen
                                                   object:nil];
        
        error = [self.mProtocolManager resolvePeerAndOpenControlStreams:[PersistentStorage readPeerNameFromPersistentStorage]];
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nStateMachine: Error: Opening the Control streams for sender and receiver");
            return error;
        }
        
        self.mCurrentState = STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET;
        
        return BM_ERROR_NONE;
    }

    error = [Utilities activateAudioSession];
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nBMVC: userWantsToStartMonitoring Error activiating audioSession. Returning");
        return BM_ERROR_FAIL;
    }
    
    
    [self.mProtocolManager.mPacketReceiver setproperties];
    [self.mProtocolManager.mPacketSender setproperties];
    
    error = [self SetupAndSendStartMONPacket];
    return error;
}

-(BMErrorCode) SetupAndSendStartMONPacket
{
    BMErrorCode error = BM_ERROR_NONE;
    
   // DDLogInfo(@"StateMachine: SetupAndSendStartMONPacket");
    uint16_t portNum = 0;
    if(mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
    {
        [self setupMediaRecorderWithPortNum:0];
        portNum = [self.mMediaRecorder getSocketPort];
    }
    else if(mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
    {
        //then we send the start monitoring message to the other peer
        //[self setupMediaPlayerWithPortNumber:0];
        //portNum = [self.mMediaPlayer getSocketPort];
    }
    
    error = [self.mProtocolManager getStartMonitoringPacketAndSendWithPortNumber:portNum];
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nStateMachine: Error sending start monitoring packet");
        self.mCurrentState = STATE_CONNECTED_TO_PEER;
        return BM_ERROR_NONE;
    }
    else 
    {
//        DDLogInfo(@"\nStateMachine: sent CONTROL_PACKET_TYPE_START_MONITORING with port number: %d",
//                  [self.mMediaRecorder getSocketPort]);

    }
    
    [self startStartMonitorReqResponseTimer];
    //and wait till we receive data to start playing
    self.mCurrentState = STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING;
    
    return BM_ERROR_NONE;
}

-(void) setupMediaPlayerWithPortNumber:(uint16_t) portnum
{
    if(mMediaPlayer)
    {
        if(self.mMediaPlayer.mAQPlayer)
        {
            [self.mMediaPlayer.mAQPlayer removeObserver:self
                                             forKeyPath:@"mAQPlayerState"];
            
            mMediaPlayer.mAQPlayer = nil;
        }
        
        //[mMediaPlayer.mMediaPlayerSocket close];
        mMediaPlayer = nil;
    }
    
    mMediaPlayer = [[MediaPlayer alloc] initWithPortNumber:portnum];
    
    mMediaPlayer.mMediaPlayerDelegate = self;
    
    [mMediaPlayer.mAQPlayer addObserver:self
                             forKeyPath:@"mAQPlayerState"
                                options:NSKeyValueObservingOptionNew
                                context:nil];
    
    [mMediaPlayer.mAQPlayer setMIsOkToStartPlaying:YES];
}

-(void) setupMediaRecorderWithPortNum:(uint16_t) portnum
{
    if(mMediaRecorder)
    {
    //    DDLogInfo(@"\nStateMachine: setupMediaRecorderWithPortNum: MediaRecorder exists");
        if(self.mMediaRecorder.mAQRecorder)
        {
            [self.mMediaRecorder.mAQRecorder removeObserver:self
                                             forKeyPath:@"mAQRecorderState"];
            mMediaRecorder.mAQRecorder = nil;
        }

        [mMediaRecorder.mMediaRecorderSocket close];
        mMediaRecorder = nil;
    }
    
    mMediaRecorder = [[MediaRecorder alloc] initWithPortNum:portnum];
    
    [mMediaRecorder.mAQRecorder addObserver:self 
                                 forKeyPath:@"mAQRecorderState" 
                                    options:NSKeyValueObservingOptionNew 
                                    context:nil];
    
    mMediaRecorder.mMediaRecorderDelegate = self;
    mMediaRecorder.mAQRecorder.mIsOkToRecordAndSend = YES;
}

#pragma clang diagnostic pop
@end

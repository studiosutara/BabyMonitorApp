//
//  StateMachine+TalkToBaby.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 8/8/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+TalkToBaby.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation StateMachine (TalkToBaby)

-(BMErrorCode) userWantsToTalkToBaby
{
    if(self.mCurrentBabyMonitorMode != PARENT_OR_RECEIVER_MODE)
        return BM_ERROR_SM_NOT_IN_EXPECTED_MODE;
 
    BMErrorCode error = BM_ERROR_NONE;

    if(self.mCurrentState == STATE_CONNECTED_TO_PEER || 
       self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
    {
        if(![self.mProtocolManager areControlStreamsSetup])
        {
            DDLogInfo(@"\nStateMachine: Error cannot talk to baby, control streams not set up in state %@",
                  [self.mReadableStateTable objectAtIndex:self.mCurrentState]);
            
            return BM_ERROR_FAIL;
        }
                
        uint16_t portNum = 0;
        [self setupMediaRecorderWithPortNum:0];
        portNum = [self.mMediaRecorder getSocketPort];
        
        error = [self.mProtocolManager getTalkToBabyStartPacketAndSendWithPortNumber:portNum];
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nStateMachine: Error sending start monitoring packet");
            return BM_ERROR_NONE;
        }
        else 
        {
         //   DDLogInfo(@"\nStateMachine: Sent TTB packet with port number: %d", portNum);
        }
        
        if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
        {
            mTTBWhileMonitoring = YES;
        }
        else
        {
            error = [Utilities activateAudioSession];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nBMVC: UserWantstotalktobaby Error activiating audioSession");
                return BM_ERROR_FAIL;
            }
//            else
//                DDLogInfo(@"\nBMVC: AudioSession activated");
            
            [self.mProtocolManager.mPacketReceiver setproperties];
            [self.mProtocolManager.mPacketSender setproperties];
            
        }
        
        [self startStartMonitorReqResponseTimer];        
        //and wait till we receive data to start playing
        self.mCurrentState = STATE_PARENTMODE_WAITING_FOR_TALK_TO_BABY_START_ACK;
    }
    else if(self.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY)
    {
        [self stopTalkingToBaby];
    }
    else 
    {
//        DDLogInfo(@"\nStateachine: PM device Error cannot talk to baby in state %@", 
//              [self.mReadableStateTable objectAtIndex:self.mCurrentState]);
        
        return BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) stopTalkingToBaby
{
  //  DDLogInfo(@"\nStateMachine: Stopping Talking to Baby. Asking recorder to stop");
    
    if([self StopMediaRecorder] !=BM_ERROR_NONE)
    {
        DDLogInfo(@"\nStateMachine: Error in stopping recorder");
    }
    
    if([self.mProtocolManager getPacketAndSendOfType:CONTROL_PACKET_TYPE_TALK_TO_BABY_END 
                                         andError:BM_ERROR_NONE] != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nStateMachine: Error sending stop TTB packet");
        return BM_ERROR_FAIL;
    }
    
    if(mDelegate && [mDelegate respondsToSelector:@selector(talkingToBaby:)])
    {
        [mDelegate talkingToBaby:NO];
    }
    
    if(mTTBWhileMonitoring)
    {
        @synchronized(self)
        {
            mTTBWhileMonitoring = NO;
            self.mCurrentState = STATE_WAITING_TO_RECEIVE_MEDIA;
            /*if([mMediaPlayer ResumePlaying] != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error resuming player after talking to baby");
                [self userWantsToStopMonitoring:YES];
            }
            else */
            {
                self.mCurrentState = STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA;
                if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(SMStartAnimation)])
                {
                    [self.mDelegate SMStartAnimation];
                }
                
                [self writeToPersistentStrorage];
                
            //    DDLogInfo(@"\nStateMachine: Stopping TTB while monitoring. Unmuting volume in Parent MOde");
                
                [self userWantsToMuteVolume];
            }
        }
    }
    else 
    {
        BMErrorCode error = [Utilities deactivateAudioSession];
        if(error != BM_ERROR_NONE)
        {
           // DDLogInfo(@"\nStateMachine: Error deactiviating audioSession");
            return BM_ERROR_NONE;
        }
//        else
//            DDLogInfo(@"\nStateMachine: AudioSession Deactivated");
        

        @synchronized(self)
        {
            self.mCurrentState = STATE_CONNECTED_TO_PEER;
            [self writeStateToPersistentStrorage];
        }
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) peerWantsToEndTalkingToBaby
{    
    if(self.mCurrentBabyMonitorMode != BABY_OR_TRANSMITTER_MODE)
    {
     //   DDLogInfo(@"\nStatemachine: peerWantsToEndTalkingToBaby error: not in BABY MODE");
        return BM_ERROR_SM_NOT_IN_EXPECTED_MODE;
    }
    
    if(self.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT)
    {
     //   DDLogInfo(@"\nStateMachine: peerWantsToEndTalkingToBaby stopping media player");
        
        @synchronized(self)
        {
            BMErrorCode error = [self StopMediaPlayer];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: peerWantsToEndTalkingToBaby error, media player unable to stop playing");
            }
        }
        
        if(mDelegate && [mDelegate respondsToSelector:@selector(talkingToBaby:)])
        {
            [mDelegate talkingToBaby:NO];
        }
        
        if(mTTBWhileMonitoring)
        {
            //self.mCurrentState = STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING;
            mMediaRecorder.mAQRecorder.mIsOkToRecordAndSend = YES;
            
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
        }
        else 
        {
            BMErrorCode error = [Utilities deactivateAudioSession];
            if(error != BM_ERROR_NONE)
            {
        //        DDLogInfo(@"\nStateMachine: Error deactiviating audioSession");
                return BM_ERROR_NONE;
            }
//            else
//                DDLogInfo(@"\nStateMachine: AudioSession Deactivated");

            @synchronized(self)
            {
                self.mCurrentState = STATE_CONNECTED_TO_PEER;
                [self writeStateToPersistentStrorage];
            }
        }
        
        return BM_ERROR_NONE;
    }
    else 
    {
//        DDLogInfo(@"\nStateMachine: Peer wants to end talking to baby, but not in expected state. %@", 
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);
        
        return BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) peerWantsToTalkToBabyAtPortNum:(uint16_t) portNum
{
    if(self.mCurrentBabyMonitorMode != BABY_OR_TRANSMITTER_MODE)
    {
       // DDLogInfo(@"\nStateMachine: Cannot listen to parent in parent/invalid mode");
        return BM_ERROR_SM_NOT_IN_EXPECTED_MODE;
    }
    
    if(self.mCurrentState == STATE_CONNECTED_TO_PEER || 
       self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
    {
        if(self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
        {
            mTTBWhileMonitoring = YES;
        }
        else
        {
            mTTBWhileMonitoring = NO;

            BMErrorCode error = [Utilities activateAudioSession];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: peerWantsToTalkToBabyAtPortNum: Error activiating audioSession");
                return BM_ERROR_FAIL;
            }
//            else
//                DDLogInfo(@"\nStateMachine: AudioSession Activated");
            
            [self.mProtocolManager.mPacketReceiver setproperties];
            [self.mProtocolManager.mPacketSender setproperties];
            
        }
        
        self.mCurrentState = STATE_WAITING_TO_RECEIVE_MEDIA;   
        [mMediaPlayer startMediaStreamActivityWatchTimer];
        [self setupMediaPlayerWithPortNumber:portNum];
    }
    else 
    {
        DDLogInfo(@"\nStateachine: BM device Error cannot talk to baby in state %@", 
              [self.mReadableStateTable objectAtIndex:self.mCurrentState]);
        
        return BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) receivedTalkToBabyACKPacketFromPeer
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(self.mCurrentBabyMonitorMode != PARENT_OR_RECEIVER_MODE)
    {
        DDLogInfo(@"\nStateMachine: error: Talk to Baby ACk not expected in baby/invalid mode");
        return BM_ERROR_SM_NOT_IN_EXPECTED_MODE;
    }
    
    if(self.mCurrentState == STATE_PARENTMODE_WAITING_FOR_TALK_TO_BABY_START_ACK)
    {
        if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
        {
            self.mCurrentState = STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING;

            if(mTTBWhileMonitoring)
            {       
                //[mMediaPlayer PausePlaying];
              //  DDLogInfo(@"\nStateMachine: TTB while monitoring. Muting VOLUME in PRENT MODE");
                [self userWantsToMuteVolume];
            }
            
            [mMediaRecorder StartRecording];  
            [self stopStartMonitorReqResponseTimer]; 
        }
        else 
        {
            DDLogInfo(@"\nStateMachine: Talk to Baby ACK unexpected in BABY/INVALID MODE");
        }
    }
    else 
    {
//        DDLogInfo(@"\nStateMachine error: Reeived receivedTalkToBabyACKPacketFromPeer in wrong state %@",
//              [self.mReadableStateTable objectAtIndex:self.mCurrentState]);
        error = BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
    }
    
    return error;    
}

#pragma clang diagnostic pop

@end
